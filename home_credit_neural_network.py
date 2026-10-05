"""Neural network (MLP) for the Home Credit Default Risk data.

Works like a scikit-learn classifier, so it can be used in a notebook, saved and
shared, and passed to sklearn tools such as permutation_importance.

Example
-------
    from home_credit_neural_network import HomeCreditNN, prepare_features

    train = pd.read_parquet("data/processed/train_merged.parquet")
    X, y = prepare_features(train)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, stratify=y, random_state=42)

    model = HomeCreditNN(class_weight="balanced").fit(X_train, y_train)
    p_default = model.predict_proba(X_test)[:, 1]

    model.save("models/home_credit_nn.pt")
    model = HomeCreditNN.load("models/home_credit_nn.pt")
"""
import copy

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader, TensorDataset

ID_COLUMNS = ["SK_ID_CURR", "TARGET", "dataset"]
NO_EMPLOYER_PLACEHOLDER = 365243


# --- Utilities to help with processing the data ---

def signed_log(d):
    """
    This function will use log1p to help the NN handle negative values (keeps the sign, 0 stays 0)
    """
    return np.sign(d) * np.log1p(np.abs(d))


def prepare_features(df):
    """
    Turns a merged table (train_merged / test_merged parquet) into model inputs.
    Returns X and y; y is None when there are no targets (the Kaggle test set).
    """
    df = df.copy()
    # 365243 in DAYS_EMPLOYED means "no employer" -> keep that as a flag, then treat the value as missing
    df["NO_EMPLOYER"] = (df["DAYS_EMPLOYED"] == NO_EMPLOYER_PLACEHOLDER).astype(int)
    df["DAYS_EMPLOYED"] = df["DAYS_EMPLOYED"].replace(NO_EMPLOYER_PLACEHOLDER, np.nan)

    y = None
    if "TARGET" in df.columns and df["TARGET"].notna().all():
        y = df["TARGET"].astype(int)
    X = df.drop(columns=[c for c in ID_COLUMNS if c in df.columns])
    return X, y


class TabularPreprocessor:
    """
    Learns all scaling statistics from the training data only, then applies them to any other data.
    Numeric columns: log (if heavily skewed) -> median fill + "was missing" flags -> standardise -> clip.
    Text / category columns: integer codes for the embeddings (0 = category not seen in training).
    """

    def __init__(self, skew_threshold=2.0, clip=5.0):
        self.skew_threshold = skew_threshold
        self.clip = clip

    @staticmethod
    def _cat_values(s):
        # missing categories become their own value, since "unknown" can itself be informative
        return s.astype(object).where(s.notna(), "MISSING").astype(str)

    def _log(self, num):
        if self.log_cols_:
            num[self.log_cols_] = signed_log(num[self.log_cols_])
        return num

    def fit(self, X):
        self.cat_cols_ = [c for c in X.columns if not pd.api.types.is_numeric_dtype(X[c])]
        self.num_cols_ = [c for c in X.columns if c not in self.cat_cols_]

        num = X[self.num_cols_].astype(float)
        skew = num.skew()
        self.log_cols_ = skew[skew.abs() > self.skew_threshold].index.tolist()
        num = self._log(num)

        self.missing_cols_ = num.columns[num.isna().any()].tolist()
        self.medians_ = num.median()
        filled = num.fillna(self.medians_)
        self.means_ = filled.mean()
        self.stds_ = filled.std().replace(0, 1)  # avoid dividing by zero on constant columns

        self.categories_ = {
            c: {v: i + 1 for i, v in enumerate(sorted(self._cat_values(X[c]).unique()))}
            for c in self.cat_cols_
        }
        return self

    @property
    def cat_cardinalities(self):
        return [len(self.categories_[c]) + 1 for c in self.cat_cols_]  # +1 for the "unseen" code 0

    def transform(self, X):
        num = self._log(X[self.num_cols_].astype(float))
        missing = num[self.missing_cols_].isna().astype(float).add_suffix("_missing")
        num = ((num.fillna(self.medians_) - self.means_) / self.stds_).clip(-self.clip, self.clip)
        num = pd.concat([num, missing], axis=1)
        x_num = torch.tensor(num.to_numpy(dtype=np.float32))

        if self.cat_cols_:
            codes = [
                self._cat_values(X[c]).map(self.categories_[c]).fillna(0).astype(np.int64).to_numpy()
                for c in self.cat_cols_
            ]
            x_cat = torch.tensor(np.stack(codes, axis=1), dtype=torch.long)
        else:
            x_cat = torch.zeros((len(X), 0), dtype=torch.long)
        return x_num, x_cat


# --- The network ---

class TabularMLP(nn.Module):
    def __init__(self, n_num, cat_cardinalities, hidden=(256, 128, 64), dropout=0.3):
        super().__init__()
        # one embedding table per categorical column; size grows with the number of categories, capped at 10
        self.embeddings = nn.ModuleList(
            [nn.Embedding(n, min(10, (n + 1) // 2)) for n in cat_cardinalities]
        )
        in_dim = n_num + sum(e.embedding_dim for e in self.embeddings)

        layers = []
        for h in hidden:
            layers += [nn.Linear(in_dim, h), nn.BatchNorm1d(h), nn.ReLU(), nn.Dropout(dropout)]
            in_dim = h
        layers.append(nn.Linear(in_dim, 1))  # one output: the logit of default
        self.mlp = nn.Sequential(*layers)

    def forward(self, x_num, x_cat):
        embedded = [emb(x_cat[:, i]) for i, emb in enumerate(self.embeddings)]
        x = torch.cat([x_num] + embedded, dim=1)
        return self.mlp(x).squeeze(1)


# --- sklearn-style wrapper: preprocessing + network + training in one object ---

class HomeCreditNN(ClassifierMixin, BaseEstimator):
    """
    class_weight: None (every client counts the same) or "balanced"
                  (each struggling client counts ~11x, the repaid/struggled ratio).
    """

    def __init__(self, hidden=(256, 128, 64), dropout=0.3, lr=1e-3, weight_decay=1e-5,
                 batch_size=1024, max_epochs=50, patience=5, class_weight=None,
                 val_size=0.1, random_state=420, verbose=True):
        self.hidden = hidden
        self.dropout = dropout
        self.lr = lr
        self.weight_decay = weight_decay
        self.batch_size = batch_size
        self.max_epochs = max_epochs
        self.patience = patience
        self.class_weight = class_weight
        self.val_size = val_size
        self.random_state = random_state
        self.verbose = verbose

    def _build_model(self, n_num, cat_cards):
        return TabularMLP(n_num, cat_cards, hidden=self.hidden, dropout=self.dropout).to(self.device_)

    def _predict_logit_proba(self, x_num, x_cat, batch_size=8192):
        # batch_size here only limits memory; it does not change the predictions
        self.model_.eval()
        out = []
        with torch.no_grad():
            for i in range(0, len(x_num), batch_size):
                logits = self.model_(x_num[i:i + batch_size].to(self.device_), x_cat[i:i + batch_size].to(self.device_))
                out.append(torch.sigmoid(logits).cpu())
        return torch.cat(out).numpy()

    def fit(self, X, y, X_val=None, y_val=None):
        """
        Pass X_val / y_val to use your own validation set (e.g. the same one LightGBM used);
        otherwise a stratified val_size share of X is held out for early stopping.
        """
        torch.manual_seed(self.random_state)
        self.device_ = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        y = np.asarray(y).astype(np.float32)

        if X_val is None:
            X, X_val, y, y_val = train_test_split(
                X, y, test_size=self.val_size, stratify=y, random_state=self.random_state
            )
        y_val = np.asarray(y_val).astype(np.float32)

        self.preprocessor_ = TabularPreprocessor().fit(X)
        fit_num, fit_cat = self.preprocessor_.transform(X)
        val_num, val_cat = self.preprocessor_.transform(X_val)
        self.n_num_ = fit_num.shape[1]
        self.cat_cards_ = self.preprocessor_.cat_cardinalities

        pos_weight = None
        if self.class_weight == "balanced":
            pos_weight = torch.tensor(float((y == 0).sum() / (y == 1).sum()), device=self.device_)

        self.model_ = self._build_model(self.n_num_, self.cat_cards_)
        loss_fn = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
        opt = torch.optim.AdamW(self.model_.parameters(), lr=self.lr, weight_decay=self.weight_decay)
        sched = torch.optim.lr_scheduler.ReduceLROnPlateau(opt, mode="max", factor=0.5, patience=2)

        loader = DataLoader(
            TensorDataset(fit_num, fit_cat, torch.tensor(y)),
            batch_size=self.batch_size, shuffle=True, drop_last=True,  # BatchNorm can't handle a batch of 1
        )

        best_auc, best_state, bad_epochs, history = 0.0, None, 0, []
        for epoch in range(1, self.max_epochs + 1):
            self.model_.train()
            total_loss = 0.0
            for xb_num, xb_cat, yb in loader:
                xb_num, xb_cat, yb = xb_num.to(self.device_), xb_cat.to(self.device_), yb.to(self.device_)
                opt.zero_grad()
                loss = loss_fn(self.model_(xb_num, xb_cat), yb)
                loss.backward()
                opt.step()
                total_loss += loss.item() * len(yb)

            val_auc = roc_auc_score(y_val, self._predict_logit_proba(val_num, val_cat))
            sched.step(val_auc)
            history.append({"epoch": epoch, "train_loss": total_loss / len(loader.dataset), "val_auc": val_auc})
            if self.verbose:
                print(f"epoch {epoch:2d}  train loss {history[-1]['train_loss']:.4f}  val AUC {val_auc:.4f}")

            if val_auc > best_auc + 1e-4:
                best_auc, best_state, bad_epochs = val_auc, copy.deepcopy(self.model_.state_dict()), 0
            else:
                bad_epochs += 1
                if bad_epochs >= self.patience:
                    if self.verbose:
                        print(f"early stop - best val AUC {best_auc:.4f}")
                    break

        self.model_.load_state_dict(best_state)  # keep the best epoch, not the last one
        self.history_ = pd.DataFrame(history)
        self.best_val_auc_ = best_auc
        self.classes_ = np.array([0, 1])
        return self

    def predict_proba(self, X):
        """Returns two columns like sklearn: [P(repaid), P(struggled)]."""
        x_num, x_cat = self.preprocessor_.transform(X)
        p = self._predict_logit_proba(x_num, x_cat)
        return np.column_stack([1 - p, p])

    def predict(self, X, threshold=0.5):
        return (self.predict_proba(X)[:, 1] >= threshold).astype(int)

    def save(self, path):
        torch.save({
            "params": self.get_params(),
            "preprocessor": self.preprocessor_,
            "n_num": self.n_num_,
            "cat_cards": self.cat_cards_,
            "state_dict": self.model_.state_dict(),
            "history": self.history_,
            "best_val_auc": self.best_val_auc_,
        }, path)

    @classmethod
    def load(cls, path):
        saved = torch.load(path, map_location="cpu", weights_only=False)
        obj = cls(**saved["params"])
        obj.device_ = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        obj.preprocessor_ = saved["preprocessor"]
        obj.n_num_, obj.cat_cards_ = saved["n_num"], saved["cat_cards"]
        obj.model_ = obj._build_model(obj.n_num_, obj.cat_cards_)
        obj.model_.load_state_dict(saved["state_dict"])
        obj.model_.eval()
        obj.history_, obj.best_val_auc_ = saved["history"], saved["best_val_auc"]
        obj.classes_ = np.array([0, 1])
        return obj
