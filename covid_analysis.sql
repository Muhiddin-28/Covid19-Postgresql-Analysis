/* 
===============================================================================
COVID-19 Data Analysis View & Queries (PostgreSQL)
===============================================================================

This script:
1. Creates a combined view of COVID-19 deaths and vaccination data.
2. Calculates death percentage and full vaccination rate.
3. Displays death percentage trends by country.
4. Identifies the Top 10 countries with the highest death percentage (filtered).
5. Performs a basic aggregation analysis of average death percentage vs. vaccination rate.
6. Calculates the correlation coefficient between death percentage and vaccination rate.
===============================================================================
*/

-- ============================================================================
-- 1. Create or replace a VIEW combining COVID deaths and vaccinations data
-- ============================================================================
CREATE OR REPLACE VIEW covid_combined AS
SELECT 
    d.country,                           -- Country name
    d.date,                              -- Observation date
    d.total_cases,                       -- Total confirmed cases so far
    d.total_deaths,                      -- Total deaths so far

    -- Death percentage = (total deaths / total cases) * 100
    ROUND(
        (d.total_deaths::numeric * 100) / NULLIF(d.total_cases, 0)::numeric, 
        2
    ) AS death_percentage,

    v.total_vaccinations,                -- Total vaccine doses administered
    v.people_vaccinated,                 -- Number of people with at least one dose
    v.people_fully_vaccinated,           -- Number of people fully vaccinated

    -- Full vaccination rate = (fully vaccinated people / total population) * 100
    ROUND(
        (v.people_fully_vaccinated::numeric * 100) / NULLIF(v.population, 0)::numeric, 
        2
    ) AS full_vaccination_rate,

    v.reproduction_rate                  -- Estimated virus reproduction rate (R-value)
FROM covid_deaths d
JOIN covid_vaccinations v
    ON d.country = v.country 
    AND d.date = v.date;                 -- Ensure data matches both by country and date


-- ============================================================================
-- 2. Show death percentage trend by country and date
-- ============================================================================
SELECT 
    country, 
    date, 
    total_cases, 
    total_deaths,
    ROUND(
        (total_deaths::numeric * 100) / NULLIF(total_cases, 0)::numeric, 
        2
    ) AS death_percentage
FROM covid_combined
ORDER BY country, date;  -- Ordered to see time trend for each country


-- ============================================================================
-- 3. Top 10 countries with the highest death percentage
--    - Filters out small sample sizes (total_cases > 1000)
--    - Ensures deaths are not more than total cases
--    - Picks the highest death percentage for each country
-- ============================================================================
SELECT 
    country, 
    date, 
    total_cases, 
    total_deaths, 
    death_percentage
FROM (
    SELECT 
        country, 
        date, 
        total_cases, 
        total_deaths,

        ROUND(
            (total_deaths::numeric * 100.0) / NULLIF(total_cases, 0), 
            2
        ) AS death_percentage,

        -- Assigns rank within each country based on death percentage (highest first)
        ROW_NUMBER() OVER (
            PARTITION BY country 
            ORDER BY 
                ROUND((total_deaths::numeric * 100.0) / NULLIF(total_cases, 0), 2) DESC
        ) AS rn
    FROM covid_combined
    WHERE total_cases > 1000           -- Ignore countries with too few cases
      AND total_deaths <= total_cases  -- Basic data sanity check
) sub
WHERE rn = 1                           -- Keep only the highest death percentage per country
ORDER BY death_percentage DESC         -- Sort by highest death percentage globally
LIMIT 10;                              -- Take top 10 countries


-- ============================================================================
-- 4. Aggregated analysis: Average death % vs. average vaccination rate by country
--    - Only includes countries with avg. full vaccination rate > 20%
-- ============================================================================
SELECT 
    country,
    ROUND(AVG(death_percentage), 2) AS avg_death,          -- Avg. death %
    ROUND(AVG(full_vaccination_rate), 2) AS avg_vaccinated -- Avg. full vaccination %
FROM covid_combined
GROUP BY country
HAVING AVG(full_vaccination_rate) > 20                     -- Filter countries with decent vaccine coverage
ORDER BY avg_death DESC;                                   -- Sort by highest avg. death %


-- ============================================================================
-- 5. Correlation analysis: 
--    Measures statistical relationship between death_percentage and full_vaccination_rate
--    Using Pearson correlation coefficient:
--      +1.0 = Strong positive correlation
--      -1.0 = Strong negative correlation
--       0.0 = No correlation
-- ============================================================================
SELECT 
    corr(death_percentage, full_vaccination_rate) AS correlation_coef
FROM covid_combined
WHERE total_cases > 1000;    -- Filter to remove unreliable small samples
