-- ============================================================
-- Q1_grade_default_rate
-- ============================================================
SELECT
    grade,
    sub_grade,
    COUNT(*) AS total_loans,
    SUM(target) AS total_defaults,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_interest_rate,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_amount,
    ROUND(AVG(annual_inc), 0) AS avg_annual_income,
    ROUND(AVG(dti), 2) AS avg_dti
FROM loans
GROUP BY grade, sub_grade
ORDER BY grade, sub_grade

-- ============================================================
-- Q2_purpose_risk
-- ============================================================
SELECT
    purpose,
    COUNT(*) AS total_loans,
    SUM(target) AS total_defaults,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_interest_rate,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_amount,
    ROUND(SUM(loan_amnt), 0) AS total_exposure
FROM loans
GROUP BY purpose
HAVING COUNT(*) > 1000
ORDER BY default_rate_pct DESC

-- ============================================================
-- Q3_portfolio_exposure
-- ============================================================
SELECT
    grade,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_amnt), 0) AS total_exposure,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(SUM(loan_amnt) * AVG(target) * 0.6, 0) AS expected_loss,
    ROUND(
        SUM(loan_amnt) * AVG(target) * 0.6
        / SUM(SUM(loan_amnt) * AVG(target) * 0.6)
        OVER () * 100
    , 2) AS pct_of_total_loss
FROM loans
GROUP BY grade
ORDER BY grade

-- ============================================================
-- Q4_vintage_analysis
-- ============================================================
SELECT
    issue_year,
    COUNT(*) AS total_loans,
    SUM(target) AS total_defaults,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_interest_rate,
    ROUND(AVG(dti), 2) AS avg_dti,
    ROUND(AVG(fico_avg), 0) AS avg_fico
FROM loans
WHERE issue_year IS NOT NULL
GROUP BY issue_year
ORDER BY issue_year

-- ============================================================
-- Q5_cumulative_defaults
-- ============================================================
WITH yearly AS (
    SELECT
        issue_year,
        COUNT(*) AS loans_issued,
        SUM(target) AS defaults_that_year,
        ROUND(SUM(loan_amnt), 0) AS volume_issued
    FROM loans
    WHERE issue_year IS NOT NULL
    GROUP BY issue_year
)
SELECT
    issue_year,
    loans_issued,
    defaults_that_year,
    volume_issued,
    SUM(loans_issued) OVER (ORDER BY issue_year) AS cumulative_loans,
    SUM(defaults_that_year) OVER (ORDER BY issue_year) AS cumulative_defaults,
    SUM(volume_issued) OVER (ORDER BY issue_year) AS cumulative_volume,
    ROUND(
        SUM(defaults_that_year) OVER (ORDER BY issue_year) * 100.0
        / SUM(loans_issued) OVER (ORDER BY issue_year)
    , 2) AS cumulative_default_rate_pct
FROM yearly
ORDER BY issue_year

-- ============================================================
-- Q6_risk_quartiles
-- ============================================================
WITH ranked AS (
    SELECT
        grade,
        int_rate,
        dti,
        fico_avg,
        loan_amnt,
        target,
        NTILE(4) OVER (ORDER BY int_rate DESC) AS risk_quartile
    FROM loans
    WHERE int_rate IS NOT NULL
)
SELECT
    risk_quartile,
    CASE risk_quartile
        WHEN 1 THEN 'Q1 - Highest Risk'
        WHEN 2 THEN 'Q2 - High Risk'
        WHEN 3 THEN 'Q3 - Medium Risk'
        WHEN 4 THEN 'Q4 - Low Risk'
    END AS risk_label,
    COUNT(*) AS total_loans,
    ROUND(AVG(int_rate), 2) AS avg_int_rate,
    ROUND(AVG(dti), 2) AS avg_dti,
    ROUND(AVG(fico_avg), 0) AS avg_fico,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(SUM(loan_amnt), 0) AS total_exposure
FROM ranked
GROUP BY risk_quartile
ORDER BY risk_quartile

-- ============================================================
-- Q7_state_exposure
-- ============================================================
SELECT
    addr_state,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_amnt), 0) AS total_exposure,
    SUM(target) AS total_defaults,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(AVG(dti), 2) AS avg_dti,
    ROUND(AVG(fico_avg), 0) AS avg_fico,
    RANK() OVER (
        ORDER BY AVG(target) DESC
    ) AS risk_rank
FROM loans
WHERE addr_state IS NOT NULL
GROUP BY addr_state
HAVING COUNT(*) > 500
ORDER BY default_rate_pct DESC
LIMIT 20

-- ============================================================
-- Q8_monthly_trend
-- ============================================================
WITH monthly AS (
    SELECT
        issue_year,
        issue_month,
        COUNT(*) AS total_loans,
        SUM(target) AS total_defaults,
        ROUND(AVG(target) * 100, 2) AS default_rate_pct
    FROM loans
    WHERE issue_year IS NOT NULL
      AND issue_month IS NOT NULL
    GROUP BY issue_year, issue_month
)
SELECT
    issue_year,
    issue_month,
    total_loans,
    total_defaults,
    default_rate_pct,
    LAG(default_rate_pct) OVER (
        ORDER BY issue_year, issue_month
    ) AS prev_month_default_rate,
    ROUND(
        default_rate_pct -
        LAG(default_rate_pct) OVER (
            ORDER BY issue_year, issue_month
        )
    , 2) AS mom_change_pct
FROM monthly
ORDER BY issue_year, issue_month

-- ============================================================
-- Q9_high_risk_profile
-- ============================================================
WITH high_risk AS (
    SELECT *
    FROM loans
    WHERE dti > 25
      AND int_rate > 16
      AND fico_avg < 700
),
risk_summary AS (
    SELECT
        grade,
        purpose,
        COUNT(*) AS borrower_count,
        ROUND(AVG(target) * 100, 2) AS default_rate_pct,
        ROUND(AVG(loan_amnt), 0) AS avg_loan_amnt,
        ROUND(AVG(dti), 2) AS avg_dti,
        ROUND(AVG(int_rate), 2) AS avg_int_rate,
        ROUND(AVG(fico_avg), 0) AS avg_fico,
        ROUND(SUM(loan_amnt) * AVG(target) * 0.6, 0) AS expected_loss
    FROM high_risk
    GROUP BY grade, purpose
    HAVING COUNT(*) > 100
)
SELECT *
FROM risk_summary
ORDER BY default_rate_pct DESC
LIMIT 15

-- ============================================================
-- Q10_dti_bucket_analysis
-- ============================================================
WITH dti_buckets AS (
    SELECT *,
        CASE
            WHEN dti < 10 THEN '1. 0-10%'
            WHEN dti < 20 THEN '2. 10-20%'
            WHEN dti < 30 THEN '3. 20-30%'
            WHEN dti < 40 THEN '4. 30-40%'
            ELSE '5. 40%+'
        END AS dti_bucket
    FROM loans
    WHERE dti IS NOT NULL
)
SELECT
    dti_bucket,
    COUNT(*) AS total_loans,
    ROUND(AVG(target) * 100, 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate,
    ROUND(AVG(fico_avg), 0) AS avg_fico,
    ROUND(SUM(loan_amnt), 0) AS total_exposure,
    LAG(ROUND(AVG(target) * 100, 2)) OVER (
        ORDER BY dti_bucket
    ) AS prev_bucket_default_rate,
    ROUND(
        ROUND(AVG(target) * 100, 2) -
        LAG(ROUND(AVG(target) * 100, 2)) OVER (
            ORDER BY dti_bucket
        )
    , 2) AS rate_increase_vs_prev_bucket
FROM dti_buckets
GROUP BY dti_bucket
ORDER BY dti_bucket

