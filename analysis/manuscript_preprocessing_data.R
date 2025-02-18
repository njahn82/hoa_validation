### Data preprocessing for the manuscript

## Why? It just takes too long to render everything in the manuscript.

library(tidyverse, warn.conflicts = FALSE)
library(bigrquery)
library(here)

# METHOD -------

## HOAD
hoad_jns <- hoaddata::jct_hybrid_jns |>
  filter(issn_l != "0027-8424")

# Full OA journals detected through OA proportion > .95
hoad_oa_excluded <- bq_table_download("hoa-article.hoaddata_sep24.cc_oa_prop") |>
  distinct(issn_l)

active_jns <- hoad_jns |>
  # Only active hybrid journals from JCT
  inner_join(hoaddata::jn_ind, by = "issn_l") |>
  filter(!cr_year %in% c("2017", "2018", "2024"))

active_jns_with_oa <- active_jns |> 
  filter(!is.na(cc))

# Get indicators for all articles without applying paratext adn supplement detection
hoad_all <- read_csv(here::here("data", "cr_all_ind.csv"))

## Web of Science
wos_jct_items_df <- readr::read_csv(here::here("data-raw", "wos_jct_items_df.csv"))

wos_hybrid_jns <- wos_jct_items_df |>
  # No PNAS
  filter(issn_l != "0027-8424") |>
  # No Full OA detected by OA prop
  filter(!issn_l %in% hoad_oa_excluded$issn_l)

wos_active_jns <- wos_hybrid_jns |>
  # Use online first, if available
  mutate(online_year = lubridate::year(wos_pubdate_online)) |>
  mutate(pub_year = ifelse(!is.na(online_year), online_year, pubyear)) |>
  filter(pub_year %in% 2019:2023)

wos_active_jns_with_oa <- wos_active_jns |> 
  filter(grepl("hybrid", oa_status))

# wos core 
wos_active_core <- wos_active_jns |>
  filter(grepl("Article|^Review$", item_type))

wos_active_core_oa <- wos_active_jns |>
  filter(grepl("hybrid", oa_status))

## Scopus

scp_jct_items_df <- readr::read_csv(here::here("data-raw", "scp_jct_items_df.csv"))

scp_hybrid_jns <- scp_jct_items_df |>
  # No PNAS
  filter(issn_l != "0027-8424") |>
  # No Full OA detected by OA prop
  filter(!issn_l %in% hoad_oa_excluded$issn_l)

scp_active_jns <- scp_hybrid_jns |>
  # Use online first, if available
  mutate(pub_year = ifelse(!is.na(first_pubyear), first_pubyear, pubyear)) |>
  filter(pub_year %in% 2019:2023)

scp_active_jns_with_oa <- scp_active_jns |> 
  filter(grepl("hybrid", oa_status))

# core
scp_active_core <- scp_active_jns |>
  filter(grepl("^Article|^Review", item_type))

scp_active_core_oa <- scp_active_core |>
  filter(grepl("hybrid", oa_status))


### Journals
ind_active_jns <- c(`hoad` = hoad_all$active_journals, 
                    `wos` = length(unique(wos_active_jns$issn_l)),
                    `scp` = length(unique(scp_active_jns$issn_l)))
ind_active_jns_core <- c(`hoad` = length(unique(active_jns$issn_l)), 
                         `wos` = length(unique(wos_active_core$issn_l)),
                         `scp` = length(unique(scp_active_core$issn_l)))
ind_active_jns_core_with_oa <-  c(`hoad` = length(unique(active_jns_with_oa$issn_l)), 
                                  `wos` = length(unique(wos_active_core_oa$issn_l)),
                                  `scp` = length(unique(scp_active_core_oa$issn_l)))

jns_ind <- bind_rows(ind_active_jns = ind_active_jns,
                     ind_active_jns_core = ind_active_jns_core,
                     ind_active_jns_core_with_oa = ind_active_jns_core_with_oa, .id = "indicator")

### Article Volume


## hoad

# DOI set too large to track it with Git, see 001_data_gathering how the data
# was obtained from Google BQ
cr_df <- readr::read_csv(here::here("data-raw/hoad_dois_all_19_23.csv"))

ind_articles_hoad <- cr_df |>
  filter(issn_l %in% active_jns_with_oa$issn_l) |>
  distinct(doi) |>
  nrow()

## WoS
ind_articles_wos <- wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  distinct(item_id) |>
  nrow()

# core
ind_core_articles_wos <- wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  filter(grepl("Article|^Review$", item_type)) |>
  distinct(item_id) |>
  nrow()
# doi
ind_articles_wos_doi <- wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  distinct(doi) |>
  nrow()

ind_core_articles_wos_doi <- wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  filter(grepl("Article|^Review$", item_type)) |>
  distinct(doi) |>
  nrow()
## scopus
ind_articles_scp <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  distinct(item_id) |>
  nrow()
# core
ind_core_articles_scp <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  filter(grepl("^Article|^Review", item_type)) |>
  distinct(item_id) |>
  nrow()
# doi
ind_articles_scp_doi <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  distinct(doi) |>
  nrow()

ind_core_articles_scp_doi <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  filter(grepl("Article|^Review$", item_type)) |>
  distinct(doi) |>
  nrow()

# Bringing it all together
ind_articles_total <- c(`hoad` = hoad_all$active_journals_all,
                        `wos` = ind_articles_wos,
                        `scp` = ind_articles_scp)
ind_articles_core <- c(`hoad` = ind_articles_hoad,
                       `wos` = ind_core_articles_wos,
                       `scp` = ind_core_articles_scp)
ind_articles_doi <- c(`hoad` = hoad_all$active_journals_all,
                      `wos` = ind_articles_wos_doi,
                      `scp` = ind_articles_scp_doi)
ind_articles_core_doi <- c(`hoad` = ind_articles_hoad,
                           `wos` = ind_core_articles_wos_doi,
                           `scp` = ind_core_articles_scp_doi)

articles_ind <- bind_rows(ind_articles_total = ind_articles_total,
                          ind_articles_core = ind_articles_core,
                          ind_articles_doi = ind_articles_doi,
                          ind_articles_core_doi = ind_articles_core_doi, .id = "indicator" )

## oa just core with doi

### hoad
ind_oa_articles_hoad <- hoaddata::cc_articles |>
  filter(between(cr_year, 2019, 2023)) |>
  filter(issn_l %in% active_jns$issn_l) |>
  distinct(doi) |>
  nrow()

### wos

ind_oa_articles_wos_all <- wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  filter(grepl("hybrid", oa_status)) |>
  distinct(item_id) |>
  nrow()

ind_oa_articles_wos_core <- wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  filter(grepl("Article|^Review$", item_type)) |>
  filter(grepl("hybrid", oa_status)) |>
  distinct(item_id) |>
  nrow()

### scp
ind_oa_articles_scp_all <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  filter(grepl("hybrid", oa_status)) |>
  distinct(item_id) |>
  nrow()
ind_oa_articles_scp_core <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  filter(grepl("Article|^Review$", item_type)) |>
  filter(grepl("hybrid", oa_status)) |>
  distinct(item_id) |>
  nrow()


ind_oa_articles_all <- c(`hoad` = hoad_all$ind_oa_articles_all,
                         `wos` = ind_oa_articles_wos_all,
                         `scp` = ind_oa_articles_scp_all
)
ind_oa_articles_core <-  c(`hoad` = ind_oa_articles_hoad,
                           `wos` = ind_oa_articles_wos_core,
                           `scp` = ind_oa_articles_scp_core
)

oa_articles_ind <- bind_rows(ind_oa_articles_all = ind_oa_articles_all,
                             ind_oa_articles_core = ind_oa_articles_core, .id = "indicator")

### affiliations

### WOS
wos_active_core_with_oa_item_ids <-  wos_active_jns |>
  filter(issn_l %in% wos_active_jns_with_oa$issn_l) |>
  filter(grepl("Article|^Review$", item_type)) |>
  distinct(item_id, oa_status)

wos_aff <- readr::read_csv(here::here("data-raw", "wos_jct_affiliations.csv"))

wos_aff_df <- wos_aff |>
  inner_join(wos_active_core_with_oa_item_ids, by = "item_id")

wos_first_au_with_affiliation <- wos_aff_df |>
  filter(author_seq_nr == 1, !is.na(vendor_org_id)) |>
  distinct(item_id) |>
  nrow()

wos_cor_au_with_affiliation <- wos_aff_df |>
  filter(corresponding == TRUE, !is.na(vendor_org_id)) |>
  distinct(item_id) |>
  nrow()

# Scopus
scp_active_core_with_oa_item_ids <- scp_active_jns |>
  filter(issn_l %in% scp_active_jns_with_oa$issn_l) |>
  filter(grepl("^Article|^Review", item_type)) |>
  distinct(item_id, oa_status) 

scp_aff <-  readr::read_csv(here::here("data-raw", "scp_jct_affiliations.csv"))

scp_aff_df <- scp_aff |>
  inner_join(scp_active_core_with_oa_item_ids, by = "item_id")

scp_first_au_with_affiliation <- scp_aff_df |>
  filter(author_seq_nr == 1, !is.na(vendor_org_id)) |>
  distinct(item_id) |>
  nrow()

scp_cor_au_with_affiliation <- scp_aff_df |>
  filter(corresponding == TRUE, !is.na(vendor_org_id)) |>
  distinct(item_id) |>
  nrow()

# hoad
aff_oalex_stats <- readr::read_csv(here::here("data", "aff_oalex_stats.csv"))

aff_ind <- bind_rows(
  first_aff = c(hoad = unlist(aff_oalex_stats$first_author_with_ror), 
                wos = wos_first_au_with_affiliation,
                scp = scp_first_au_with_affiliation),
  cor_aff = c(hoad = unlist(aff_oalex_stats$corresponding_authors_inst),
              wos = wos_cor_au_with_affiliation,
              scp = scp_cor_au_with_affiliation), .id = "indicator"
)

# Save
save(# Journals
  jns_ind,
  # Articles
  articles_ind,
  # OA
  oa_articles_ind,
  # Affiliation and Author roles
  aff_ind,
  file = here::here("data", "manuscript_data.Rda")
  )

# Results --------

## Overlap -------

# DOI set too large to track it with Git, see 001_data_gathering how the data
# was obtained from Google BQ
cr_df <- readr::read_csv(here::here("data-raw/hoad_dois_all_19_23.csv"))

cr_active_upset <- cr_df |>
  filter(issn_l %in% active_jns_with_oa$issn_l) |>
  group_by(issn_l) |>
  summarise(n_cr = n_distinct(doi)) |>
  mutate(Crossref = TRUE)
wos_active_upset <- wos_active_core |>
  filter(issn_l %in% wos_active_core_oa$issn_l) |>
  group_by(issn_l) |>
  summarise(n_wos = n_distinct(item_id)) |>
  mutate(WoS = TRUE)
scp_active_upset <- scp_active_core |>
  filter(issn_l %in% scp_active_core_oa$issn_l) |>
  group_by(issn_l) |>
  summarise(n_scp = n_distinct(item_id)) |>
  mutate(Scopus = TRUE)

jn_upset_ <- dplyr::full_join(cr_active_upset, wos_active_upset, by = "issn_l") |>
  dplyr::full_join(scp_active_upset, by = "issn_l") |>
  mutate(across(c(Crossref, WoS, Scopus), ~ replace_na(.x, FALSE))) |>
  # Journal 5-years article volume
  mutate(n = case_when(!is.na(n_cr) ~ n_cr, !is.na(n_scp) ~ n_scp, TRUE ~ n_wos))

## DOI overlap
scp_dois <- scp_active_core |>
  filter(issn_l %in% scp_active_core_oa$issn_l) |> 
  pull(doi)
wos_dois <- wos_active_core |>
  filter(issn_l %in% wos_active_core_oa$issn_l) |>
  pull(doi)
cr_dois <- cr_df |>
  filter(issn_l %in% active_jns_with_oa$issn_l) |>
  pull(doi)

doi_overlap_df <- cr_df |>
 # filter(issn_l %in% active_jns_with_oa$issn_l) |>
  mutate(
    in_wos_or_scopus = ifelse(doi %in% c(scp_dois, wos_dois), 1, 0),
    in_cr = ifelse(doi %in% cr_dois, 1, 0),
    in_scopus = ifelse(doi %in% scp_dois, 1, 0),
    in_wos =  ifelse(doi %in% wos_dois, 1, 0)
  )
doi_overlap <- doi_overlap_df |>
  group_by(issn_l) |>
  summarise(
    doi_in_wos_or_scopus = sum(in_wos_or_scopus),
    doi_in_scopus = sum(in_scopus),
    doi_in_wos = sum(in_wos),
    doi_cr = sum(in_cr)
  )

jn_upset_articles <- jn_upset_ |>
  left_join(doi_overlap, by = "issn_l")

write_csv(jn_upset_articles, here::here("data/jn_upset_articles.csv"))

# Check articles exclusively in crossref
intersection_jns <- jn_upset_articles |>
  filter(WoS == TRUE, Scopus == TRUE, Crossref == TRUE) |>
  distinct(issn_l)
  
cr_df |> 
  filter(issn_l %in% intersection_jns$issn_l) |>
  filter(doi %in% c(wos_dois, scp_dois)) |>
  distinct(doi)

cr_df |> 
  filter(issn_l %in% intersection_jns$issn_l) |>
  filter(!doi %in% c(wos_dois, scp_dois)) |>
  distinct(doi) |>
  write_csv(here::here("data-raw", "missing_dois_in_active_jns.csv"))

