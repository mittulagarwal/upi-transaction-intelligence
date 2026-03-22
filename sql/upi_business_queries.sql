
-- UPI Transaction Intelligence — Business SQL Queries
-- Author: Mittul Agarwal
-- Data Source: NPCI Official UPI Ecosystem Statistics (2022-2025)
-- Database: SQLite (upi_intelligence.db)

-- Q1: Total UPI Market Size by Year
SELECT
    year,
    ROUND(SUM(total_vol_mn), 0)          AS total_volume_mn,
    ROUND(SUM(total_val_cr) / 100000, 2) AS total_value_lakh_cr,
    COUNT(DISTINCT app_name_std)          AS active_apps
FROM upi_apps
GROUP BY year
ORDER BY year;

-- Q2: Market Share % by App by Year (Top 4)
WITH yearly_total AS (
    SELECT year, SUM(total_vol_mn) AS market_vol
    FROM upi_apps GROUP BY year
),
app_yearly AS (
    SELECT year, app_name_std, SUM(total_vol_mn) AS app_vol
    FROM upi_apps
    WHERE app_name_std IN ('PhonePe','Google Pay','Paytm','BHIM')
    GROUP BY year, app_name_std
)
SELECT
    a.year,
    a.app_name_std,
    ROUND(a.app_vol, 0)                         AS volume_mn,
    ROUND(a.app_vol * 100.0 / t.market_vol, 2) AS market_share_pct
FROM app_yearly a
JOIN yearly_total t ON a.year = t.year
ORDER BY a.year, market_share_pct DESC;

-- Q3: Paytm Before vs After RBI Action
SELECT
    CASE
        WHEN year < 2024 THEN 'Before RBI Action'
        WHEN year = 2024 AND month < 2 THEN 'Before RBI Action'
        ELSE 'After RBI Action'
    END AS period,
    ROUND(AVG(total_vol_mn), 0) AS avg_monthly_volume_mn,
    ROUND(MAX(total_vol_mn), 0) AS peak_volume_mn,
    ROUND(MIN(total_vol_mn), 0) AS min_volume_mn,
    COUNT(*) AS months_count
FROM upi_apps
WHERE app_name_std = 'Paytm'
GROUP BY period
ORDER BY period DESC;

-- Q4: PhonePe vs Google Pay Annual Gap
WITH pp AS (
    SELECT year, SUM(total_vol_mn) AS pp_vol
    FROM upi_apps WHERE app_name_std = 'PhonePe'
    GROUP BY year
),
gp AS (
    SELECT year, SUM(total_vol_mn) AS gp_vol
    FROM upi_apps WHERE app_name_std = 'Google Pay'
    GROUP BY year
)
SELECT
    pp.year,
    ROUND(pp.pp_vol, 0)              AS phonePe_vol_mn,
    ROUND(gp.gp_vol, 0)              AS googlePay_vol_mn,
    ROUND(pp.pp_vol - gp.gp_vol, 0) AS gap_mn,
    ROUND(pp.pp_vol * 100.0 / gp.gp_vol, 1) AS phonePe_lead_pct
FROM pp JOIN gp ON pp.year = gp.year
ORDER BY pp.year;

-- Q5: Top 10 Apps in 2025
SELECT
    app_name_std,
    ROUND(SUM(total_vol_mn), 0) AS total_vol_mn,
    ROUND(SUM(total_val_cr), 0) AS total_val_cr,
    COUNT(DISTINCT month)       AS months_active
FROM upi_apps
WHERE year = 2025
GROUP BY app_name_std
ORDER BY total_vol_mn DESC
LIMIT 10;

-- Q6: Seasonality by Calendar Month
SELECT
    month,
    ROUND(AVG(total_vol_mn), 0) AS avg_vol_mn,
    ROUND(MAX(total_vol_mn), 0) AS peak_vol_mn,
    COUNT(DISTINCT year)        AS years_of_data
FROM upi_apps
GROUP BY month
ORDER BY avg_vol_mn DESC;

-- Q7: Fastest Growing Apps 2022 vs 2024
WITH y2022 AS (
    SELECT app_name_std, SUM(total_vol_mn) AS vol_2022
    FROM upi_apps WHERE year = 2022 GROUP BY app_name_std
),
y2024 AS (
    SELECT app_name_std, SUM(total_vol_mn) AS vol_2024
    FROM upi_apps WHERE year = 2024 GROUP BY app_name_std
)
SELECT
    a.app_name_std,
    ROUND(a.vol_2022, 0) AS vol_2022,
    ROUND(b.vol_2024, 0) AS vol_2024,
    ROUND((b.vol_2024 - a.vol_2022) * 100.0 / a.vol_2022, 1) AS growth_pct
FROM y2022 a
JOIN y2024 b ON a.app_name_std = b.app_name_std
WHERE a.vol_2022 > 100
ORDER BY growth_pct DESC
LIMIT 10;

-- Q8: Transaction Type Mix by Year
SELECT
    year,
    ROUND(SUM(cust_vol_mn), 0)  AS customer_initiated_mn,
    ROUND(SUM(b2c_vol_mn), 0)   AS b2c_mn,
    ROUND(SUM(b2b_vol_mn), 0)   AS b2b_mn,
    ROUND(SUM(cust_vol_mn) * 100.0 / NULLIF(SUM(total_vol_mn),0), 1) AS cust_pct,
    ROUND(SUM(b2c_vol_mn)  * 100.0 / NULLIF(SUM(total_vol_mn),0), 1) AS b2c_pct,
    ROUND(SUM(b2b_vol_mn)  * 100.0 / NULLIF(SUM(total_vol_mn),0), 1) AS b2b_pct
FROM upi_apps
GROUP BY year
ORDER BY year;

-- Q9: High Value Apps — Premium Transaction Processing
SELECT
    app_name_std,
    ROUND(SUM(total_vol_mn), 0) AS total_vol_mn,
    ROUND(SUM(total_val_cr), 0) AS total_val_cr,
    ROUND(SUM(total_val_cr) / NULLIF(SUM(total_vol_mn),0) * 10, 0) AS avg_txn_value_inr
FROM upi_apps
WHERE year >= 2023
  AND app_name_std NOT IN ('PhonePe','Google Pay','Paytm')
  AND total_vol_mn > 0
GROUP BY app_name_std
HAVING SUM(total_vol_mn) > 50
ORDER BY avg_txn_value_inr DESC
LIMIT 10;

-- Q10: Where Did Paytm's Lost Market Share Go?
WITH y2022 AS (
    SELECT app_name_std,
           SUM(total_vol_mn) * 100.0 /
           (SELECT SUM(total_vol_mn) FROM upi_apps WHERE year = 2022) AS share_2022
    FROM upi_apps WHERE year = 2022 GROUP BY app_name_std
),
y2024 AS (
    SELECT app_name_std,
           SUM(total_vol_mn) * 100.0 /
           (SELECT SUM(total_vol_mn) FROM upi_apps WHERE year = 2024) AS share_2024
    FROM upi_apps WHERE year = 2024 GROUP BY app_name_std
)
SELECT
    a.app_name_std,
    ROUND(a.share_2022, 2) AS share_2022_pct,
    ROUND(b.share_2024, 2) AS share_2024_pct,
    ROUND(b.share_2024 - a.share_2022, 2) AS share_change
FROM y2022 a
JOIN y2024 b ON a.app_name_std = b.app_name_std
WHERE ABS(b.share_2024 - a.share_2022) > 0.5
ORDER BY share_change DESC
LIMIT 10;
