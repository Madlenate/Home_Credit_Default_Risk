## The Math Behind the Feature Engineering

### Notation
For one applicant, let their history records be indexed by $j = 1, \dots, n$ (payments, card-months or loans).

- $t_j$ = when record $j$ happened, relative to the application date (negative = in the past)
  - installments: $t_j$ = `DAYS_INSTALMENT` (days)
  - credit card: $t_j$ = `MONTHS_BALANCE` (months, $-1$ = most recent month)
- $W$ = a time window, e.g. "last 6 months" = $\{\, j : t_j \ge -180 \,\}$
- $\mathbb{1}[\cdot]$ = indicator: 1 if the condition is true, 0 otherwise

### 1. Summaries (all-time and windowed)
Every summary is a count, an average or a maximum over a set of records.

**Count in a window**

$$n_W = \sum_{j} \mathbb{1}[\, j \in W \,]$$

**Rate in a window** (e.g. share of late payments)

$$\text{rate}_W = \frac{1}{n_W} \sum_{j \in W} \mathbb{1}[\text{late}_j]
\qquad \text{where } \text{late}_j = \mathbb{1}[\, \text{paid day}_j > \text{due day}_j \,]$$

If $n_W = 0$ (nothing in the window), the rate is undefined and stored as `NaN`.

**Average days late** (early payments count as 0)

$$\text{days late}_W = \frac{1}{n_W} \sum_{j \in W} \max(\text{paid day}_j - \text{due day}_j,\ 0)$$

**Card utilisation** for card-month $j$:

$$u_j = \frac{\text{balance}_j}{\text{credit limit}_j}
\qquad
u_W = \frac{1}{n_W} \sum_{j \in W} u_j$$

**Share of months near the limit**

$$\text{maxed}_W = \frac{1}{n_W} \sum_{j \in W} \mathbb{1}[\, u_j \ge 0.9 \,]$$

**Paying only the minimum** (months with a minimum due only)

$$\text{min-only}_W = \frac{1}{n_W} \sum_{j \in W} \mathbb{1}[\, \text{paid}_j \le \text{minimum}_j \,]$$

**All-time** summaries are the same formulas with $W$ = all records.

### 2. Change (trend) features
A trend compares recent behaviour with the applicant's **own** all-time behaviour:

$$\text{trend}_W = \text{rate}_W - \text{rate}_{\text{all}}$$

- $\text{trend} > 0$: worse recently than usual
- $\text{trend} < 0$: better recently than usual
- $\text{trend} \approx 0$: steady

| Feature | Recent window $W$ | Formula |
|---|---|---|
| `inst_late_trend_6m` | last 180 days | $\text{rate}_{6m} - \text{rate}_{\text{all}}$ |
| `inst_late_trend_12m` | last 365 days | $\text{rate}_{12m} - \text{rate}_{\text{all}}$ |
| `inst_days_late_trend_12m` | last 365 days | $\text{days late}_{12m} - \text{days late}_{\text{all}}$ |
| `cc_util_trend_3m` | last 3 months | $u_{3m} - u_{\text{all}}$ |
| `cc_dpd_trend_12m` | last 12 months | $\text{rate}^{\text{DPD}}_{12m} - \text{rate}^{\text{DPD}}_{\text{all}}$ |

**Change ratios** compare two periods by division (1 = no change):

$$\text{change ratio} = \frac{\text{average in recent period}}{\text{average in earlier period}}$$

| Feature | Recent period | Earlier period |
|---|---|---|
| `inst_payment_change_ratio` | payments in last 12 months | payments before that |
| `cc_drawings_change_ratio` | drawings in last 3 months | all-time average |
| `prev_applied_change_ratio` | applications in last 2 years | applications before that |

**Balance change** (in money, not a ratio):

$$\text{cc\_balance\_change\_3m} = \overline{\text{balance}}_{\text{months } -3 \text{ to } -1} - \overline{\text{balance}}_{\text{months } -12 \text{ to } -4}$$

**Recency of the last late payment**:

$$\text{inst\_last\_late\_days} = \max_{\, j \,:\, \text{late}_j = 1} t_j$$

(closest to 0 = most recent; `NaN` if never late)

### 3. Current loan vs past borrowing

$$\text{cur\_credit\_vs\_prev\_avg} = \frac{\text{current loan amount}}{\text{average past approved loan}}
\qquad
\text{cur\_credit\_vs\_prev\_max} = \frac{\text{current loan amount}}{\text{largest past approved loan}}$$

Values above 1 mean the applicant is asking for more than they have borrowed before.

### 4. Affordability

$$\text{INCOME\_LEFT\_PER\_PERSON} = \frac{\text{income} - \text{annuity}}{\text{family members}}
\qquad
\text{TOTAL\_DEBT\_TO\_INCOME} = \frac{\text{outside debt} + \text{current loan}}{\text{income}}$$

Every division uses a safe denominator: if it is 0, the result is `NaN` instead of an error (`NULLIF(x, 0)` in SQL).

### 5. How applicants are labelled in the sanity check
Each trend feature is split into four groups using a **±0.05 threshold** (5 percentage points):

| Label | Rule | Meaning |
|---|---|---|
| **Improving** | $\text{trend} < -0.05$ | Recent rate is more than 5 points **better** than their usual |
| **Steady** | $-0.05 \le \text{trend} \le 0.05$ | Within 5 points of their usual |
| **Worsening** | $\text{trend} > 0.05$ | Recent rate is more than 5 points **worse** than their usual |
| **No recent data** | trend is `NaN` | Nothing happened in the recent window |

Example: an applicant late on 4% of all payments but 15% of payments in the last 6 months has $\text{trend} = 0.15 - 0.04 = 0.11 > 0.05$, so they are labelled **worsening**.

The ±0.05 threshold is a judgement call, chosen so that small random variation counts as "steady". It only affects this summary table; the models use the raw trend values.

### 6. Single-feature AUC
For each feature, AUC is computed on applicants who have a value:

$$\text{AUC} = P(\, x_{\text{defaulter}} > x_{\text{repayer}} \,)$$

The probability that a randomly chosen defaulter has a higher value than a randomly chosen repayer: 0.5 = no signal, 1.0 = perfect separation. Features where *lower* values mean riskier are flipped onto the same scale:

$$\text{AUC}_{\text{reported}} = \max(\text{AUC},\ 1 - \text{AUC})$$
