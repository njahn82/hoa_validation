
## About

This folder contains analytical datasets providing aggregated counts on
the uptake of open access in hybrid journals included in transformative
agreements by journal and country information between 2019 and 2023. A
particular focus was on whether publications were from eligible authors
who could use such agreements. For this purpose, the affiliations of
first and corresponding authors were analysed.

The following datasets were used:

- Scopus (`scp`): In-house Scopus database provided by the
  Kompetenznetzwerk Bibliometrie (April 2024 snapshot)
- Web of Science (`wos`): In-house Web of Science database provided by
  the Kompetenznetzwerk Bibliometrie (April 2024 snapshot)

See `data-raw/` how the subset of publications associated with hybrid
journals and transformative agreements was retrieved. The indicator were
determined using SQL. `indicators.R` contains the database queries.

## Data files

### Overview

Articles in hybrid journals by year

| Variable | Description |
|----|----|
| `earliest_year` | Year first published |
| `pub_type` | `core`: Article or Review; `all`: All articles regardless of item type |
| `n_articles` | Number of items |
| `n_oa_articles` | Number of items in the database with a hybrid flag, indicating open access availability under an open license |
| `p` | Open access uptake |

#### `wos_by_year`

Web of Science

``` r
readr::read_csv(here("data", "wos_by_year.csv"))
```

    ## # A tibble: 10 × 5
    ##    earliest_year pub_type n_articles n_oa_articles      p
    ##            <dbl> <chr>         <dbl>         <dbl>  <dbl>
    ##  1          2023 core        1312766        258038 0.197 
    ##  2          2023 all         1690767        273181 0.162 
    ##  3          2022 core        1366245        234117 0.171 
    ##  4          2022 all         1736039        253557 0.146 
    ##  5          2021 core        1470581        223014 0.152 
    ##  6          2021 all         1839456        243135 0.132 
    ##  7          2020 core        1388593        177087 0.128 
    ##  8          2020 all         1781448        194104 0.109 
    ##  9          2019 core        1314879        138441 0.105 
    ## 10          2019 all         1745710        160918 0.0922

#### `scp_by_year`

Scopus

``` r
readr::read_csv(here("data", "scp_by_year.csv"))
```

    ## # A tibble: 10 × 5
    ##    earliest_year pub_type n_articles n_oa_articles      p
    ##            <dbl> <chr>         <dbl>         <dbl>  <dbl>
    ##  1          2023 core        1708860        326466 0.191 
    ##  2          2023 all         1881806        341561 0.182 
    ##  3          2022 core        1549643        215073 0.139 
    ##  4          2022 all         1704628        225977 0.133 
    ##  5          2021 core        1499193        178140 0.119 
    ##  6          2021 all         1662564        189672 0.114 
    ##  7          2020 core        1411049        130120 0.0922
    ##  8          2020 all         1584885        141930 0.0896
    ##  9          2019 core        1331727         86025 0.0646
    ## 10          2019 all         1487060         91131 0.0613

### By hybrid journal

Articles in hybrid journals by year and hybrid journal included in a
transformative agreement

| Variable | Description |
|----|----|
| `issn_l` | Linking ISSN, a unique identifier for different journal ISSN according to the ISSN agency |
| `earliest_year` | Year first published |
| `pub_type` | `core`: Article or Review; `all`: All articles regardless of item type |
| `n` | Number of items |
| `oa_articles` | Number of items in the database with a hybrid flag, indicating open access availability under an open license |

#### `wos_jn_by_year`

Web of Science

``` r
readr::read_csv(here("data", "wos_jn_by_year.csv"))
```

    ## # A tibble: 85,873 × 5
    ##    issn_l    earliest_year pub_type     n oa_articles
    ##    <chr>             <dbl> <chr>    <dbl>       <dbl>
    ##  1 0001-0782          2019 core        94           0
    ##  2 0001-0782          2019 all        314           0
    ##  3 0001-0782          2020 core        89           0
    ##  4 0001-0782          2020 all        322           0
    ##  5 0001-0782          2021 core        93           0
    ##  6 0001-0782          2021 all        356           0
    ##  7 0001-0782          2022 core        93           2
    ##  8 0001-0782          2022 all        343           3
    ##  9 0001-0782          2023 core        84           9
    ## 10 0001-0782          2023 all        290           9
    ## # ℹ 85,863 more rows

#### `scp_jn_by_year`

Scopus

``` r
readr::read_csv(here("data", "scp_jn_by_year.csv"))
```

    ## # A tibble: 116,725 × 5
    ##    issn_l    earliest_year pub_type     n oa_articles
    ##    <chr>             <dbl> <chr>    <dbl>       <dbl>
    ##  1 0001-0782          2019 all        258           0
    ##  2 0001-0782          2019 core       141           0
    ##  3 0001-0782          2020 all        296           2
    ##  4 0001-0782          2020 core       155           1
    ##  5 0001-0782          2021 all        344           1
    ##  6 0001-0782          2021 core       182           0
    ##  7 0001-0782          2022 all        319           4
    ##  8 0001-0782          2022 core       184           4
    ##  9 0001-0782          2023 all        271          11
    ## 10 0001-0782          2023 core       169          11
    ## # ℹ 116,715 more rows

### Country affiliations

Indicators are provided for both first and corresponding authors.
Because of multiple country affiliations, full counting was applied.
Note that the bibliometric database did not always include the
corresponding affiliation.

| Variable | Description |
|----|----|
| `issn_l` | Linking ISSN, a unique identifier for different journal ISSN according to the ISSN agency |
| `earliest_year` | Year first published |
| `country_code` | ISO three letter country codes |
| `pub_type` | `core`: Article or Review; `all`: All articles regardless of item type |
| `n` | Number of items |
| `oa_articles` | Number of items in the database with a hybrid flag, indicating open access availability under an open license |
| `first_author_articles` | Number of items from first authors |
| `oa_first_author_articles` | Number of open access items (tagged as hybrid) from first authors |
| `corresponding_author_articles` | Number of items from corresponding authors |
| `oa_first_author_articles` | Number of open access items (tagged as hybrid) from corresponding authors |
| `first_corresponding_author_articles` | Number of items from first authors, which are also corresponding authors |
| `oa_first_corresponding_author_articles` | Number of open access items (tagged as hybrid) from first authors, which are also corresponding authors |

#### `wos_country_aff.csv`

Web of Science

``` r
readr::read_csv(here("data", "wos_country_aff.csv"))
```

    ## # A tibble: 2,081,308 × 12
    ##    issn_l    earliest_year countrycode pub_type     n oa_articles
    ##    <chr>             <dbl> <chr>       <chr>    <dbl>       <dbl>
    ##  1 0001-0782          2019 AUS         all          2           0
    ##  2 0001-0782          2019 AUS         core         2           0
    ##  3 0001-0782          2019 AUT         all          2           0
    ##  4 0001-0782          2019 CHE         all          3           0
    ##  5 0001-0782          2019 CHN         core         1           0
    ##  6 0001-0782          2019 DNK         all          3           0
    ##  7 0001-0782          2019 ESP         core         1           0
    ##  8 0001-0782          2019 ISR         all          5           0
    ##  9 0001-0782          2019 JPN         all          1           0
    ## 10 0001-0782          2019 LKA         all          1           0
    ## # ℹ 2,081,298 more rows
    ## # ℹ 6 more variables: first_author_articles <dbl>,
    ## #   oa_first_author_articles <dbl>, corresponding_author_articles <dbl>,
    ## #   oa_corresponding_author_articles <dbl>,
    ## #   first_corresponding_author_articles <dbl>,
    ## #   oa_first_corresponding_author_articles <dbl>

#### `scp_country_aff.csv`

Scopus

``` r
readr::read_csv(here("data", "scp_country_aff.csv"))
```

    ## # A tibble: 2,442,479 × 12
    ##    issn_l    earliest_year countrycode pub_type     n oa_articles
    ##    <chr>             <dbl> <chr>       <chr>    <dbl>       <dbl>
    ##  1 0001-0782          2019 <NA>        all          1           0
    ##  2 0001-0782          2019 <NA>        core         1           0
    ##  3 0001-0782          2019 AUS         all          5           0
    ##  4 0001-0782          2019 AUS         core         2           0
    ##  5 0001-0782          2019 AUT         all          1           0
    ##  6 0001-0782          2019 AUT         core         1           0
    ##  7 0001-0782          2019 BEL         all          3           0
    ##  8 0001-0782          2019 BEL         core         1           0
    ##  9 0001-0782          2019 CAN         all          2           0
    ## 10 0001-0782          2019 CHE         core         1           0
    ## # ℹ 2,442,469 more rows
    ## # ℹ 6 more variables: first_author_articles <dbl>,
    ## #   oa_first_author_articles <dbl>, corresponding_author_articles <dbl>,
    ## #   oa_corresponding_author_articles <dbl>,
    ## #   first_corresponding_author_articles <dbl>,
    ## #   oa_first_corresponding_author_articles <dbl>

### Transformative agreement data: Overview

The following data files contain indicators for journals where a link
were established between articles and eligible institutions
participating in transformative agreements. This could be achieved by
linking author affiliations with agreement data.

Note that the earliest snapshot available with information about
transformative agreemnt were from July 2021, while the analysis started
in 2019.

| Variable | Description |
|----|----|
| `earliest_year` | Year first published |
| `pub_type` | `core`: Article or Review; `all`: All articles regardless of item type |
| `ta_articles` | Number of items under an transformative agreement (first OR corresponding author) |
| `ta_oa_articles` | Number of items under an transformative agreement in the database with a hybrid flag, indicating open access availability under an open license (first OR corresponding author) |
| `ta_first_author_articles` | Number items from first authors under an transformative agreement |
| `ta_oa_first_author_articles` | Number of open access items (tagged as hybrid) from first authors under an transformative agreement |
| `ta_corresponding_author_articles` | Number of items from corresponding authors under an transformative agreement |
| `ta_oa_first_author_articles` | Number of open access items (tagged as hybrid) from corresponding authors under an transformative agreement |
| `ta_first_corresponding_author_articles` | Number of items from first authors under an transformative agreement, which are also corresponding authors |
| `ta_oa_first_corresponding_author_articles` | Number of open access items (tagged as hybrid) from first authors under an transformative agreement, which are also corresponding authors |

#### `wos_ta_by_year`

Web of Science

``` r
readr::read_csv(here("data", "wos_ta_by_year.csv"))
```

    ## # A tibble: 10 × 10
    ##    earliest_year pubtype ta_articles ta_oa_articles ta_first_author_articles
    ##            <dbl> <chr>         <dbl>          <dbl>                    <dbl>
    ##  1          2023 all          343183         179331                   328807
    ##  2          2023 core         267272         171793                   253923
    ##  3          2022 all          285204         132176                   273576
    ##  4          2022 core         221064         126478                   210250
    ##  5          2021 all          232941         105390                   224126
    ##  6          2021 core         184281         100560                   176027
    ##  7          2020 all          136238          60555                   131717
    ##  8          2020 core         110511          58037                   106339
    ##  9          2019 all           46990          19100                    45424
    ## 10          2019 core          37802          18549                    36325
    ## # ℹ 5 more variables: ta_oa_first_author_articles <dbl>,
    ## #   ta_corresponding_author_articles <dbl>,
    ## #   ta_oa_corresponding_author_articles <dbl>,
    ## #   ta_first_corresponding_author_articles <dbl>,
    ## #   ta_oa_first_corresponding_author_articles <dbl>

#### `scp_ta_by_year`

Scopus

``` r
readr::read_csv(here("data", "scp_ta_by_year.csv"))
```

    ## # A tibble: 10 × 10
    ##    earliest_year pubtype ta_articles ta_oa_articles ta_first_author_articles
    ##            <dbl> <chr>         <dbl>          <dbl>                    <dbl>
    ##  1          2023 core         335542         214396                   308494
    ##  2          2023 all          364652         221444                   335759
    ##  3          2022 core         237181         127417                   217834
    ##  4          2022 all          259563         131940                   238892
    ##  5          2021 core         178355          92919                   164787
    ##  6          2021 all          195700          96886                   181073
    ##  7          2020 core          99739          48522                    92948
    ##  8          2020 all          110041          50799                   102638
    ##  9          2019 core          33925          15823                    31912
    ## 10          2019 all           36419          16209                    34277
    ## # ℹ 5 more variables: ta_oa_first_author_articles <dbl>,
    ## #   ta_corresponding_author_articles <dbl>,
    ## #   ta_oa_corresponding_author_articles <dbl>,
    ## #   ta_first_corresponding_author_articles <dbl>,
    ## #   ta_oa_first_corresponding_author_articles <dbl>

### Transformative agreement data by hybrid journal

Articles in hybrid journals under transformative agreements by journal.

| Variable | Description |
|----|----|
| `issn_l` | Linking ISSN, a unique identifier for different journal ISSN according to the ISSN agency |
| `earliest_year` | Year first published |
| `pub_type` | `core`: Article or Review; `all`: All articles regardless of item type |
| `ta_articles` | Number of items under an transformative agreement (first OR corresponding author) |
| `ta_oa_articles` | Number of items under an transformative agreement in the database with a hybrid flag, indicating open access availability under an open license (first OR corresponding author) |
| `ta_first_author_articles` | Number items from first authors under an transformative agreement |
| `ta_oa_first_author_articles` | Number of open access items (tagged as hybrid) from first authors under an transformative agreement |
| `ta_corresponding_author_articles` | Number of items from corresponding authors under an transformative agreement |
| `ta_oa_first_author_articles` | Number of open access items (tagged as hybrid) from corresponding authors under an transformative agreement |
| `ta_first_corresponding_author_articles` | Number of items from first authors under an transformative agreement, which are also corresponding authors |
| `ta_oa_first_corresponding_author_articles` | Number of open access items (tagged as hybrid) from first authors under an transformative agreement, which are also corresponding authors |

#### `wos_jn_ta_by_year`

Web of Science

``` r
readr::read_csv(here("data", "wos_jn_ta_by_year.csv"))
```

    ## # A tibble: 71,416 × 11
    ##    issn_l    earliest_year pubtype ta_articles ta_oa_articles
    ##    <chr>             <dbl> <chr>         <dbl>          <dbl>
    ##  1 1698-031X          2023 all               7              1
    ##  2 0025-7753          2023 all             164              6
    ##  3 0272-8842          2023 all             252            114
    ##  4 0308-8146          2023 all             341            213
    ##  5 0263-8223          2023 all             232            133
    ##  6 0260-6917          2023 all              74             51
    ##  7 0277-5395          2023 all              68             36
    ##  8 0006-3207          2023 all             197            142
    ##  9 1388-1981          2023 all              28             15
    ## 10 0924-0136          2023 all              51             19
    ## # ℹ 71,406 more rows
    ## # ℹ 6 more variables: ta_first_author_articles <dbl>,
    ## #   ta_oa_first_author_articles <dbl>, ta_corresponding_author_articles <dbl>,
    ## #   ta_oa_corresponding_author_articles <dbl>,
    ## #   ta_first_corresponding_author_articles <dbl>,
    ## #   ta_oa_first_corresponding_author_articles <dbl>

#### `scp_ta_jn_by_year`

Scopus

``` r
readr::read_csv(here("data", "scp_ta_jn_by_year.csv"))
```

    ## # A tibble: 84,779 × 11
    ##    issn_l    earliest_year pubtype ta_articles ta_oa_articles
    ##    <chr>             <dbl> <chr>         <dbl>          <dbl>
    ##  1 0001-0782          2023 all              33              1
    ##  2 0001-0782          2023 core             22              1
    ##  3 0001-1541          2023 all              87             47
    ##  4 0001-1541          2023 core             85             47
    ##  5 0001-2092          2023 all               4              0
    ##  6 0001-2092          2023 core              3              0
    ##  7 0001-2998          2023 all              48             17
    ##  8 0001-2998          2023 core             48             17
    ##  9 0001-3072          2023 all              17              9
    ## 10 0001-3072          2023 core             17              9
    ## # ℹ 84,769 more rows
    ## # ℹ 6 more variables: ta_first_author_articles <dbl>,
    ## #   ta_oa_first_author_articles <dbl>, ta_corresponding_author_articles <dbl>,
    ## #   ta_oa_corresponding_author_articles <dbl>,
    ## #   ta_first_corresponding_author_articles <dbl>,
    ## #   ta_oa_first_corresponding_author_articles <dbl>

### Transformative agreement data by country affiliations

Indicators are provided for both first and corresponding authors.
Because of multiple country affiliations, full counting was applied.
Note that the bibliometric database did not always include the
corresponding affiliation.

| Variable | Description |
|----|----|
| `issn_l` | Linking ISSN, a unique identifier for different journal ISSN according to the ISSN agency |
| `country_code` | ISO three letter country codes |
| `earliest_year` | Year first published |
| `pub_type` | `core`: Article or Review; `all`: All articles regardless of item type |
| `ta_articles` | Number of items under an transformative agreement (first OR corresponding author) |
| `ta_oa_articles` | Number of items under an transformative agreement in the database with a hybrid flag, indicating open access availability under an open license (first OR corresponding author) |
| `ta_first_author_articles` | Number items from first authors under an transformative agreement |
| `ta_oa_first_author_articles` | Number of open access items (tagged as hybrid) from first authors under an transformative agreement |
| `ta_corresponding_author_articles` | Number of items from corresponding authors under an transformative agreement |
| `ta_oa_first_author_articles` | Number of open access items (tagged as hybrid) from corresponding authors under an transformative agreement |
| `ta_first_corresponding_author_articles` | Number of items from first authors under an transformative agreement, which are also corresponding authors |
| `ta_oa_first_corresponding_author_articles` | Number of open access items (tagged as hybrid) from first authors under an transformative agreement, which are also corresponding authors |

#### `wos_jn_country_ta_by_year`

Web of Science

``` r
readr::read_csv(here("data", "wos_jn_country_ta_by_year.csv"))
```

    ## # A tibble: 373,606 × 12
    ##    issn_l    countrycode earliest_year pubtype ta_articles ta_oa_articles
    ##    <chr>     <chr>               <dbl> <chr>         <dbl>          <dbl>
    ##  1 0001-0782 CHN                  2021 core              1              0
    ##  2 0001-0782 CHN                  2021 all               2              0
    ##  3 0001-0782 DEU                  2021 core              4              0
    ##  4 0001-0782 DEU                  2021 all               6              0
    ##  5 0001-0782 GBR                  2021 core              2              0
    ##  6 0001-0782 GBR                  2021 all               2              0
    ##  7 0001-0782 IRL                  2021 all               1              0
    ##  8 0001-0782 NLD                  2021 all               1              0
    ##  9 0001-0782 AUT                  2022 all               3              0
    ## 10 0001-0782 CHE                  2022 core              1              0
    ## # ℹ 373,596 more rows
    ## # ℹ 6 more variables: ta_first_author_articles <dbl>,
    ## #   ta_oa_first_author_articles <dbl>, ta_corresponding_author_articles <dbl>,
    ## #   ta_oa_corresponding_author_articles <dbl>,
    ## #   ta_first_corresponding_author_articles <dbl>,
    ## #   ta_oa_first_corresponding_author_articles <dbl>

#### `wos_jn_country_ta_by_year`

Scopus

``` r
readr::read_csv(here("data", "scp_jn_country_ta_by_year.csv"))
```

    ## # A tibble: 422,068 × 12
    ##    issn_l    countrycode earliest_year pubtype ta_articles ta_oa_articles
    ##    <chr>     <chr>               <dbl> <chr>         <dbl>          <dbl>
    ##  1 0001-0782 CHN                  2021 core              2              0
    ##  2 0001-0782 CHN                  2021 all               2              0
    ##  3 0001-0782 DEU                  2021 core              3              0
    ##  4 0001-0782 DEU                  2021 all               3              0
    ##  5 0001-0782 GBR                  2021 core              2              0
    ##  6 0001-0782 GBR                  2021 all               2              0
    ##  7 0001-0782 IRL                  2021 core              1              0
    ##  8 0001-0782 IRL                  2021 all               1              0
    ##  9 0001-0782 NLD                  2021 all               1              0
    ## 10 0001-0782 AUT                  2022 all               3              0
    ## # ℹ 422,058 more rows
    ## # ℹ 6 more variables: ta_first_author_articles <dbl>,
    ## #   ta_oa_first_author_articles <dbl>, ta_corresponding_author_articles <dbl>,
    ## #   ta_oa_corresponding_author_articles <dbl>,
    ## #   ta_first_corresponding_author_articles <dbl>,
    ## #   ta_oa_first_corresponding_author_articles <dbl>
