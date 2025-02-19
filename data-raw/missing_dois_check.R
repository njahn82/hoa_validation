## Check missing dois in KB
library(DBI)
library(RPostgres)
library(tidyverse)
#' Connect to DB 
#' 
#' KB Postgres (Web of Science, Scopus)
kb_con <- dbConnect(RPostgres::Postgres(),
                    host = "biblio-p-db03.fiz-karlsruhe.de",
                    port = 6432,
                    dbname = "kbprod",
                    user =  Sys.getenv("kb_user"),
                    password = Sys.getenv("kb_pwd"),
                    bigint = "numeric"
)
miss_dois <- readr::read_csv(here::here("data-raw", "missing_dois_in_active_jns.csv"))

dbWriteTable(kb_con, "miss_dois", miss_dois, overwrite = TRUE)

miss_dois_counts <- dbGetQuery(kb_con, "select
	count(distinct md.doi) as n_doi,
	i.item_type as scp_item_type,
	i2.item_type as wos_item_type,
	i.first_pubyear,
	i.pubyear,
	i2.pubyear as scp_year
from
	miss_dois md
left join scp_b_202404.items i on
	md.doi = i.doi
left join wos_b_202304.v_items i2 on
	md.doi = i2.doi
group by
	i.item_type,
	i2.item_type,
	i.first_pubyear,
	i.pubyear,
	i2.pubyear")

miss_dois_counts |>
  as_tibble() |>
  arrange(desc(n_doi)) |>
  write_csv(here::here("data-raw", "miss_dois_in_active_jns_ckeck.csv"))
