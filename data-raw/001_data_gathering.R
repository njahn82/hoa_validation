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

#### Prepare affiliation metadata

#' Why?
#' 
#' I use ROR ID to retrieve eligible publications using the ROR, which is
#' both present in JCT and OpenAlex. However, Web of Science and Scopus do not
#' provide ROR IDs, but use proprietory approaches.
#' 
#' How?
#' 
#' The idea is to use TA publications as a benchmark to retrieve corresponding
#' organsiation strings from the Web of Science / Scopus and map them to the ROR 
#' per article using the DOI. 
#' 
#' To account for multiplecaffiliations only the most frequent RORID/WOS ORG 
#' combination is used.
#' 
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

#### Prepare journal data
jct_issn <- hoaddata::jct_hybrid_jns |>
  distinct(issn, issn_l)
dbWriteTable(kb_con, "jct_hybrid_jns_issn", jct_issn, overwrite = TRUE)

#### Retrieve articles from hybrid journals
dbExecute(kb_con, "DROP TABLE wos_jct_items")

dbExecute(kb_con, "CREATE table wos_jct_items AS select
	distinct 
	jhji.issn_l ,
	i.item_id,
	doi,
	pubyear,
	wos_pubdate_online
from
	jct_hybrid_jns_issn jhji
left join wos_b_202310.v_issn_isbn vii on
	jhji.issn = vii.sn
left join wos_b_202310.v_items i on
	vii.item_id = i.item_id
where
	pubyear > 2017")

#### Add WOS affiliation data for first data and corresponding authors
dbExecute(kb_con, "DROP TABLE wos_jct_affiliations")

dbExecute(kb_con, "CREATE table wos_jct_affiliations AS select
	distinct jct.item_id,
	jct.issn_l,
	jct.doi,
	jct.pubyear,
	jct.wos_pubdate_online,
	via.author_seq_nr,
	via.corresponding,
	via.orcid,
	via2.organization,
	via2.countrycode
from
	wos_jct_items jct
left join wos_b_202310.v_items_authors via on
	jct.item_id = via.item_id
left join wos_b_202310.v_authors_affiliations vaa2 on
	jct.item_id = vaa2.item_id
	and via.author_seq_nr = vaa2.author_seq_nr
left join wos_b_202310.v_items_affiliations via2 on
	jct.item_id = via2.item_id
	and vaa2.aff_seq_nr = via2.aff_seq_nr
where
	via.author_seq_nr = 1 or corresponding = true")

tt <- DBI::dbReadTable(kb_con, "wos_jct_affiliations")
wos_jct_affiliations <- tt |>
  mutate(organization = gsub('\\{|\\}|"', '', organization)) |>
  mutate(doi = tolower(doi)) |>
  as_tibble()
write_csv(wos_jct_affiliations, "data-raw/wos_jct_affiliations_20240410.csv")
#' Disconnect DB
DBI::dbDisconnect(bq_con)
DBI::dbDisconnect(kb_con)

