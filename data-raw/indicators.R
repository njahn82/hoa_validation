#' Indicator datasets
library(tidyverse)
library(DBI)
library(bigrquery)
#' Database connection
bq_con <- dbConnect(bigrquery::bigquery(), 
                    project = "subugoe-collaborative", 
                    billing = "subugoe-collaborative")
#' ## Web of Science
#' 
#' ### Overview
wos_by_year <- dbGetQuery(bq_con, "WITH
  items_by_year AS (
  SELECT
    DISTINCT wos.item_id,
    COALESCE(CAST(REGEXP_EXTRACT(wos_pubdate_online, r'^[0-9]{4}') AS NUMERIC), pubyear) AS earliest_year,
    REGEXP_CONTAINS(wos.oa_status, 'hybrid') AS is_oa,
    REGEXP_CONTAINS(item_type, 'Article|^Review$') AS core
  FROM
    `hoa-article.hoa_comparision.wos_jct_items` AS wos ),
  article_counts AS (
  SELECT
    earliest_year,
    COUNT(DISTINCT item_id) AS n_articles,
    SUM(CASE
        WHEN core = TRUE THEN 1
        ELSE 0
    END
      ) AS n_core_articles,
    SUM(CASE
        WHEN is_oa = TRUE THEN 1
        ELSE 0
    END
      ) AS n_oa_articles,
    SUM(CASE
        WHEN is_oa = TRUE AND core = TRUE THEN 1
        ELSE 0
    END
      ) AS n_core_oa_articles
  FROM
    items_by_year
  GROUP BY
    earliest_year ),
  all_oa AS (
  SELECT
    earliest_year,
    'all' AS pub_type,
    n_articles,
    n_oa_articles,
    n_oa_articles / n_articles AS p
  FROM
    article_counts ),
  core_oa AS (
  SELECT
    earliest_year,
    'core' AS pub_type,
    n_core_articles AS n_articles,
    n_core_oa_articles AS n_oa_articles,
    n_core_oa_articles / n_core_articles AS p
  FROM
    article_counts )
SELECT
  *
FROM
  all_oa
UNION ALL
SELECT
  *
FROM
  core_oa
ORDER BY
  earliest_year DESC")
#' Save results
wos_by_year |>
  filter(between(earliest_year, 2018, 2023)) |>
  write_csv(here::here("data", "wos_by_year.csv"))
#' ### by journal
wos_jn_by_year <- dbGetQuery(bq_con, "-- Step 1: Extract relevant data with distinct item_id
WITH items_by_year AS (
  SELECT
    DISTINCT wos.item_id,
    COALESCE(CAST(REGEXP_EXTRACT(wos_pubdate_online, r'^[0-9]{4}') AS NUMERIC), pubyear) AS earliest_year,
    REGEXP_CONTAINS(wos.oa_status, 'hybrid') AS is_oa,
    REGEXP_CONTAINS(item_type, 'Article|^Review$') AS core,
    wos.issn_l
  FROM
    `hoa-article.hoa_comparision.wos_jct_items` AS wos
),

-- Step 2: Aggregate article counts by year and issn_l
article_counts AS (
  SELECT
    issn_l,
    earliest_year,
    COUNT(DISTINCT item_id) AS n_articles,
    SUM(CASE WHEN core = TRUE THEN 1 ELSE 0 END) AS n_core_articles,
    SUM(CASE WHEN is_oa = TRUE THEN 1 ELSE 0 END) AS n_oa_articles,
    SUM(CASE WHEN is_oa = TRUE AND core = TRUE THEN 1 ELSE 0 END) AS n_core_oa_articles
  FROM
    items_by_year
  GROUP BY
    issn_l, earliest_year
),

-- Step 3: Calculate OA percentages for all articles
all_oa AS (
  SELECT
    issn_l,
    earliest_year,
    'all' AS pub_type,
    n_articles,
    n_oa_articles,
    -- Avoid division by zero by checking if n_articles > 0
    CASE WHEN n_articles > 0 THEN n_oa_articles / n_articles ELSE 0 END AS p
  FROM
    article_counts
),

-- Step 4: Calculate OA percentages for core articles
core_oa AS (
  SELECT
    issn_l,
    earliest_year,
    'core' AS pub_type,
    n_core_articles AS n_articles,
    n_core_oa_articles AS n_oa_articles,
    -- Avoid division by zero by checking if n_core_articles > 0
    CASE WHEN n_core_articles > 0 THEN n_core_oa_articles / n_core_articles ELSE 0 END AS p
  FROM
    article_counts
)

-- Step 5: Combine and sort results
SELECT * FROM all_oa
UNION ALL
SELECT * FROM core_oa
ORDER BY issn_l, earliest_year DESC")
#' Save results
wos_jn_by_year |>
  filter(between(earliest_year, 2018, 2023)) |>
  write_csv(here::here("data", "wos_jn_by_year.csv"))
#' Check distribution         
# wos_jn_by_year |>
#  filter(between(earliest_year, 2018, 2023)) |>
#  ggplot(aes(as.character(earliest_year), p, fill = pub_type)) +
#  geom_boxplot(outlier.shape = NA) +
#  scale_y_continuous(expand = expansion(mult = c(0, 0.05)),
#                     labels = scales::percent) +
#  coord_cartesian(ylim = c(0,0.8)) 
#' Focus on TA articles
