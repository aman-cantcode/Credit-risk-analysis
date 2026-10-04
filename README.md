# Credit Risk Analysis & Prediction

An end-to-end data pipeline built on the UCI Statlog German Credit Dataset:
**raw data ingestion → cleaning/transformation → SQL analysis → model-ready data
generation → Logistic Regression classification → evaluation → business insights.**

Built as a portfolio project with a data-engineering lean - the emphasis is on a
clean, reproducible pipeline (raw data in, model-ready data and a trained model
out) as much as on the analysis itself.

---

## 1. Project Overview

Banks need to decide whether a loan applicant is likely to repay ("Good" risk) or
default ("Bad" risk). This project builds a small pipeline around 1,000 historical
loan applications to:

- Ingest and clean a raw, inconsistently-coded dataset into a model-ready format.
- Load the cleaned data into MySQL and answer analyst-style questions with SQL.
- Generate a proper train/test split as its own "model-ready data" artifact.
- Train a Logistic Regression classifier and evaluate it the right way for an
  imbalanced classification problem.
- Turn the whole thing into business-relevant conclusions and honest limitations.

This is **not** an automated loan-approval system - it's a pipeline and analysis
exercise using a well-known academic dataset.

---

## 2. Problem Statement

> Given an applicant's financial history and the characteristics of the loan
> they're requesting, can we identify which factors are associated with a higher
> chance of default, and can a simple, well-evaluated model support (not replace)
> a credit decision?

---

## 3. Dataset / Source

- **Name:** Statlog (German Credit Data)
- **Source:** UCI Machine Learning Repository, donated by Prof. Hans Hofmann,
  University of Hamburg (1994).
- **Size:** 1,000 rows, 20 attributes (7 numerical, 13 categorical) + target.
- **Target:** `risk` - `Good` (700 customers, 70%) or `Bad` (300 customers, 30%).
- The raw file uses coded categorical values (e.g. `A11`, `A34`); these are
  decoded into readable labels during cleaning using the dataset's official
  attribute documentation.

---

## 4. Pipeline / Architecture

```text
data/raw/german.data (raw, coded)
        │
        ▼
notebooks/01_data_cleaning.ipynb   →  data/processed/german_credit_processed.csv
        │
        ▼
notebooks/02_eda.ipynb             →  charts + written insights
        │
        ▼
sql/analysis.sql (run in MySQL)    →  analyst-style SQL insights
        │
        ▼
notebooks/03_modeling.ipynb        →  data/processed/train_set.csv + test_set.csv
                                        (model-ready data)
                                    →  trained Logistic Regression model
                                        + evaluation + interpretation
        │
        ▼
Business insights (this README)
```

`src/preprocessing.py` packages the cleaning + feature engineering logic from
notebook 01 into reusable functions, so the same transformation can be run outside
a notebook (e.g. `python src/preprocessing.py` regenerates the processed CSV from
the raw file - useful if this were ever wired into a scheduled job instead of run
by hand).

---

## 5. Data Cleaning (`notebooks/01_data_cleaning.ipynb`)

- **Missing values:** none found. **Duplicate rows:** none found.
- Several categorical attributes include an explicit "unknown / none" category
  (e.g. no checking account, no savings account). These behave like hidden
  missingness but were kept as their own category rather than dropped, because
  *not having* one of these financial products is itself meaningful signal for
  credit risk.
- All 13 categorical columns were decoded from their raw codes (e.g. `A34` →
  `"critical / other credits existing"`) into readable labels, using the
  official attribute documentation.
- The target was recoded from `1`/`2` to `Good`/`Bad` for readability.
- Two features were engineered:
  - **`age_group`**: age binned into 5 ranges, used for EDA/segmentation.
  - **`credit_per_month`**: `credit_amount / duration_months`, a simple proxy
    for monthly repayment burden.
- Final processed dataset: **1,000 rows, 23 columns**, saved to
  `data/processed/german_credit_processed.csv`.

---

## 6. EDA (`notebooks/02_eda.ipynb`)

Eight charts were built. Headline findings (all numbers computed directly from
the data):

- **Class balance:** 70% Good / 30% Bad - imbalanced, which matters for model
  evaluation later.
- **Loan amount:** right-skewed, median ≈ 2,320 DM, mean ≈ 3,271 DM, range
  250-18,424 DM.
- **Loan duration:** median 18 months, range 4-72 months, clustered around
  common terms (12/24/36/48 months).
- **Credit history (counter-intuitive finding):** applicants with *no* credit
  history or all-paid-duly history have the **highest** bad-risk rate (62.5%,
  n=40), while applicants with a "critical account / other credits existing"
  have the **lowest** (17.1%, n=293). Discussed in the notebook as a
  correlation-vs-causation caution, not a "no credit history = bad" causal rule.
- **Employment length:** more intuitive pattern - bad-risk rate is highest for
  <1 year employed (40.7%) and unemployed (37.1%) applicants, lowest for 4-7
  years employed (22.4%).
- **Loan purpose:** highest bad-risk rate for education (44.0%, n=50) and new
  car loans (38.0%, n=234); lowest for used car loans (16.5%, n=103) and
  retraining (11.1%, n=9 - very small sample).
- **Age group:** youngest applicants (19-25) have the highest bad-risk rate at
  42.1%, versus 24-30% for every other age group.
- **Checking account status:** clearest gradient in the dataset - `< 0 DM`
  49.3% bad-risk (n=274) down to `no checking account` 11.7% bad-risk (n=394).
- **Numeric correlations:** nothing strongly collinear; the strongest
  relationship is `duration_months` vs `credit_amount` (r = 0.62) - larger
  loans tend to run longer.

---

## 7. SQL Analysis (`sql/analysis.sql`)

The processed dataset is loaded into a MySQL table (`credit_risk_db.credit_risk`)
and analyzed with 15 queries covering aggregation, `GROUP BY`, `HAVING`,
`CASE WHEN`, filtering, a window function (`RANK() OVER`), and a CTE. All 15
queries were run and verified against a real MySQL 8.0 instance. Highlights:

- Overall bad-risk rate: **30.0%** (300 / 1,000).
- `RANK() OVER (ORDER BY bad_risk_pct DESC)` ranks credit-history categories by
  risk, confirming the EDA finding directly in SQL.
- A CTE compares each loan purpose's bad-risk rate against the portfolio
  average (`education` is +14.0 points above average; `car (used)` is -13.5
  points below).
- A `CASE WHEN` query flags `foreign_worker = 'no'` as a small sample (37
  customers) that shouldn't be trusted at face value, even though its raw
  bad-risk rate (10.8%) looks very favorable.

See `sql/analysis.sql` for the full, commented query list.

---

## 8. Model-Ready Data & Machine Learning (`notebooks/03_modeling.ipynb`)

The cleaned dataset is split into an 80/20 **stratified** train/test split (800 /
200 rows, both preserving the 70/30 Good/Bad ratio), and that split is written out
to `data/processed/train_set.csv` and `data/processed/test_set.csv` as its own
pipeline output - a clear handoff point between "cleaned data" and "modeling,"
and something that could be reused without re-running the split.

A single **Logistic Regression** model is then trained on top of it:

- `StandardScaler` on numeric features, `OneHotEncoder` on categorical features,
  combined in one `ColumnTransformer` / `Pipeline` so the same preprocessing is
  always applied consistently and fit only on the training data (no leakage from
  the test set).
- `class_weight="balanced"` to account for the 70/30 class imbalance, as a
  single, easy-to-explain parameter rather than resampling the data (e.g. SMOTE).

A single model was used deliberately, rather than comparing several, to keep the
pipeline focused on doing one thing well - clean data in, a correctly evaluated,
explainable model out.

---

## 9. Evaluation & Results

**Why accuracy alone isn't enough:** the test set is ~70% Good / 30% Bad, so a
model that always predicts "Good" would score 70% accuracy while never catching
a single risky customer. Precision/recall/F1 on the Bad class, and ROC-AUC,
matter more here.

| Metric            | Logistic Regression |
|--------------------|:-------------------:|
| Accuracy           | 0.760                |
| Precision (Bad)    | 0.570                |
| Recall (Bad)       | 0.817                |
| F1 (Bad)           | 0.671                |
| ROC-AUC            | 0.807                |

Confusion matrix (rows = actual, columns = predicted, order = Good/Bad):

`[[103, 37], [11, 49]]` → the model catches 49 of 60 Bad-risk customers in the
test set (recall 81.7%), at the cost of 37 false alarms on Good-risk customers.

An ROC-AUC of 0.807 means the model does a solid, if imperfect, job of ranking
risky applicants above safe ones across every possible decision threshold - not
just the 0.5 cutoff used for the confusion matrix above.

### Model interpretation

- Coefficients most associated with **higher** risk: `checking_status: < 0 DM`,
  `purpose: education`, `credit_history: no credits / all paid duly`, `purpose:
  car (new)`. Most associated with **lower** risk: `checking_status: no checking
  account`, `credit_history: critical / other credits existing`, `purpose: car
  (used)`.
  (`foreign_worker: yes` had the single largest coefficient, but only 37 of
  1,000 customers are `foreign_worker: no`, so that estimate is based on a very
  small comparison group and is called out as low-confidence in the notebook.)
- These are **associations, not proof of causation** - e.g. "critical account"
  applicants being lower-risk likely reflects how this specific applicant pool
  was originally screened, not a general rule that risk-taking history causes
  good repayment.

---

## 10. Business Insights

Based on the EDA, SQL, and modeling above:

- **Checking account status is the single clearest risk signal available**:
  applicants with a negative balance (`< 0 DM`) have a 49.3% bad-risk rate vs
  11.7% for applicants with no checking account on record at all. This is a
  simple, explainable segment a bank could use as an early screening signal.
- **Employment stability and age matter**: applicants employed <1 year or
  unemployed, and applicants aged 19-25, both show noticeably higher bad-risk
  rates than the rest of the portfolio. These could support requiring
  additional documentation or a co-signer for that segment, rather than an
  automatic decline.
- **Loan purpose is informative but uneven in sample size**: education and new
  car loans skew riskier; used car loans skew safer. Purposes with fewer than
  ~20 applicants (domestic appliances, retraining, "other") shouldn't be used
  to set policy on their own.
- **A model can support triage, not replace judgment**: the Logistic Regression
  model catches about 82% of Bad-risk applicants in this test set, but also
  misclassifies a meaningful share of Good-risk applicants as risky (a 37/140
  false-alarm rate here). In practice this kind of model is best used to flag
  applications for manual review, not to auto-decline.

### Limitations

- **Small, dated sample**: 1,000 applications from 1994 Germany. Relationships
  found here (e.g. specific risk-by-purpose rates) may not generalize to a
  different market, country, or time period.
- **No income or debt-to-income data**: the dataset doesn't include applicant
  income directly, only proxies like installment rate and savings status.
- **Sensitive attributes**: the dataset includes personal status/sex and age,
  which are protected characteristics in many real lending contexts (e.g. the
  US Equal Credit Opportunity Act restricts using sex directly in credit
  decisions). This project uses them for analysis and modeling as-is because
  it's a historical academic dataset, but a production system would need a
  fairness review before using such features, and some jurisdictions would
  require removing them entirely.
- **Cost-sensitivity was approximated, not exact**: `class_weight="balanced"`
  approximates caring more about the minority (Bad) class, but doesn't
  precisely reproduce the dataset's documented 5:1 misclassification cost
  ratio. A more advanced version could set `class_weight={0: 1, 1: 5}`
  directly.
- **Small subgroups**: a few categories (e.g. `foreign_worker: no`, `purpose:
  retraining`) have fewer than 40 customers and their risk rates should be
  treated as directional, not solid conclusions.
- **Single model**: only Logistic Regression was built. It was chosen for
  interpretability and a clean, correct pipeline - a production system might
  compare it against other model types before settling on one.

---

## 11. Setup / Run Instructions (Ubuntu/Linux)

### 11.1 Clone and set up a virtual environment

```bash
git clone <your-repo-url> credit-risk-analysis
cd credit-risk-analysis

python3 -m venv venv
source venv/bin/activate

pip install -r requirements.txt
```

### 11.2 Dataset placement

The raw dataset is already included at `data/raw/german.data` (and
`data/raw/german.names` with the attribute documentation), so no download step
is required.

### 11.3 MySQL setup

```bash
sudo apt update
sudo apt install mysql-server
sudo service mysql start
```

`LOAD DATA LOCAL INFILE` (used in `sql/analysis.sql` to load the processed CSV)
needs to be enabled on both the server and the client:

```bash
# Enable on the server (run once per server session, or add
# local_infile=1 under [mysqld] in /etc/mysql/my.cnf to make it permanent)
mysql -u root -e "SET GLOBAL local_infile = 1;"
```

Then, before running the script, update the file path in the
`LOAD DATA LOCAL INFILE '...'` line near the top of `sql/analysis.sql` to the
absolute path of your `data/processed/german_credit_processed.csv`, and run it
with the client-side flag enabled:

```bash
mysql --local-infile=1 -u root < sql/analysis.sql
```

This creates the `credit_risk_db` database, creates the `credit_risk` table,
loads the data, and runs all 15 analyst queries.

### 11.4 Run the notebooks

```bash
jupyter notebook
```

Then open and run, **in order**:

1. `notebooks/01_data_cleaning.ipynb`
2. `notebooks/02_eda.ipynb`
3. `notebooks/03_modeling.ipynb`

---

## 12. Execution Order

```text
data/raw/german.data
   → 01_data_cleaning.ipynb  (cleans + engineers features)
   → data/processed/german_credit_processed.csv
   → 02_eda.ipynb            (visual + written EDA)
   → sql/analysis.sql        (load into MySQL, run analyst queries)
   → 03_modeling.ipynb       (train/test split -> model-ready data,
                               Logistic Regression, evaluation)
   → data/processed/train_set.csv, test_set.csv
   → business insights (this README, Section 10)
```

---

## 13. Project Structure

```text
credit-risk-analysis/
├── data/
│   ├── raw/
│   │   ├── german.data              # raw UCI dataset (coded)
│   │   └── german.names             # official attribute documentation
│   └── processed/
│       ├── german_credit_processed.csv  # cleaned, full dataset
│       ├── train_set.csv                # model-ready training split
│       └── test_set.csv                 # model-ready test split
├── notebooks/
│   ├── 01_data_cleaning.ipynb
│   ├── 02_eda.ipynb
│   └── 03_modeling.ipynb
├── sql/
│   └── analysis.sql
├── src/
│   └── preprocessing.py
├── requirements.txt
├── README.md
└── .gitignore
```

---

## 14. Tech Stack

Python, Pandas, NumPy, Matplotlib, Seaborn, Scikit-learn, MySQL, Jupyter Notebook.
