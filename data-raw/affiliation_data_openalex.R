# Check affiliations and corresponding authors in OpenAlex
library(DBI)
library(bigrquery)
library(RPostgres)
library(tidyverse)
library(here)
#' Connect to DB 

#' KB Postgres (Web of Science, Scopus)
kb_con <- dbConnect(RPostgres::Postgres(),
                    host = "biblio-p-db03.fiz-karlsruhe.de",
                    port = 6432,
                    dbname = "kbprod",
                    user =  Sys.getenv("kb_user"),
                    password = Sys.getenv("kb_pwd"),
                    bigint = "numeric"
)
cr_dois <- readr::read_csv(here("data-raw", "hoad_dois_all_19_23.csv"))

#' HOAD active journals with OA
hoad_jns <- hoaddata::jct_hybrid_jns |>
  filter(issn_l != "0027-8424")

active_jns <- hoad_jns |>
  # Only active hybrid journals from JCT
  inner_join(hoaddata::jn_ind, by = "issn_l") |>
  filter(!cr_year %in% c("2017", "2018", "2024"))

active_jns_with_oa <- active_jns |> 
  filter(!is.na(cc))

dois_active_jns_with_oa <- cr_dois |>
  filter(issn_l %in% active_jns_with_oa$issn_l)

#' Send to FIZ
DBI::dbWriteTable(kb_con, "dois_active_jns_with_oa", dois_active_jns_with_oa)

#' Create table with author roles, affiliations and funding stats
dbExecute(kb_con, "CREATE TABLE oalex_cr_cor_funder AS WITH filtered_works AS (
  SELECT 
    id,
    REPLACE(doi, 'https://doi.org/', '') as short_doi,
    corresponding_author_ids, 
    corresponding_institution_ids,
    json_array_length(corresponding_author_ids) AS num_corresponding_authors,
    json_array_length(corresponding_institution_ids) AS num_corresponding_institutions
  FROM 
    fiz_openalex_rep_20240831_openbib_fdw.works
)
SELECT 
    hoad.doi, 
    w.corresponding_author_ids, 
    w.corresponding_institution_ids,
    w.num_corresponding_authors,
    w.num_corresponding_institutions,
    f.funder_id
FROM 
    dois_active_jns_with_oa hoad
LEFT JOIN 
    filtered_works w
ON
    hoad.doi = w.short_doi
LEFT JOIN
    fiz_openalex_rep_20240831_openbib_fdw.works_funders f
ON 
    w.id = f.work_id")

#' Download (just counts)
oal_author_affiliation_stats <- dbGetQuery(kb_con, "select distinct doi, num_corresponding_authors, num_corresponding_institutions
from oalex_cr_cor_funder")
write_csv(oal_author_affiliation_stats, 
          here::here("data", "oal_author_affiliation_stats.csv"))

#' Affiliation stats

# from bq
bq_con <- dbConnect(
  bigrquery::bigquery(),
  project = "subugoe-collaborative",
  billing = "subugoe-collaborative"
)
first_stat <- dbGetQuery(bq_con, 'WITH
active_with_oa AS (
  SELECT
  DISTINCT issn_l
  FROM (
    SELECT
    jct.issn_l,
    cr_year,
    cc
    FROM
    `hoa-article.hoaddata_sep24.jct_hybrid_jns` AS jct
    INNER JOIN
    `hoa-article.hoaddata_sep24.cc_jn_ind` AS ccdf
    ON
    jct.issn_l = ccdf.issn_l )
  WHERE
  (cr_year BETWEEN 2019
    AND 2023)
  AND NOT issn_l = "0027-8424"
  AND cc IS NOT NULL ),
aff AS (
  SELECT
  DISTINCT id AS ror,
  doi
  FROM
  active_with_oa
  INNER JOIN
  `hoa-article.hoaddata_sep24.cr_openalex_inst_full` AS inst
  ON
  active_with_oa.issn_l = inst.issn_l
  WHERE
  cr_year BETWEEN 2019
  AND 2023 )
SELECT
COUNT(DISTINCT
      CASE
      WHEN ror IS NOT NULL THEN doi
      ELSE NULL
      END
) AS has_ror
FROM
aff')
corresponding_authors_n <- oal_author_affiliation_stats |>
  filter(num_corresponding_authors != 0) |>
  distinct(doi) |>
  nrow()
corresponding_authors_inst <-  oal_author_affiliation_stats |>
  filter(num_corresponding_authors != 0, num_corresponding_institutions != 0) |>
  distinct(doi) |>
  nrow()
tmp <- tibble(first_author_with_ror = first_stat$has_ror, corresponding_authors_n, corresponding_authors_inst)
write_csv(tmp, here::here("data", "aff_oalex_stats.csv"))

#' Create stats for HOAD non-core articles
#' - JNs
#' - article volume (active with oa)
#' - oa article volume (active with oa)

#' Set up BQ
#' BigQuery HOAD (Crossref, OpenAlex and open friends)
bq_con <- dbConnect(
  bigrquery::bigquery(),
  project = "subugoe-collaborative",
  billing = "subugoe-collaborative"
)
bigrquery::bq_dataset_query(
  bigrquery::bq_dataset("hoa-article", "hoaddata_sep24"),
                            query = 'SELECT DISTINCT *
FROM (
  SELECT
    issn_l,
    esac_publisher,
    LOWER(doi) AS doi,
    EXTRACT ( YEAR
    FROM
      issued ) AS cr_year,
    license
  FROM (
    SELECT
      SPLIT(issn, ",") AS issn,
      doi,
      issued,
      license
    FROM
      `subugoe-collaborative.resources.crossref_august_2024_licenses` ) AS `tbl_cr`,
    UNNEST(issn) AS issn
  INNER JOIN
    `hoa-article.hoaddata_sep24.jct_hybrid_jns`
  ON
    issn = `hoa-article.hoaddata_sep24.jct_hybrid_jns`.`issn` )
WHERE
  ( cr_year BETWEEN 2019
    AND 2023 )',
                            destination_table = bigrquery::bq_table(
                              "hoa-article", "hoaddata_sep24", "cr_all")
)
##

#' All journals
#' Need to remove OA
active_journals <- dbGetQuery(bq_con, 'SELECT DISTINCT issn_l
FROM `hoa-article.hoaddata_sep24.cr_all` cr_all
WHERE NOT EXISTS (
    SELECT 1 
    FROM `hoa-article.hoaddata_sep24.cc_oa_prop` oa 
    WHERE cr_all.issn_l = oa.issn_l
) AND issn_l != "0027-8424"')
active_journals

active_journals |>
  filter(!issn_l %in% active_jns$issn_l)
#       "Clinical Research in Cardiology Supplements"
# Journal of Molecular Microbiology and Biotechnology (2019) 29 (1-6): I–V.
# ten aritcles
active_journals_all <- dbGetQuery(bq_con, 'SELECT COUNT(DISTINCT doi)
FROM `hoa-article.hoaddata_sep24.cr_all` cr_all
WHERE NOT EXISTS (
    SELECT 1 
    FROM `hoa-article.hoaddata_sep24.cc_oa_prop` oa 
    WHERE cr_all.issn_l = oa.issn_l
) AND issn_l NOT IN ("0027-8424", "1861-0706", "1464-1801")')

ind_oa_articles_all <- dbGetQuery(bq_con, 'WITH
  cr_all AS (
  SELECT
    doi,
    lic
  FROM
    `hoa-article.hoaddata_sep24.cr_all` cr_all,
    UNNEST(license) AS lic
  WHERE
    NOT EXISTS (
    SELECT
      1
    FROM
      `hoa-article.hoaddata_sep24.cc_oa_prop` oa
    WHERE
      cr_all.issn_l = oa.issn_l )
    AND issn_l NOT IN ("0027-8424",
      "1861-0706",
      "1464-1801") ),
  oa_ind AS (
  SELECT
    DISTINCT doi,
    CASE
      WHEN lic.content_version != "am" THEN 1
      ELSE 0
  END
    AS vor,
    CASE
      WHEN lic.delay_in_days = 0 THEN 1
      ELSE 0
  END
    AS IMMEDIATE
  FROM
    cr_all
  WHERE
    REGEXP_CONTAINS(LOWER(lic.url), "creativecommons.org") )
SELECT
  COUNT(DISTINCT doi)
FROM
  oa_ind
WHERE
  vor = 1')

tibble::tibble(active_journals = length(unique(active_journals$issn_l)),
               active_journals_all = unlist(active_journals_all$f0_),
               ind_oa_articles_all = unlist(ind_oa_articles_all$f0_)) |>
  write_csv(here::here("data", "cr_all_ind.csv"))

