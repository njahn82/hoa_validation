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
wos_df <- readr::read_csv("data-raw/wos_jct_affiliations.csv") 
# Matching
wos_ror <- readr::read_csv("data-raw/ror_wos_matching.csv") |>
  distinct(ror, vendor_org_id)

wos_matching <- wos_df |> 
  left_join(wos_ror, by = "vendor_org_id")
#' The results is downloaded as csv and uploaded to Google BiGQuery using gcloud 
#' command line tools (because file is large)
#' `gcloud storage cp ~/Documents/thesis/hoa_validation/data-raw/wos_matching_20240717.csv gs://bigschol`
write_csv(wos_matching, "data-raw/wos_matching_20240717.csv")
#'
#' 
#' ## Matching
#' 
#' First, we combine data about journals and participating institutions per
#' transformative agreements according to the JCT. Note, ISSN-L and ROR were 
#' enriched. The resulting temporary table is `esac_data`
#' 
#' Then, we create a subset of publications from eligible institutions by merging
#' `esac_data` with `wos_matching_20240717`. To improve the performance of the query
#' not all fields will be returned. Also, records from institutions without TA were 
#' excluded before the matching as indicated by NA. 
library(bigrquery)

my_sql <- "WITH
  esac_data AS (
  SELECT
    jct_jn.esac_id,
    issn_l,
    jct_inst.ror_main,
    jct_inst.ror as ror_matching,
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
    `hoa-article.hoa_comparision.wos_matching_20240717`
  WHERE
    ror_matching != 'NA')
SELECT
  DISTINCT item_id,
  wos.issn_l,
  doi,
  pubyear,
  wos.online_year,
  CASE WHEN online_year IS NULL THEN pubyear ELSE online_year END AS earliest_year,
 -- wos.ror_matching AS ror,
  ror_main,
  vendor_org_id,
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
  AND esac_data.ror_matching = wos.ror_matching"

bq_auth()
if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.wos_jct")) {
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.wos_jct")
}
tb <-  bigrquery::bq_dataset_query("hoa-article.hoa_comparision",
                                   query = my_sql,
                                   destination_table = "hoa-article.hoa_comparision.wos_jct",
                                   billing = "subugoe-collaborative"
)
#' ## Zwischenschritt Validierung anhand der Länderinformationen des ESAC Registry
#' 
#' Get ESAC data
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
#' Match in BigQuery
#' 
#' To Do: Use year and month, both data points seems to be present in wos data
my_sql <- "SELECT
  DISTINCT wos.*,
  CASE
    WHEN (earliest_year BETWEEN start_year AND end_year) THEN TRUE -- Check if publication is within the agreement's date range
  ELSE
  FALSE
END
  AS ta,
  -- Flag indicating if the publication is within the agreement
FROM
  `hoa-article.hoa_comparision.wos_jct` AS wos
INNER JOIN
  `hoa-article.hoa_comparision.esac_countries` AS esac
ON
  wos.countrycode = esac.country_code
  AND wos.esac_id = esac.id"

if (bigrquery::bq_table_exists("hoa-article.hoa_comparision.wos_jct_ta")) {
  bigrquery::bq_table_delete("hoa-article.hoa_comparision.wos_jct_ta")
}
tb <-  bigrquery::bq_dataset_query("hoa-article.hoa_comparision",
                                   query = my_sql,
                                   destination_table = "hoa-article.hoa_comparision.wos_jct_ta",
                                   billing = "subugoe-collaborative"
)
