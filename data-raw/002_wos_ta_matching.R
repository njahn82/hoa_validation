#' Web of Science matching with Transformative Agreement data
#' 
#' The aim is to link bibliographic records with transformative agreement data 
#' to determine, which publications were from an eligible institution under a 
#' specific TA
#' 
#' ## Data prep
#' 
#' First, I need to add ror ids to the wos dataset using our matching.
#' 
#' To Do: Keep this data point in KB.
library(tidyverse)
wos_df <- readr::read_csv("data-raw/wos_jct_affiliations_20240410.csv") 
# Matching
wos_ror <- readr::read_csv("data-raw/ror_wos_matching.csv") |>
  distinct(ror_matching, organization)

wos_matching <- wos_df |> 
  left_join(wos_ror, by = "organization")
#' The results is downloaded as csv and uploaded to Google BiGQuery using gcloud 
#' command line tools (because file is large)
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/wos_matching_20240410.csv gs://bigschol`
write_csv(wos_matching, "data-raw/wos_matching_20240410.csv")
#'
#' 
#' ## Matching
#' 
#' First, we combine data about journals and participating institutions per
#' transformative agreements according to the JCT. Note, ISSN-L and ROR were 
#' enriched. The resulting temporary table is `esac_data`
#' 
#' Then, we create a subset of publications from eligible institutions by merging
#' `esac_data` with `wos_matching_20240410`. To improve the performance of the query
#' not all fields will be returned. Also, records from institutions without TA were 
#' excluded before the matching as indicated by NA. 
library(bigrquery)

my_sql <- "WITH
  esac_data AS (
  SELECT
    jct_jn.esac_id,
    issn_l,
    jct_inst.ror_main,
    EXTRACT(YEAR
    FROM
      start_date) AS start_year,
    -- Extracting the year from start_date
    EXTRACT(YEAR
    FROM
      end_date) AS end_year,
    -- Extracting the year from end_date
  FROM
    `subugoe-collaborative.hoaddata.jct_hybrid_jns` AS jct_jn
  INNER JOIN
    `subugoe-collaborative.hoaddata.jct_inst_enriched` AS jct_inst
  ON
    jct_jn.esac_id = jct_inst.esac_id
  WHERE
    ror_main != 'NA'),
  wos AS (
  SELECT
    *,
    CAST(REGEXP_EXTRACT(wos_pubdate_online, r'^[0-9]{4}') AS NUMERIC) AS online_year
  FROM
    `hoa-article.hoa_comparision.wos_matching_20240410`
  WHERE
    ror_matching != 'NA')
SELECT
  DISTINCT item_id,
  wos.issn_l,
  doi,
  pubyear,
  wos.online_year,
  CASE WHEN online_year IS NULL THEN pubyear ELSE online_year END AS earliest_year,
  wos.ror_matching AS ror,
  organization,
  countrycode,
  author_seq_nr,
  corresponding,
  esac_id,
  start_year,
  end_year
FROM
  wos
INNER JOIN
  esac_data
ON
  esac_data.issn_l = wos.issn_l
  AND esac_data.ror_main = wos.ror_matching"

bq_auth()
if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.wos_jct")) {
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.wos_jct")
}
tb <-  bigrquery::bq_dataset_query("hoa-article.hoa_comparision",
                                   query = my_sql,
                                   destination_table = "hoa-article.hoa_comparision.wos_jct",
                                   billing = "subugoe-collaborative"
)
wos_jct <- bq_table_download(tb)

