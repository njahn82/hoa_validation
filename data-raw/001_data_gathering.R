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
#' organisation strings from the Web of Science / Scopus and map them to the ROR 
#' per article using the DOI. 
#' 
#' To account for multiple affiliations only the most frequent RORID/WOS ORG 
#' combination is used.
#' 
#' Article-level publication metadata from institutions with TA
ta_oa_inst <- readr::read_csv("https://github.com/subugoe/hoaddata/releases/download/v.0.3/ta_oa_inst.csv.gz")
#' Backup
write_csv(ta_oa_inst, here::here("data-raw", "ta_oa_inst.csv"))
ta_ror_pubs <- ta_oa_inst |>
  distinct(doi, ror)
#' Make sure RORs are aligned 
#' Upload to KB
dbWriteTable(kb_con, "ta_ror_pubs", ta_ror_pubs, overwrite = TRUE)
#' #### Web of Science
#' 
#' Matching table
dbExecute(kb_con, "DROP TABLE ta_wos")
dbExecute(kb_con, "CREATE table ta_wos AS 
select ta.*, vi.item_id
from ta_ror_pubs ta
left join wos_b_202404.v_items vi on ta.doi = LOWER(vi.doi)")
#' 
#' Get article-level affiliation metadata
dbExecute(kb_con, "DROP TABLE ta_wos_aff")
dbExecute(kb_con, "CREATE TABLE ta_wos_aff AS select distinct tw.*, aa.author_seq_nr, aa.organization, aa.vendor_org_id 
from ta_wos tw 
inner join wos_b_202404.v_authors_affiliations aa on tw.item_id = aa.item_id 
where aa.author_seq_nr = 1 ")
#' Create matching table where the most frequent ror / org combination is chosen to
#' account for multiple authorships
#' 
#' I use the Unique ID of an organization as defined by Clarivate. WoS Organization Enhanced ("preferred name"). 
#' Path: /REC/static_data/fullrecord_metadata/addresses/address_name/address_spec/organizations/organization@pref.
#' 
#' 
ror_wos_matching <- dbGetQuery(kb_con, "with vendor as
(
select
	ror,
	vendor_org_id,
	n,
	row_number
from
	(
	select
		*,
		row_number() over (partition by vendor_org_id
	order by
		n desc) as row_number
	from
		(
		select
			COUNT(distinct item_id) as n,
			ror,
			vendor_org_id
		from
			(
			select
				distinct item_id,
				ror,
				unnest(vendor_org_id) as vendor_org_id
			from
				ta_wos_aff twa
      )
		group by
			ror,
			vendor_org_id
		order by
			vendor_org_id,
			n desc
    )
  )
), 
ror as 
(
select
	ror,
	vendor_org_id,
	n,
	row_number() over (partition by ror
order by
	n desc) as row_number
from
	vendor 
)
select
	*
from
	ror
where
	row_number = 1;") |>
  as_tibble()
#' backup
write_csv(ror_wos_matching, here::here("data-raw", "ror_wos_matching.csv"))

#' Items where no vendor could be retrieved
#' 
ror_no_vendor_org_id <- dbGetQuery(kb_con, "with doi_groups as (
select
	doi,
	case
		when every(vendor_org_id is null) then true
		else false
	end as all_null
from
	ta_wos_aff
group by
	doi
)
select distinct *
from
	doi_groups
where
	all_null = true;"
)
#' Backup
write_csv(ror_no_vendor_org_id, here::here("data-raw", "wos_ror_no_vendor_org_id.csv"))

#' #### Scopus
#' 
#' Matching table
dbExecute(kb_con, "DROP TABLE ta_scopus")
dbExecute(kb_con, "CREATE table ta_scopus AS 
select ta.*, vi.item_id
from ta_ror_pubs ta
left join scp_b_202404.items vi on ta.doi = LOWER(vi.doi)")
#' 
#' Get article-level affiliation metadata
dbExecute(kb_con, "DROP TABLE ta_scopus_aff")
dbExecute(kb_con, "CREATE TABLE ta_scopus_aff AS select distinct tw.*, aa.author_seq_nr, aa.organization, aa.vendor_org_id 
from ta_scopus tw 
inner join scp_b_202404.authors_affiliations aa on tw.item_id = aa.item_id 
where aa.author_seq_nr = 1 ")
#' Create matching table where the most frequent ror / org combination is chosen to
#' account for multiple authorships
#' 
#' In Scopus, I use the Scopus Affiliation ID https://www.wikidata.org/wiki/Property:P1155
#' 
ror_scp_matching <- dbGetQuery(kb_con, "with vendor as
(
select
	ror,
	vendor_org_id,
	n,
	row_number
from
	(
	select
		*,
		row_number() over (partition by vendor_org_id
	order by
		n desc) as row_number
	from
		(
		select
			COUNT(distinct item_id) as n,
			ror,
			vendor_org_id
		from
			(
			select
				distinct item_id,
				ror,
				unnest(vendor_org_id) as vendor_org_id
			from
				ta_scopus_aff twa
      )
		group by
			ror,
			vendor_org_id
		order by
			vendor_org_id,
			n desc
    )
  )
), 
ror as 
(
select
	ror,
	vendor_org_id,
	n,
	row_number() over (partition by ror
order by
	n desc) as row_number
from
	vendor 
)
select
	*
from
	ror
where
	row_number = 1;") |>
as_tibble()
#' backup
write_csv(ror_scp_matching, here::here("data-raw", "scp_wos_matching.csv"))

#' Items where no vendor could be retrieved
#' 
scp_ror_no_vendor_id <- dbGetQuery(kb_con, "with doi_groups as (
select
	doi,
	case
		when every(vendor_org_id is null) then true
		else false
	end as all_null
from
	ta_scopus_aff
group by
	doi
)
select distinct *
from
	doi_groups
where
	all_null = true;"
                               )
#' Backup
write_csv(scp_ror_no_vendor_id, here::here("data-raw", "scp_ror_no_vendor_id.csv"))




#' ## Prepare journal data
jct_issn <- hoaddata::jct_hybrid_jns |>
  distinct(issn, issn_l)
dbWriteTable(kb_con, "jct_hybrid_jns_issn", jct_issn, overwrite = TRUE)

#### Retrieve articles from hybrid journals
dbExecute(kb_con, "DROP TABLE wos_jct_items")

dbExecute(kb_con, "CREATE table wos_jct_items AS 
select distinct 
    issn_l,
	item_id,
	doi,
	pubyear,
	wos_pubdate_online,
	oa_status,
	item_type
from (
select
	distinct 
	jhji.issn_l,
	i.item_id,
	doi,
	pubyear,
	wos_pubdate_online,
	unnest(wos_ci) as ci,
	oa_status,
	item_type
from
	jct_hybrid_jns_issn jhji
left join wos_b_202404.v_issn_isbn vii on
	jhji.issn = vii.sn
left join wos_b_202401.v_items i on
	vii.item_id = i.item_id
where
	pubyear > 2017 ) as tmp
where ci in ('SCI', 'SSCI', 'AHCI')")

wos_jct_items <- DBI::dbReadTable(kb_con, "wos_jct_items")
#' backup
wos_jct_items_df <- wos_jct_items |> 
  as_tibble() |> 
  mutate(item_type = as.character(gsub('\\{|\\}|"', '', item_type))) |>
  mutate(oa_status = as.character(gsub('\\{|\\}|"', '', oa_status)))
write_csv(wos_jct_items_df, "data-raw/wos_jct_items_df.csv")

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
	via2.vendor_org_id,
	via2.countrycode
from
	wos_jct_items jct
left join wos_b_202404.v_items_authors via on
	jct.item_id = via.item_id
left join wos_b_202404.v_authors_affiliations vaa2 on
	jct.item_id = vaa2.item_id
	and via.author_seq_nr = vaa2.author_seq_nr
left join wos_b_202404.v_items_affiliations via2 on
	jct.item_id = via2.item_id
	and vaa2.aff_seq_nr = via2.aff_seq_nr
where
	via.author_seq_nr = 1 or corresponding = true")

tt <- DBI::dbReadTable(kb_con, "wos_jct_affiliations")
wos_jct_affiliations <- tt |>
  mutate(vendor_org_id = gsub('\\{|\\}|"', '', vendor_org_id)) |>
  mutate(doi = tolower(doi)) |>
  as_tibble()
write_csv(wos_jct_affiliations, "data-raw/wos_jct_affiliations.csv")

### Scopus items and affiliations

#### Retrieve articles from hybrid journals
dbExecute(kb_con, "DROP TABLE scp_jct_items")

dbExecute(kb_con, "CREATE table scp_jct_items AS 
select distinct 
    issn_l,
	item_id,
	doi,
	pubyear,
	first_pubyear,
	oa_status,
	item_type
from (
select
	distinct 
	jhji.issn_l,
	i.item_id,
	doi,
	pubyear,
	first_pubyear,
	sn_c,
	oa_status,
	item_type
from
	jct_hybrid_jns_issn jhji
left join scp_b_202404.issn_isbn vii on
	jhji.issn = vii.sn_c
left join scp_b_202401.items i on
	vii.item_id = i.item_id
where
	pubyear > 2017 ) as tmp")

scp_jct_items <- DBI::dbReadTable(kb_con, "scp_jct_items")
#' backup
scp_jct_items_df <- scp_jct_items |> 
  as_tibble() |> 
  mutate(item_type = as.character(gsub('\\{|\\}|"', '', item_type))) |>
  mutate(oa_status = as.character(gsub('\\{|\\}|"', '', oa_status)))
write_csv(scp_jct_items_df, "data-raw/scp_jct_items_df.csv")

#### Add WOS affiliation data for first data and corresponding authors
dbExecute(kb_con, "DROP TABLE scp_jct_affiliations")

dbExecute(kb_con, "CREATE table scp_jct_affiliations AS select distinct jct.item_id,
	jct.issn_l,
	jct.doi,
	jct.pubyear,
	jct.first_pubyear,
	via.author_seq_nr,
	via.corresponding,
	via.orcid,
	via2.vendor_org_id,
	via2.organization,
	via2.countrycode
from
	scp_jct_items jct
left join scp_b_202404.items_authors via on
	jct.item_id = via.item_id
left join scp_b_202404.authors_affiliations vaa2 on
	jct.item_id = vaa2.item_id
	and via.author_seq_nr = vaa2.author_seq_nr
left join scp_b_202404.items_affiliations via2 on
	jct.item_id = via2.item_id
	and vaa2.aff_seq_nr = via2.aff_seq_nr
where
	via.author_seq_nr = 1 or corresponding = true")

tt <- DBI::dbReadTable(kb_con, "scp_jct_affiliations")
scp_jct_affiliations <- tt |>
  mutate(vendor_org_id = gsub('\\{|\\}|"', '', vendor_org_id)) |>
  mutate(organization = gsub('\\{|\\}|"', '', organization)) |>
  mutate(doi = tolower(doi)) |>
  as_tibble()
write_csv(scp_jct_affiliations, "data-raw/scp_jct_affiliations.csv")

### BigQuery raw

hoad_dois_all <- DBI::dbGetQuery(bq_con, "SELECT
  DISTINCT doi,
  issn_l,
  cr_year
FROM
  `subugoe-collaborative.hoaddata.cc_md`
WHERE
  cr_year BETWEEN 2019
  AND 2023")

# backup

write_csv(hoad_dois_all, here::here("data-raw", "hoad_dois_all_19_23.csv"))

#' Disconnect DB
DBI::dbDisconnect(bq_con)
DBI::dbDisconnect(kb_con)

