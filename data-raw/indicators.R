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
SELECT *
FROM (SELECT
  *
FROM
  all_oa
UNION ALL
SELECT
  *
FROM
  core_oa
ORDER BY
  earliest_year DESC )
WHERE earliest_year BETWEEN 2019 AND 2023")
#' Save results
write_csv(wos_by_year, here::here("data", "wos_by_year.csv"))

#' ### by journal
wos_jn_by_year <- dbGetQuery(bq_con, "WITH
  tt AS (
  SELECT
    DISTINCT wos.item_id,
    COALESCE(CAST(REGEXP_EXTRACT(wos.wos_pubdate_online, r'^[0-9]{4}') AS NUMERIC), wos.pubyear) AS earliest_year,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN wos.item_id
      ELSE NULL
  END
    AS is_oa,
    CASE
      WHEN REGEXP_CONTAINS(item_type, 'Article|^Review$') THEN TRUE
      ELSE FALSE
  END
    AS is_core,
    wos.issn_l
  FROM
    `hoa-article.hoa_comparision.wos_jct_items` AS wos),
  -- Just core
  core_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    'core' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles,
  FROM
    tt
  WHERE
    is_core IS TRUE
  GROUP BY
    issn_l,
    earliest_year),
  -- All
  all_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    'all' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles
  FROM
    tt
  GROUP BY
    issn_l,
    earliest_year),
combined AS (SELECT
  *
FROM
  core_pubs
UNION ALL
SELECT
  *
FROM
  all_pubs
ORDER BY
  issn_l,
  earliest_year)
SELECT *
FROM combined
WHERE earliest_year BETWEEN 2019 AND 2023")
#' Save results
write_csv(wos_jn_by_year, here::here("data", "wos_jn_by_year.csv"))
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
WHERE earliest_year BETWEEN 2019 AND 2023
ORDER BY
  earliest_year DESC")
#' Save results
write_csv(wos_ta_by_year, here::here("data", "wos_ta_by_year.csv"))


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
WHERE earliest_year BETWEEN 2018 AND 2023
ORDER BY
  earliest_year DESC")
#' Save results
write_csv(wos_jn_ta_by_year, here::here("data", "wos_jn_ta_by_year.csv"))

### Scopus

scp_by_year <- dbGetQuery(bq_con, "WITH
  items_by_year AS (
  SELECT
    DISTINCT scp.item_id,
    first_pubyear AS earliest_year,
    REGEXP_CONTAINS(scp.oa_status, 'hybrid') AS is_oa,
    REGEXP_CONTAINS(item_type, '^Article|^Review') AS core
  FROM
    `hoa-article.hoa_comparision.scp_jct_items` AS scp
   WHERE first_pubyear BETWEEN 2019 AND 2023),
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
write_csv(scp_by_year, here::here("data", "scp_by_year.csv"))

scp_jn_by_year <- dbGetQuery(bq_con, "WITH
  tt AS (
  SELECT
    DISTINCT scp.item_id,
    first_pubyear AS earliest_year,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN scp.item_id
      ELSE NULL
  END
    AS is_oa,
    CASE
      WHEN REGEXP_CONTAINS(item_type, 'Article|^Review$') THEN TRUE
      ELSE FALSE
  END
    AS is_core,
    scp.issn_l
  FROM
    `hoa-article.hoa_comparision.scp_jct_items` AS scp),
  -- Just core
  core_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    'core' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles,
  FROM
    tt
  WHERE
    is_core IS TRUE
  GROUP BY
    issn_l,
    earliest_year),
  -- All
  all_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    'all' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles
  FROM
    tt
  GROUP BY
    issn_l,
    earliest_year),
combined AS (SELECT
  *
FROM
  core_pubs
UNION ALL
SELECT
  *
FROM
  all_pubs
ORDER BY
  issn_l,
  earliest_year)
SELECT *
FROM combined
WHERE earliest_year BETWEEN 2019 AND 2023")
write_csv(scp_jn_by_year, here::here("data", "scp_jn_by_year.csv"))

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
  first_pubyear as earliest_year,
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
WHERE first_pubyear BETWEEN 2019 AND 2023
ORDER BY
  first_pubyear DESC")

#' Save results
write_csv(scp_ta_by_year, here::here("data", "scp_ta_by_year.csv"))

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
  first_pubyear as earliest_year,
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
WHERE first_pubyear BETWEEN 2019 AND 2023
ORDER BY
  first_pubyear DESC,
  issn_l")

write_csv(scp_ta_jn_by_year, here::here("data", "scp_ta_jn_by_year.csv"))

### Country Affiliations

#' ## Web of Science
wos_country_aff <- dbGetQuery(bq_con, "WITH
  tt AS (
  SELECT
    DISTINCT wos.item_id,
    COALESCE(CAST(REGEXP_EXTRACT(wos.wos_pubdate_online, r'^[0-9]{4}') AS NUMERIC), wos.pubyear) AS earliest_year,
    CASE
      WHEN author_seq_nr = 1 THEN wos.item_id
      ELSE NULL
  END
    AS is_first_author,
    CASE
      WHEN corresponding = TRUE THEN wos.item_id
      ELSE NULL
  END
    AS is_corresponding_author,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN wos.item_id
      ELSE NULL
  END
    AS is_oa,
    CASE
      WHEN REGEXP_CONTAINS(item_type, 'Article|^Review$') THEN TRUE
      ELSE FALSE
  END
    AS is_core,
    wos.issn_l,
    aff.countrycode
  FROM
    `hoa-article.hoa_comparision.wos_jct_items` AS wos
  LEFT JOIN
    `hoa-article.hoa_comparision.wos_jct_affiliations` AS aff
  ON
    wos.item_id = aff.item_id
    ),
  -- Just core
  core_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    countrycode,
    'core' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles,
    COUNT(DISTINCT is_first_author) AS first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS oa_first_corresponding_author_articles
  FROM
    tt
  WHERE
    is_core IS TRUE
  GROUP BY
    issn_l,
    earliest_year,
    countrycode),
  -- All
  all_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    countrycode,
    'all' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles,
    COUNT(DISTINCT is_first_author) AS first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS oa_first_corresponding_author_articles
  FROM
    tt
  GROUP BY
    issn_l,
    earliest_year,
    countrycode),
combined AS (SELECT
  *
FROM
  core_pubs
UNION ALL
SELECT
  *
FROM
  all_pubs
ORDER BY
  issn_l,
  earliest_year,
  countrycode)
SELECT *
FROM combined
WHERE earliest_year BETWEEN 2019 AND 2023")
#' 
write_csv(wos_country_aff, here::here("data", "wos_country_aff.csv"))

wos_jn_country_ta_by_year <-  dbGetQuery(bq_con, "WITH
  jct_short AS (
  SELECT
    DISTINCT item_id,
    countrycode,
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
    countrycode,
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
    countrycode,
    earliest_year
  UNION ALL
  SELECT
    issn_l,
    countrycode,
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
    countrycode,
    earliest_year)
SELECT
  issn_l,
  countrycode,
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
WHERE
    earliest_year BETWEEN 2019
    AND 2023
ORDER BY
  issn_l, earliest_year, countrycode")

write_csv(wos_jn_country_ta_by_year, here::here("data", "wos_jn_country_ta_by_year.csv"))

#' Scopus
#' 
scp_country_aff <- dbGetQuery(bq_con, "WITH
  tt AS (
  SELECT
    DISTINCT scp.item_id,
    scp.first_pubyear AS earliest_year,
    CASE
      WHEN author_seq_nr = 1 THEN scp.item_id
      ELSE NULL
  END
    AS is_first_author,
    CASE
      WHEN corresponding = TRUE THEN scp.item_id
      ELSE NULL
  END
    AS is_corresponding_author,
    CASE
      WHEN REGEXP_CONTAINS(oa_status, 'hybrid') THEN scp.item_id
      ELSE NULL
  END
    AS is_oa,
    CASE
      WHEN REGEXP_CONTAINS(item_type, '^Article|^Review') THEN TRUE
      ELSE FALSE
  END
    AS is_core,
    scp.issn_l,
    aff.countrycode
  FROM
    `hoa-article.hoa_comparision.scp_jct_items` AS scp
  LEFT JOIN
    `hoa-article.hoa_comparision.scp_jct_affiliations` AS aff
  ON
    scp.item_id = aff.item_id
  WHERE scp.first_pubyear BETWEEN 2019 AND 2023
    ),
  -- Just core
  core_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    countrycode,
    'core' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles,
    COUNT(DISTINCT is_first_author) AS first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS oa_first_corresponding_author_articles
  FROM
    tt
  WHERE
    is_core IS TRUE
  GROUP BY
    issn_l,
    earliest_year,
    countrycode),
  -- All
  all_pubs AS (
  SELECT
    DISTINCT issn_l,
    earliest_year,
    countrycode,
    'all' AS pub_type,
    COUNT(DISTINCT item_id) AS n,
    COUNT(DISTINCT is_oa) AS oa_articles,
    COUNT(DISTINCT is_first_author) AS first_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_first_author
        ELSE NULL
    END
      ) AS oa_first_author_articles,
    COUNT(DISTINCT is_corresponding_author) AS corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL THEN is_corresponding_author
        ELSE NULL
    END
      ) AS oa_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS first_corresponding_author_articles,
    COUNT(DISTINCT
      CASE
        WHEN is_oa IS NOT NULL AND is_first_author IS NOT NULL AND is_corresponding_author IS NOT NULL THEN item_id
        ELSE NULL
    END
      ) AS oa_first_corresponding_author_articles
  FROM
    tt
  GROUP BY
    issn_l,
    earliest_year,
    countrycode)
SELECT
  *
FROM
  core_pubs
UNION ALL
SELECT
  *
FROM
  all_pubs
ORDER BY
  issn_l,
  earliest_year,
  countrycode")

write_csv(scp_country_aff, here::here("data", "scp_country_aff.csv"))

#' by TA
scp_jn_country_ta_by_year <- dbGetQuery(bq_con, "WITH
  jct_short AS (
  SELECT
    DISTINCT item_id,
    countrycode,
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
    `hoa-article.hoa_comparision.scp_jct_match`),
  article_stats AS (
  SELECT
    issn_l,
    countrycode,
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
    countrycode,
    first_pubyear
  UNION ALL
  SELECT
    issn_l,
    countrycode,
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
    countrycode,
    first_pubyear)
SELECT
  issn_l,
  countrycode,
  first_pubyear AS earliest_year,
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
WHERE
    first_pubyear BETWEEN 2019
    AND 2023
ORDER BY
  issn_l, earliest_year, countrycode")

write_csv(scp_jn_country_ta_by_year, here::here("data", "scp_jn_country_ta_by_year.csv"))

#' hoadata

## hoad jn by year

hoad_jn_by_year <- hoaddata::jn_ind |>
  mutate(cr_year = as.numeric(as.character(cr_year))) |>
  filter(between(cr_year, 2019, 2023)) |>
  distinct(issn_l, cr_year, jn_all)  |>
  arrange(issn_l, cr_year)
write_csv(hoad_jn_by_year, here::here("data", "hoad_jn_by_year.csv"))


# hoad_country_aff 
hoad_country_all <- hoaddata::jn_aff |>
  filter(between(cr_year, 2019, 2023)) |>
  distinct(issn_l, cr_year, country_code, articles_total) |>
  rename(articles = articles_total)

hoad_country_oa <- hoaddata::jn_aff |>
  filter(between(cr_year, 2019, 2023), !is.na(cc)) |>
  distinct(issn_l, cr_year, country_code, cc, articles_under_cc_variant) |>
  group_by(issn_l, cr_year, country_code) |>
  summarise(oa_articles = sum(articles_under_cc_variant))

hoad_country_aff <- left_join(hoad_country_all, hoad_country_oa, by = c("issn_l", "cr_year", "country_code")) |>
  # To ISO three letter country code
  mutate(country_code = countrycode::countrycode(country_code, "iso2c", "iso3c")) |>
  mutate(across(where(is.numeric), ~replace_na(.x, 0))) |>
  arrange(issn_l, cr_year, country_code)
write_csv(hoad_country_aff, here::here("data", "hoad_country_aff.csv"))
# hoad ta
# Use BigQuery
library(bigrquery)
library(DBI)
bq_con <- dbConnect(
  bigrquery::bigquery(),
  project = "subugoe-collaborative",
  billing = "subugoe-collaborative"
)
hoad_ta_country_df <- dbGetQuery(bq_con, "SELECT
  DISTINCT main.doi,
  main.cr_year,
  main.issn_l,
  country_code,
  CASE
    WHEN CC IS NULL THEN FALSE
    ELSE TRUE
END
  is_oa
FROM
  `hoa-article.hoaddata_sep24.ta_oa_inst` AS main
LEFT JOIN
  `subugoe-collaborative.openalex.institutions` AS oalex
ON
  main.ror = oalex.ror
WHERE
  ta_active = TRUE
  AND cr_year BETWEEN 2019 AND 2023")

hoad_ta_by_year_all <- hoad_ta_country_df |>
  group_by(issn_l, cr_year) |>
  summarise(ta_articles = n_distinct(doi))

hoad_ta_by_year_oa <-  hoad_ta_country_df |>
  filter(is_oa == TRUE) |>
  group_by(issn_l, cr_year) |>
  summarise(oa_articles = n_distinct(doi))

hoad_ta_by_year <- left_join(hoad_ta_by_year_all, hoad_ta_by_year_oa, 
                             by = c("issn_l", "cr_year")) |>
  mutate(across(where(is.numeric), ~replace_na(.x, 0))) |>
  arrange(issn_l, cr_year)

write_csv(hoad_ta_by_year, here::here("data", "hoad_ta_by_year.csv"))

# by country

hoad_jn_country_ta_by_year_all <- hoad_ta_country_df |>
  group_by(issn_l, cr_year, country_code) |>
  summarise(ta_articles = n_distinct(doi))

hoad_jn_country_ta_by_year_oa <-  hoad_ta_country_df |>
  filter(is_oa == TRUE) |>
  group_by(issn_l, cr_year, country_code) |>
  summarise(oa_articles = n_distinct(doi))

hoad_jn_country_ta_by_year <- left_join(hoad_jn_country_ta_by_year_all, 
                                        hoad_jn_country_ta_by_year_oa, 
                                        by = c("issn_l", "cr_year", "country_code")) |>
  mutate(across(where(is.numeric), ~replace_na(.x, 0))) |>
  # To ISO three letter country code
  mutate(country_code = countrycode::countrycode(country_code, "iso2c", "iso3c")) |>
  arrange(issn_l, cr_year, country_code)

write_csv(hoad_jn_country_ta_by_year, here::here("data", "hoad_jn_country_ta_by_year.csv"))

### Country stats spreadsheet

#### Scopus
scp_aff <- readr::read_csv("data/scp_country_aff.csv")
scp_ta <- readr::read_csv("data/scp_jn_country_ta_by_year.csv")

scp_df <- left_join(scp_aff, scp_ta, by = c("issn_l", "countrycode", "earliest_year", "pub_type" = "pubtype")) |>
  mutate(earliest_year = as.character(earliest_year)) |>
  filter(pub_type == "core") |>
  rename_with(.cols = where(is.numeric), function(x){paste0("scp_", x)}) |>
  select(-pub_type)

#### Web of Science
wos_aff <- readr::read_csv("data/wos_country_aff.csv")
wos_ta <- readr::read_csv("data/wos_jn_country_ta_by_year.csv")

wos_df <- left_join(wos_aff, wos_ta, by = c("issn_l", "countrycode", "earliest_year", "pub_type" = "pubtype"))

wos_df <- left_join(wos_aff, wos_ta, by = c("issn_l", "countrycode", "earliest_year", "pub_type" = "pubtype")) |>
  mutate(earliest_year = as.character(earliest_year)) |>
  filter(pub_type == "core") |>
  rename_with(.cols = where(is.numeric), function(x){paste0("wos_", x)}) |>
  select(-pub_type)

#### HOAD
hoad_aff <- readr::read_csv("data/hoad_country_aff.csv")
hoad_ta <- readr::read_csv("data/hoad_jn_country_ta_by_year.csv") |>
  rename(ta_oa_articles = oa_articles)

hoad_df <- left_join(hoad_aff, hoad_ta, by = c("issn_l", "country_code", "cr_year")) |>
  mutate(earliest_year = as.character(cr_year)) |>
  rename_with(.cols = where(is.numeric), function(x){paste0("hoad_", x)}) |>
  select(-hoad_cr_year)

my_df <- left_join(hoad_df, scp_df, by = c("issn_l", "country_code" = "countrycode", "earliest_year")) |>
  left_join(wos_df, by =   c("issn_l", "country_code" = "countrycode", "earliest_year")) 

write_csv(my_df, here::here("data", "jn_country_stats_all.csv"))