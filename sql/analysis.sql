-- ---------------------------------------------------------------------
-- SECTION 1: Database, table, and data load
-- ---------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS credit_risk_db;
USE credit_risk_db;

DROP TABLE IF EXISTS credit_risk;

CREATE TABLE credit_risk (
    customer_id           INT AUTO_INCREMENT PRIMARY KEY,
    checking_status        VARCHAR(50),
    duration_months        INT,
    credit_history          VARCHAR(50),
    purpose                 VARCHAR(50),
    credit_amount           INT,
    savings_status          VARCHAR(50),
    employment_since        VARCHAR(50),
    installment_rate        INT,
    personal_status_sex     VARCHAR(50),
    other_debtors           VARCHAR(20),
    residence_since         INT,
    property                 VARCHAR(50),
    age                     INT,
    other_installment_plans VARCHAR(20),
    housing                  VARCHAR(20),
    existing_credits        INT,
    job                     VARCHAR(60),
    num_dependents          INT,
    telephone                VARCHAR(10),
    foreign_worker           VARCHAR(10),
    risk                     VARCHAR(10),
    age_group                VARCHAR(10),
    credit_per_month        DECIMAL(10, 2)
);

-- LOAD DATA LOCAL INFILE requires local_infile to be enabled on both the server and the client.
LOAD DATA LOCAL INFILE '/home/aman/Projects/files/credit-risk-analysis/data/processed/german_credit_processed.csv'
INTO TABLE credit_risk
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(checking_status, duration_months, credit_history, purpose, credit_amount,
 savings_status, employment_since, installment_rate, personal_status_sex,
 other_debtors, residence_since, property, age, other_installment_plans,
 housing, existing_credits, job, num_dependents, telephone, foreign_worker,
 risk, age_group, credit_per_month);

SELECT COUNT(*) AS total_rows FROM credit_risk;

-- ---------------------------------------------------------------------
-- SECTION 2: Analyst queries
-- ---------------------------------------------------------------------

-- Q1. Overall bad-risk rate
-- Simple aggregation: what share of the portfolio is classified as Bad risk.
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) AS bad_risk_customers,
    ROUND(SUM(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS bad_risk_pct
FROM credit_risk;

-- Q2. Bad-risk rate by credit history, sorted worst first
-- GROUP BY + CASE WHEN + ROUND, ordered to surface the riskiest categories.
SELECT
    credit_history,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY credit_history
ORDER BY bad_risk_pct DESC;

-- Q3. Bad-risk rate by loan purpose, only purposes with a meaningful sample size
-- GROUP BY + HAVING to filter out purposes with too few customers to trust.
SELECT
    purpose,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY purpose
HAVING COUNT(*) >= 20
ORDER BY bad_risk_pct DESC;

-- Q4. Bad-risk rate by employment length
SELECT
    employment_since,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY employment_since
ORDER BY bad_risk_pct DESC;

-- Q5. Bad-risk rate by age group
SELECT
    age_group,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY age_group
ORDER BY age_group;

-- Q6. Average loan amount and duration by risk class
-- Comparison query: do Bad-risk loans tend to be larger or longer?
SELECT
    risk,
    ROUND(AVG(credit_amount), 0) AS avg_credit_amount,
    ROUND(AVG(duration_months), 1) AS avg_duration_months,
    ROUND(AVG(credit_per_month), 1) AS avg_monthly_repayment_burden
FROM credit_risk
GROUP BY risk;

-- Q7. Loan size segments and their bad-risk rate
-- CASE WHEN used to build custom buckets directly in SQL.
SELECT
    CASE
        WHEN credit_amount < 2000 THEN '1. Under 2000 DM'
        WHEN credit_amount < 5000 THEN '2. 2000-4999 DM'
        WHEN credit_amount < 10000 THEN '3. 5000-9999 DM'
        ELSE '4. 10000+ DM'
    END AS loan_size_segment,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY loan_size_segment
ORDER BY loan_size_segment;

-- Q8. Checking account status vs risk (with row-level filtering)
-- Filtering: focus on applicants who do have a checking account on record.
SELECT
    checking_status,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
WHERE checking_status <> 'no checking account'
GROUP BY checking_status
ORDER BY bad_risk_pct DESC;

-- Q9. Housing situation vs risk, restricted to applicants who rent
-- Simple WHERE filter combined with aggregation.
SELECT
    housing,
    purpose,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
WHERE housing = 'rent'
GROUP BY housing, purpose
HAVING COUNT(*) >= 10
ORDER BY bad_risk_pct DESC;

-- Q10. Job type vs number of existing credits and risk
-- Multi-column GROUP BY segmentation.
SELECT
    job,
    existing_credits,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY job, existing_credits
HAVING COUNT(*) >= 15
ORDER BY job, existing_credits;

-- Q11. Rank credit-history categories by bad-risk rate using a window function
-- RANK() OVER (...) - a common analyst window-function pattern.
SELECT
    credit_history,
    num_customers,
    bad_risk_pct,
    RANK() OVER (ORDER BY bad_risk_pct DESC) AS risk_rank
FROM (
    SELECT
        credit_history,
        COUNT(*) AS num_customers,
        ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
    FROM credit_risk
    GROUP BY credit_history
) AS history_summary;

-- Q12. Each purpose's bad-risk rate vs the overall portfolio average
-- CTE + cross join to compare a group rate against the global rate.
WITH purpose_summary AS (
    SELECT
        purpose,
        COUNT(*) AS num_customers,
        ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
    FROM credit_risk
    GROUP BY purpose
),
overall AS (
    SELECT ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS overall_bad_risk_pct
    FROM credit_risk
)
SELECT
    p.purpose,
    p.num_customers,
    p.bad_risk_pct,
    o.overall_bad_risk_pct,
    ROUND(p.bad_risk_pct - o.overall_bad_risk_pct, 1) AS diff_vs_overall
FROM purpose_summary p
CROSS JOIN overall o
HAVING p.num_customers >= 20
ORDER BY diff_vs_overall DESC;

-- Q13. Foreign worker status vs risk, flagged with a small-sample warning
-- Demonstrates why sample size matters before trusting a group's risk rate.
SELECT
    foreign_worker,
    COUNT(*) AS num_customers,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct,
    CASE WHEN COUNT(*) < 50 THEN 'Small sample - interpret with caution' ELSE 'OK' END AS sample_size_flag
FROM credit_risk
GROUP BY foreign_worker;

-- Q14. Top 10 oldest applicants with a Bad risk rating
-- Simple filtering + sorting + LIMIT, useful for row-level drill-down.
SELECT
    customer_id, age, job, purpose, credit_amount, duration_months, risk
FROM credit_risk
WHERE risk = 'Bad'
ORDER BY age DESC
LIMIT 10;

-- Q15. Savings status vs average installment rate and risk
-- A three-way look: savings level, how much of disposable income goes to
-- the loan, and how that relates to risk.
SELECT
    savings_status,
    COUNT(*) AS num_customers,
    ROUND(AVG(installment_rate), 2) AS avg_installment_rate,
    ROUND(AVG(CASE WHEN risk = 'Bad' THEN 1 ELSE 0 END) * 100, 1) AS bad_risk_pct
FROM credit_risk
GROUP BY savings_status
ORDER BY bad_risk_pct DESC;
