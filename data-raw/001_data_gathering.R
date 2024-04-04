library(DBI)
library(bigrquery)
library(RPostgres)
library(tidyverse)
#' Connect to DB 
#' 
#' BigQuery HOAD (Crossref, OpenAlex and open friends)
bq_con <- dbConnect(
  bigrquery::bigquery(),
  project = "subugoe-collaborative",
  billing = "subugoe-collaborative"
)
#' KB Postgres (Web of Science, Scopus)
kb_con <- dbConnect(RPostgres::Postgres(),
                    host = "biblio-p-db03.fiz-karlsruhe.de",
                    port = 6432,
                    dbname = "kbprod",
                    user =  Sys.getenv("kb_user"),
                    password = Sys.getenv("kb_pwd"),
                    bigint = "numeric"
)
#' Article-level publication metadata from institutions with TA
ta_oa_inst <- readr::read_csv("https://github.com/subugoe/hoaddata/releases/download/v0.2.95/ta_oa_inst.csv.gz")
ta_ror_pubs <- ta_oa_inst |>
  distinct(doi, ror_matching)
#' Upload to KB
dbWriteTable(kb_con, "ta_ror_pubs", ta_ror_pubs, overwrite = TRUE)
#' #### Web of Science
#' 
#' Matching table
dbExecute(kb_con, "DROP TABLE ta_wos")
dbExecute(kb_con, "CREATE table ta_wos AS 
select ta.*, vi.item_id
from ta_ror_pubs ta
left join wos_b_202310.v_items vi on ta.doi = LOWER(vi.doi)")
#' 
#' Get article-level affiliation metadata
dbExecute(kb_con, "DROP TABLE ta_wos_aff")
dbExecute(kb_con, "CREATE TABLE ta_wos_aff AS select distinct tw.*, aa.author_seq_nr, aa.organization, aa.vendor_org_id 
from ta_wos tw 
inner join wos_b_202310.v_authors_affiliations aa on tw.item_id = aa.item_id 
where aa.author_seq_nr = 1 ")
#' Create matching table where the most frequent ror / org combination is chosen to
#' account for multiple authorships
ror_wos_matching <- dbGetQuery(kb_con, "select
	*
from
	(
	select
		*,
		row_number() over(partition by ror_matching
	order by
		matches desc) as row_n
	from
		(
		select
			count(distinct doi) as matches,
			ror_matching,
			unnest(organization) as organization
		from
			ta_wos_aff twa
		group by
			ror_matching,
			organization
) ii ) ppp
where
	ppp.row_n = 1
") |>
  as_tibble()
#' backup
write_csv(ror_wos_matching, here::here("data-raw", "ror_wos_matching.csv"))

#' Disconnect DB
DBI::dbDisconnect(bq_con)
DBI::dbDisconnect(kb_con)

