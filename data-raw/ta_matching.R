#' TA identification
#' 
library(tidyverse)
library(bigrquery)
#' ## Prepare matching table
#' 
#' I combine data about journals and participating institutions per
#' transformative agreements according to the JCT. Note, ISSN-L and ROR were 
#' enriched. The resulting temporary table is `jct_full`
#' 
jct_full_sql <- "SELECT
  DISTINCT jct_jn.esac_id,
  issn_l,
  jct_inst.ror,
  EXTRACT(YEAR
  FROM
    start_date) AS start_year,
  EXTRACT(YEAR
  FROM
    end_date) AS end_year,
FROM
  `hoa-article.hoaddata_sep24.jct_hybrid_jns` AS jct_jn
INNER JOIN
  `hoa-article.hoaddata_sep24.jct_inst_enriched` AS jct_inst
ON
  jct_jn.esac_id = jct_inst.esac_id
WHERE
  ror != 'NA'"

bq_auth()
if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.jct_full")) {
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.jct_full")
}
bigrquery::bq_dataset_query("hoa-article.hoa_comparision",
                                   query = jct_full_sql,
                                   destination_table = "hoa-article.hoa_comparision.jct_full",
                                   billing = "subugoe-collaborative")

#' Upload ESAC data
data_url <- "https://keeper.mpdl.mpg.de/f/7fbb5edd24ab4c5ca157/?dl=1"
tmp <- tempfile()
download.file(data_url, tmp)
esac <- readxl::read_xlsx(tmp, skip = 2) |>
  janitor::clean_names()
esac_countries <- esac |>
  select(id, country) |>
  separate_rows(country, sep = ",") |>
  mutate(country = trimws(country)) |>
  mutate(country_code = countrycode::countrycode(country, origin = "country.name", dest = "iso3c")) |>
  mutate(country_code = ifelse(country == "Kosovo", "XKK", country_code))
#' Upload to BQ
if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.esac_countries")) 
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.esac_countries") 
bigrquery::bq_table_upload("hoa-article.hoa_comparision.esac_countries", esac_countries)

## Web of Science

#' Upload Web of Science article-level affilaition data and the matching table to Cloud Storage
#'  and import to BigQuery
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/wos_jct_affiliations.csv gs://bigschol`
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/ror_wos_matching.csv gs://bigschol`
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/wos_jct_items_df.csv gs://bigschol`
#' 
#' Main query: Get candidate articles published under an TA from WOS using JCT and ESAC metadata
wos_jct_match_sql <- "WITH
  -- Extract affiliation data from wos_jct_affiliation and match it with ror_wos
  wos_ror AS (
  SELECT
    DISTINCT wos_jct.item_id,
    wos_jct.issn_l,
    wos_jct.doi,
    wos_jct.pubyear,
    CAST(REGEXP_EXTRACT(wos_pubdate_online, r'^[0-9]{4}') AS NUMERIC) AS online_year,
    wos_jct.author_seq_nr,
    wos_jct.corresponding,
    wos_jct.vendor_org_id,
    wos_jct.countrycode,
    matching.ror
  FROM
    `hoa-article.hoa_comparision.wos_jct_affiliations` AS wos_jct
  CROSS JOIN
    UNNEST(SPLIT(wos_jct.vendor_org_id, ',')) AS vendor_org_id_part
  LEFT JOIN
    `hoa-article.hoa_comparision.ror_wos_matching` AS matching
  ON
    vendor_org_id_part = matching.vendor_org_id
  WHERE
    matching.ror != 'NA' ),
  -- Filter and add additional metadata from Web of Science items
  wos_items AS (
  SELECT
    DISTINCT wos_ror.*,
    items.oa_status,
    REGEXP_CONTAINS(items.item_type, 'Article|^Review$') AS core
  FROM
    `hoa-article.hoa_comparision.wos_jct_items` AS items
  INNER JOIN
    wos_ror
  ON
    items.item_id = wos_ror.item_id ),
  -- Combine with JCT data to capture agreements' details
  wos_ror_jct AS (
  SELECT
    DISTINCT wos_items.item_id,
    wos_items.issn_l,
    wos_items.doi,
    COALESCE(wos_items.online_year, wos_items.pubyear) AS earliest_year,
    wos_items.ror,
    wos_items.vendor_org_id,
    wos_items.countrycode,
    wos_items.author_seq_nr,
    wos_items.corresponding,
    wos_items.oa_status,
    wos_items.core,
    jct_full.esac_id,
    jct_full.start_year,
    jct_full.end_year
  FROM
    wos_items
  INNER JOIN
    `hoa-article.hoa_comparision.jct_full` AS jct_full
  ON
    wos_items.issn_l = jct_full.issn_l
    AND wos_items.ror = jct_full.ror ),
  -- Check if the article was published within the JCT agreement date range
  eligible_articles AS (
  SELECT
    wos_ror_jct.*,
    CASE
      WHEN wos_ror_jct.earliest_year BETWEEN wos_ror_jct.start_year AND wos_ror_jct.end_year THEN TRUE
      ELSE FALSE
  END
    AS ta_flag
  FROM
    wos_ror_jct
  INNER JOIN
    `hoa-article.hoa_comparision.esac_countries` AS esac
  ON
    wos_ror_jct.countrycode = esac.country_code
    AND wos_ror_jct.esac_id = esac.id )
  -- Select only the articles that are identified as published under a transformative agreement
SELECT
  DISTINCT *
FROM
  eligible_articles
WHERE
  ta_flag = TRUE"

if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.wos_jct_match")) {
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.wos_jct_match")
}
bigrquery::bq_dataset_query("hoa-article.hoa_comparision",
                            query = wos_jct_match_sql,
                            destination_table = "hoa-article.hoa_comparision.wos_jct_match",
                            billing = "subugoe-collaborative")

## Scopus

#' Upload Web of Science article-level affilaition data and the matching table to Cloud Storage
#'  and import to BigQuery
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/scp_jct_affiliations.csv gs://bigschol`
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/scp_wos_matching.csv gs://bigschol`
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/scp_jct_items_df.csv gs://bigschol`
#' 
#' Main query: Get candidate articles published under an TA from WOS using JCT and ESAC metadata
scp_jct_match_sql <- "WITH
  -- Extract affiliation data from scp_jct_affiliation and match it with ror_scp
  scp_ror AS (
  SELECT
    DISTINCT scp_jct.item_id,
    scp_jct.issn_l,
    scp_jct.doi,
    scp_jct.first_pubyear,
    scp_jct.author_seq_nr,
    scp_jct.corresponding,
    scp_jct.vendor_org_id,
    scp_jct.countrycode,
    matching.ror
  FROM
    `hoa-article.hoa_comparision.scp_jct_affiliations` AS scp_jct
  LEFT JOIN
    `hoa-article.hoa_comparision.scp_ror_matching` AS matching
  ON
    scp_jct.vendor_org_id = CAST(matching.vendor_org_id AS STRING)
  WHERE
    matching.ror != 'NA'),
  -- Filter and add additional metadata from Web of Science items
  scp_items AS (
  SELECT
    DISTINCT scp_ror.*,
    items.oa_status,
    REGEXP_CONTAINS(items.item_type, '^Article|^Review') AS core
  FROM
    `hoa-article.hoa_comparision.scp_jct_items` AS items
  INNER JOIN
    scp_ror
  ON
    items.item_id = scp_ror.item_id ),
  -- Combine with JCT data to capture agreements' details
  scp_ror_jct AS (
  SELECT
    DISTINCT scp_items.item_id,
    scp_items.issn_l,
    scp_items.doi,
    scp_items.first_pubyear,
    scp_items.ror,
    scp_items.countrycode,
    scp_items.author_seq_nr,
    scp_items.corresponding,
    scp_items.oa_status,
    scp_items.core,
    jct_full.esac_id,
    jct_full.start_year,
    jct_full.end_year
  FROM
    scp_items
  INNER JOIN
    `hoa-article.hoa_comparision.jct_full` AS jct_full
  ON
    scp_items.issn_l = jct_full.issn_l
    AND scp_items.ror = jct_full.ror ),
  -- Check if the article was published within the JCT agreement date range
  eligible_articles AS (
  SELECT
    scp_ror_jct.*,
    CASE
      WHEN scp_ror_jct.first_pubyear BETWEEN scp_ror_jct.start_year AND scp_ror_jct.end_year THEN TRUE
      ELSE FALSE
  END
    AS ta_flag
  FROM
    scp_ror_jct
  INNER JOIN
    `hoa-article.hoa_comparision.esac_countries` AS esac
  ON
    scp_ror_jct.countrycode = esac.country_code
    AND scp_ror_jct.esac_id = esac.id )
  -- Select only the articles that are identified as published under a transformative agreement
SELECT
  DISTINCT *
FROM
  eligible_articles
WHERE
  ta_flag = TRUE"

if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.scp_jct_match")) {
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.scp_jct_match")
}
bigrquery::bq_dataset_query("hoa-article.hoa_comparision",
                            query = scp_jct_match_sql,
                            destination_table = "hoa-article.hoa_comparision.scp_jct_match",
                            billing = "subugoe-collaborative")
