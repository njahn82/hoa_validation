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

wos_ta_by_year <- dbGetQuery(bq_con, "WITH
  jct_short AS (
  SELECT
    DISTINCT item_id,
    earliest_year,
    CASE
      WHEN author_seq_nr = 1 THEN item_id
      ELSE NULL
  END
    AS is_first_author,
    CASE
      WHEN corresponding = TRUE THEN item_id
      ELSE NULL
  END
    AS is_corresponding_author,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN item_id
      ELSE NULL
  END
    AS is_oa,
    core
  FROM
    `hoa-article.hoa_comparision.wos_jct_match`),
  article_stats AS (
  SELECT
    earliest_year,
    'all' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  GROUP BY
    earliest_year
  UNION ALL
  SELECT
    earliest_year,
    'core' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  WHERE
    core = TRUE
  GROUP BY
    earliest_year )
SELECT
  earliest_year,
  pubtype,
  ta_articles,
  ta_oa_articles,
  -- Output for first author articles
  ta_first_author_articles,
  ta_oa_first_author_articles,
  -- Output for corresponding author articles
  ta_corresponding_author_articles,
  ta_oa_corresponding_author_articles,
  -- Output for first + corresponding author articles
  ta_first_corresponding_author_articles,
  ta_oa_first_corresponding_author_articles
FROM
  article_stats
ORDER BY
  earliest_year DESC")
#' Save results
wos_ta_by_year |>
  filter(between(earliest_year, 2018, 2023)) |>
  write_csv(here::here("data", "wos_ta_by_year.csv"))


#' by journal

wos_jn_ta_by_year <- dbGetQuery(bq_con, "WITH
  jct_short AS (
  SELECT
    DISTINCT item_id,
    issn_l,
    earliest_year,
    CASE
      WHEN author_seq_nr = 1 THEN item_id
      ELSE NULL
  END
    AS is_first_author,
    CASE
      WHEN corresponding = TRUE THEN item_id
      ELSE NULL
  END
    AS is_corresponding_author,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN item_id
      ELSE NULL
  END
    AS is_oa,
    core
  FROM
    `hoa-article.hoa_comparision.wos_jct_match`),
  article_stats AS (
  SELECT
    issn_l,
    earliest_year,
    'all' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  GROUP BY
    issn_l,
    earliest_year
  UNION ALL
  SELECT
    issn_l,
    earliest_year,
    'core' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  WHERE
    core = TRUE
  GROUP BY
    issn_l,
    earliest_year)
SELECT
  issn_l,
  earliest_year,
  pubtype,
  ta_articles,
  ta_oa_articles,
  -- Output for first author articles
  ta_first_author_articles,
  ta_oa_first_author_articles,
  -- Output for corresponding author articles
  ta_corresponding_author_articles,
  ta_oa_corresponding_author_articles,
  -- Output for first + corresponding author articles
  ta_first_corresponding_author_articles,
  ta_oa_first_corresponding_author_articles
FROM
  article_stats
ORDER BY
  earliest_year DESC")
#' Save results
wos_jn_ta_by_year |>
  filter(between(earliest_year, 2018, 2023)) |>
  write_csv(here::here("data", "wos_jn_ta_by_year.csv"))

### Scopus

scp_by_year <- dbGetQuery(bq_con, "WITH
  items_by_year AS (
  SELECT
    DISTINCT scp.item_id,
    first_pubyear AS earliest_year,
    REGEXP_CONTAINS(scp.oa_status, 'hybrid') AS is_oa,
    REGEXP_CONTAINS(item_type, '^Article|^Review') AS core
  FROM
    `hoa-article.hoa_comparision.scp_jct_items` AS scp ),
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
    SAFE_DIVIDE(n_oa_articles, n_articles) AS p
  FROM
    article_counts ),
  core_oa AS (
  SELECT
    earliest_year,
    'core' AS pub_type,
    n_core_articles AS n_articles,
    n_core_oa_articles AS n_oa_articles,
    SAFE_DIVIDE(n_core_oa_articles, n_core_articles) AS p
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
scp_by_year |>
  # Would be great to filter by year using BQ
  filter(between(earliest_year, 2018, 2023)) |>
  write_csv(here::here("data", "scp_by_year.csv"))

scp_jn_by_year <- dbGetQuery(bq_con, "  -- Step 1: Extract relevant data with distinct item_id
WITH
  items_by_year AS (
  SELECT
    DISTINCT scp.item_id,
    first_pubyear AS earliest_year,
    REGEXP_CONTAINS(scp.oa_status, 'hybrid') AS is_oa,
    REGEXP_CONTAINS(item_type, '^Article|^Review') AS core,
    scp.issn_l
  FROM
    `hoa-article.hoa_comparision.scp_jct_items` AS scp ),
  -- Step 2: Aggregate article counts by year and issn_l
  article_counts AS (
  SELECT
    issn_l,
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
    issn_l,
    earliest_year ),
  -- Step 3: Calculate OA percentages for all articles
  all_oa AS (
  SELECT
    issn_l,
    earliest_year,
    'all' AS pub_type,
    n_articles,
    n_oa_articles,
    SAFE_DIVIDE(n_oa_articles, n_articles) AS p
  FROM
    article_counts ),
  -- Step 4: Calculate OA percentages for core articles
  core_oa AS (
  SELECT
    issn_l,
    earliest_year,
    'core' AS pub_type,
    n_core_articles AS n_articles,
    n_core_oa_articles AS n_oa_articles,
    SAFE_DIVIDE(n_core_oa_articles, n_core_articles) AS p
  FROM
    article_counts )
  -- Step 5: Combine and sort results
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
  issn_l,
  earliest_year DESC")
scp_jn_by_year |>
  filter(between(earliest_year, 2018, 2023)) |>
  write_csv(here::here("data", "scp_jn_by_year.csv"))

#' Focus on TA articles

scp_ta_by_year <- dbGetQuery(bq_con, "WITH
  jct_short AS (
  SELECT
    DISTINCT item_id,
    first_pubyear,
    CASE
      WHEN author_seq_nr = 1 THEN item_id
      ELSE NULL
  END
    AS is_first_author,
    CASE
      WHEN corresponding = TRUE THEN item_id
      ELSE NULL
  END
    AS is_corresponding_author,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN item_id
      ELSE NULL
  END
    AS is_oa,
    core
  FROM
    `hoa-article.hoa_comparision.scp_jct_match`),
  article_stats AS (
  SELECT
    first_pubyear,
    'all' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  GROUP BY
    first_pubyear
  UNION ALL
  SELECT
    first_pubyear,
    'core' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  WHERE
    core = TRUE
  GROUP BY
    first_pubyear )
SELECT
  first_pubyear,
  pubtype,
  ta_articles,
  ta_oa_articles,
  -- Output for first author articles
  ta_first_author_articles,
  ta_oa_first_author_articles,
  -- Output for corresponding author articles
  ta_corresponding_author_articles,
  ta_oa_corresponding_author_articles,
  -- Output for first + corresponding author articles
  ta_first_corresponding_author_articles,
  ta_oa_first_corresponding_author_articles
FROM
  article_stats
ORDER BY
  first_pubyear DESC")

#' Save results
scp_ta_by_year |>
  filter(between(first_pubyear, 2018, 2023)) |>
  write_csv(here::here("data", "scp_ta_by_year.csv"))

scp_ta_jn_by_year <- dbGetQuery(bq_con, "WITH
  jct_short AS (
  SELECT
    DISTINCT item_id,
    issn_l,
    first_pubyear,
    CASE
      WHEN author_seq_nr = 1 THEN item_id
      ELSE NULL
  END
    AS is_first_author,
    CASE
      WHEN corresponding = TRUE THEN item_id
      ELSE NULL
  END
    AS is_corresponding_author,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN item_id
      ELSE NULL
  END
    AS is_oa,
    core
  FROM
    `hoa-article.hoa_comparision.scp_jct_match` ),
  article_stats AS (
  SELECT
    issn_l,
    first_pubyear,
    'all' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  GROUP BY
    issn_l,
    first_pubyear
  UNION ALL
  SELECT
    issn_l,
    first_pubyear,
    'core' AS pubtype,
    COUNT(DISTINCT item_id) AS ta_articles,
    COUNT(DISTINCT is_oa) AS ta_oa_articles,
    COUNT(DISTINCT is_first_author) AS ta_first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS ta_oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS ta_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS ta_oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS ta_oa_first_corresponding_author_articles
  FROM
    jct_short
  WHERE
    core = TRUE
  GROUP BY
    issn_l,
    first_pubyear )
SELECT
  issn_l,
  first_pubyear,
  pubtype,
  ta_articles,
  ta_oa_articles,
  ta_first_author_articles,
  ta_oa_first_author_articles,
  ta_corresponding_author_articles,
  ta_oa_corresponding_author_articles,
  ta_first_corresponding_author_articles,
  ta_oa_first_corresponding_author_articles
FROM
  article_stats
ORDER BY
  first_pubyear DESC,
  issn_l")

scp_ta_jn_by_year |>
  filter(between(first_pubyear, 2018, 2023)) |>
  write_csv(here::here("data", "scp_ta_jn_by_year.csv"))
