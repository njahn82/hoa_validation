## hoaddata validation 

## Data flow

### Journal-level analysis

### Article-level analysis

#### Open access by hybrid journal

ISSN variants from `hoaddata::jct_hybrid_jns` were uplaoded to the KB and  matched with the WoS. Along with the WoS record IDs, doc type information and open access status informationw ere gathered. This allows two essential distinctions:

- all records vs citable items (articles and reviews)
- open access information as recorded by WoS (via Unpaywall) vs. information in Crossref as gathered from `hoaddata::cc_articles`

Query

```sql
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
left join wos_b_202401.v_issn_isbn vii on
	jhji.issn = vii.sn
left join wos_b_202401.v_items i on
	vii.item_id = i.item_id
where
	pubyear > 2017 ) as tmp
where ci in ('SCI', 'SSCI', 'AHCI')
```

Resulting file is safeguarded in `data-raw/wos_jct_items_df.csv`

#### Open acccess by institution

#### Open access by TA