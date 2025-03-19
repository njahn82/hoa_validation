# Correlation tests


## About

The aim of this document is to determine the correlation coefficients
for several hybrid open access indicators between hoaddata, Web of
Science and Scopus, focusing on country affiliations between 2019 and
2023. Related research have compared open scholarly data sources and
propietory databases at the country-level using Spearman’s rank
correlation coefficient (Alperin et al. 2024) and Kendal tau correlation
(Akbaritabar, Theile, and Zagheni 2024), showing high level of
correlations.

## Data preparation

<details class="code-fold">
<summary>Code</summary>

``` r
library(tidyverse)
library(corrr)
library(stats)
library(Hmisc)
library(here)


# Load data
jn_df <- readr::read_csv(here("data", "/jn_country_stats_all.csv")) |>
  filter(issn_l != "0027-8424") |>
  mutate(earliest_year = as.character(earliest_year))


# Calculate indicators by country and year
my_df_ind <- jn_df |> 
  select(-earliest_year) |> 
  group_by(country_code) |> 
  summarise(across(where(is.numeric), ~ sum(.x, na.rm = TRUE))) 
```

</details>

Automate reporting

<details class="code-fold">
<summary>Code</summary>

``` r
#' Create a correlation matrix with significance markers
#'
#' @param data A data frame containing the variables for correlation analysis
#' @param vars A character vector of variable names to include in the correlation matrix
#' @param group_name A string to be included in the title of the correlation matrix
#' @return A list with the correlation data frame and title
#' @importFrom dplyr select all_of
#' @importFrom Hmisc rcorr
#' @importFrom stringr str_to_title
create_correlation_table <- function(data, vars, group_name) {
  # Check if all variables exist in the data
  missing_vars <- setdiff(vars, names(data))
  if (length(missing_vars) > 0) {
    warning(paste("The following variables are not in the dataset:", 
                  paste(missing_vars, collapse = ", ")))
    vars <- intersect(vars, names(data))
  }
  
  # Select only the specified variables
  subset_data <- data %>% select(all_of(vars))
  
  # Calculate Spearman correlation
  corr_result <- rcorr(as.matrix(subset_data), type = "spearman")
  r <- corr_result$r
  p <- corr_result$P
  
  # Create a dataframe for the table
  corr_df <- as.data.frame(r)
  
  # Add significance markers
  for (i in 1:nrow(r)) {
    for (j in 1:ncol(r)) {
      if (!is.na(p[i, j])) {
        if (p[i, j] < 0.001) {
          corr_df[i, j] <- paste0(round(r[i, j], 2), "***")
        } else if (p[i, j] < 0.01) {
          corr_df[i, j] <- paste0(round(r[i, j], 2), "**")
        } else if (p[i, j] < 0.05) {
          corr_df[i, j] <- paste0(round(r[i, j], 2), "*")
        } else {
          corr_df[i, j] <- round(r[i, j], 2)
        }
      }
    }
  }
  
  # Set diagonal to "-"
  for (i in 1:nrow(corr_df)) {
    corr_df[i, i] <- "-"
  }
  
  return(list(df = corr_df, title = paste0(group_name, "--Spearman Correlation Matrix")))
}

#' Display correlation matrix using Pandoc table with row names
#'
#' @param corr_list A list containing the correlation data frame and title
#' @return A character string containing the Pandoc table
create_pandoc_table <- function(corr_list) {
  footnote_text <- c("\\* p < 0.05", "** p < 0.01", "*** p < 0.001")
  
  # Convert the correlation dataframe to include row names as a column
  corr_df <- corr_list$df
  corr_df <- rownames_to_column(corr_df, var = "Variable")
  
  # Add title
  table_title <- paste("###", corr_list$title, "\n\n")
  
  # Create the Pandoc table
  pandoc_table <- paste(capture.output(knitr::kable(corr_df, format = "pandoc")), collapse = "\n")
  
  # Add footnotes
  footnotes <- paste(footnote_text, collapse = "\n")
  
  return(paste(table_title, pandoc_table, "\n\n", footnotes, sep = "\n"))
}
```

</details>

## Results

<details class="code-fold">
<summary>Code</summary>

``` r
cor_articles <- create_correlation_table(my_df_ind, vars = c("hoad_articles", "scp_first_author_articles", "wos_first_author_articles", 
            "scp_corresponding_author_articles", "wos_corresponding_author_articles"), "Article volume")
cat(create_pandoc_table(cor_articles))
```

</details>

### Article volume–Spearman Correlation Matrix

| Variable | hoad_articles | scp_first_author_articles | wos_first_author_articles | scp_corresponding_author_articles | wos_corresponding_author_articles |
|:---|:---|:---|:---|:---|:---|
| hoad_articles | \- | 0.99\*\*\* | 0.94\*\*\* | 0.99\*\*\* | 0.94\*\*\* |
| scp_first_author_articles | 0.99\*\*\* | \- | 0.96\*\*\* | 1\*\*\* | 0.95\*\*\* |
| wos_first_author_articles | 0.94\*\*\* | 0.96\*\*\* | \- | 0.95\*\*\* | 1\*\*\* |
| scp_corresponding_author_articles | 0.99\*\*\* | 1\*\*\* | 0.95\*\*\* | \- | 0.95\*\*\* |
| wos_corresponding_author_articles | 0.94\*\*\* | 0.95\*\*\* | 1\*\*\* | 0.95\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
oa_articles <- create_correlation_table(my_df_ind, vars =  c("hoad_oa_articles", "scp_oa_first_corresponding_author_articles", "scp_oa_corresponding_author_articles",
            "wos_oa_first_author_articles", "wos_oa_corresponding_author_articles"), "Open Access volume")
cat(create_pandoc_table(oa_articles))
```

</details>

### Open Access volume–Spearman Correlation Matrix

| Variable | hoad_oa_articles | scp_oa_first_corresponding_author_articles | scp_oa_corresponding_author_articles | wos_oa_first_author_articles | wos_oa_corresponding_author_articles |
|:---|:---|:---|:---|:---|:---|
| hoad_oa_articles | \- | 0.98\*\*\* | 0.98\*\*\* | 0.94\*\*\* | 0.94\*\*\* |
| scp_oa_first_corresponding_author_articles | 0.98\*\*\* | \- | 1\*\*\* | 0.95\*\*\* | 0.95\*\*\* |
| scp_oa_corresponding_author_articles | 0.98\*\*\* | 1\*\*\* | \- | 0.95\*\*\* | 0.95\*\*\* |
| wos_oa_first_author_articles | 0.94\*\*\* | 0.95\*\*\* | 0.95\*\*\* | \- | 1\*\*\* |
| wos_oa_corresponding_author_articles | 0.94\*\*\* | 0.95\*\*\* | 0.95\*\*\* | 1\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
oa_prop_ind <- my_df_ind |>
  # As in Figure
  mutate(
    hoad_oa_prop = hoad_oa_articles / hoad_articles,
    scp_first_oa_prop = scp_oa_first_author_articles / scp_first_author_articles,
    scp_corresponding_oa_prop = scp_oa_corresponding_author_articles / scp_corresponding_author_articles,
    wos_first_oa_prop = wos_oa_first_author_articles / wos_first_author_articles,
    wos_corresponding_oa_prop = wos_oa_corresponding_author_articles / wos_corresponding_author_articles
  ) |>
  select(country_code, contains("prop")) |>
  create_correlation_table(vars =  c("hoad_oa_prop", "scp_first_oa_prop", 
            "scp_corresponding_oa_prop", "wos_first_oa_prop", "wos_corresponding_oa_prop"), "Open Access Uptake")
cat(create_pandoc_table(oa_prop_ind))
```

</details>

### Open Access Uptake–Spearman Correlation Matrix

| Variable | hoad_oa_prop | scp_first_oa_prop | scp_corresponding_oa_prop | wos_first_oa_prop | wos_corresponding_oa_prop |
|:---|:---|:---|:---|:---|:---|
| hoad_oa_prop | \- | 0.9\*\*\* | 0.86\*\*\* | 0.9\*\*\* | 0.88\*\*\* |
| scp_first_oa_prop | 0.9\*\*\* | \- | 0.95\*\*\* | 0.92\*\*\* | 0.86\*\*\* |
| scp_corresponding_oa_prop | 0.86\*\*\* | 0.95\*\*\* | \- | 0.86\*\*\* | 0.89\*\*\* |
| wos_first_oa_prop | 0.9\*\*\* | 0.92\*\*\* | 0.86\*\*\* | \- | 0.95\*\*\* |
| wos_corresponding_oa_prop | 0.88\*\*\* | 0.86\*\*\* | 0.89\*\*\* | 0.95\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
oa_prop_ind <- my_df_ind |>
  # As in Figure
  filter(!is.na(country_code), hoad_articles > 10000) |>
  mutate(
    hoad_oa_prop = hoad_oa_articles / hoad_articles,
    scp_first_oa_prop = scp_oa_first_author_articles / scp_first_author_articles,
    scp_corresponding_oa_prop = scp_oa_corresponding_author_articles / scp_corresponding_author_articles,
    wos_first_oa_prop = wos_oa_first_author_articles / wos_first_author_articles,
    wos_corresponding_oa_prop = wos_oa_corresponding_author_articles / wos_corresponding_author_articles
  ) |>
  select(country_code, contains("prop")) |>
  create_correlation_table(vars =  c("hoad_oa_prop", "scp_first_oa_prop", 
            "scp_corresponding_oa_prop", "wos_first_oa_prop", "wos_corresponding_oa_prop"), "Open Access Uptake (min 1.000 articles)")
cat(create_pandoc_table(oa_prop_ind))
```

</details>

### Open Access Uptake (min 1.000 articles)–Spearman Correlation Matrix

| Variable | hoad_oa_prop | scp_first_oa_prop | scp_corresponding_oa_prop | wos_first_oa_prop | wos_corresponding_oa_prop |
|:---|:---|:---|:---|:---|:---|
| hoad_oa_prop | \- | 1\*\*\* | 1\*\*\* | 0.98\*\*\* | 0.98\*\*\* |
| scp_first_oa_prop | 1\*\*\* | \- | 1\*\*\* | 0.99\*\*\* | 0.99\*\*\* |
| scp_corresponding_oa_prop | 1\*\*\* | 1\*\*\* | \- | 0.98\*\*\* | 0.99\*\*\* |
| wos_first_oa_prop | 0.98\*\*\* | 0.99\*\*\* | 0.98\*\*\* | \- | 1\*\*\* |
| wos_corresponding_oa_prop | 0.98\*\*\* | 0.99\*\*\* | 0.99\*\*\* | 1\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
ta_oa_articles <- create_correlation_table(my_df_ind, vars = c("hoad_ta_oa_articles", "scp_ta_oa_first_corresponding_author_articles", "scp_ta_oa_corresponding_author_articles",
            "wos_ta_oa_first_author_articles", "wos_ta_oa_corresponding_author_articles"), "Open Access volume via Transformative Agreements")
cat(create_pandoc_table(ta_oa_articles))
```

</details>

### Open Access volume via Transformative Agreements–Spearman Correlation Matrix

| Variable | hoad_ta_oa_articles | scp_ta_oa_first_corresponding_author_articles | scp_ta_oa_corresponding_author_articles | wos_ta_oa_first_author_articles | wos_ta_oa_corresponding_author_articles |
|:---|:---|:---|:---|:---|:---|
| hoad_ta_oa_articles | \- | 0.87\*\*\* | 0.87\*\*\* | 0.87\*\*\* | 0.87\*\*\* |
| scp_ta_oa_first_corresponding_author_articles | 0.87\*\*\* | \- | 0.97\*\*\* | 0.85\*\*\* | 0.86\*\*\* |
| scp_ta_oa_corresponding_author_articles | 0.87\*\*\* | 0.97\*\*\* | \- | 0.88\*\*\* | 0.89\*\*\* |
| wos_ta_oa_first_author_articles | 0.87\*\*\* | 0.85\*\*\* | 0.88\*\*\* | \- | 0.99\*\*\* |
| wos_ta_oa_corresponding_author_articles | 0.87\*\*\* | 0.86\*\*\* | 0.89\*\*\* | 0.99\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
ta_oa_articles <- my_df_ind |>
    filter(!is.na(country_code), hoad_articles > 10000) |>
  create_correlation_table(vars = c("hoad_ta_oa_articles", "scp_ta_oa_first_corresponding_author_articles", "scp_ta_oa_corresponding_author_articles",
            "wos_ta_oa_first_author_articles", "wos_ta_oa_corresponding_author_articles"), "Open Access volume via Transformative Agreements (min 1,000 articles)")
cat(create_pandoc_table(ta_oa_articles))
```

</details>

### Open Access volume via Transformative Agreements (min 1,000 articles)–Spearman Correlation Matrix

| Variable | hoad_ta_oa_articles | scp_ta_oa_first_corresponding_author_articles | scp_ta_oa_corresponding_author_articles | wos_ta_oa_first_author_articles | wos_ta_oa_corresponding_author_articles |
|:---|:---|:---|:---|:---|:---|
| hoad_ta_oa_articles | \- | 0.98\*\*\* | 0.98\*\*\* | 0.95\*\*\* | 0.95\*\*\* |
| scp_ta_oa_first_corresponding_author_articles | 0.98\*\*\* | \- | 1\*\*\* | 0.96\*\*\* | 0.96\*\*\* |
| scp_ta_oa_corresponding_author_articles | 0.98\*\*\* | 1\*\*\* | \- | 0.96\*\*\* | 0.96\*\*\* |
| wos_ta_oa_first_author_articles | 0.95\*\*\* | 0.96\*\*\* | 0.96\*\*\* | \- | 1\*\*\* |
| wos_ta_oa_corresponding_author_articles | 0.95\*\*\* | 0.96\*\*\* | 0.96\*\*\* | 1\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
ta_oa_prop <- my_df_ind |>
 #filter(hoad_ta_oa_articles > 1000) |>
  mutate(
    hoad_oa_prop = hoad_ta_oa_articles / hoad_oa_articles,
    scp_first_oa_prop = scp_ta_oa_first_author_articles / scp_oa_first_author_articles,
    scp_corresponding_oa_prop = scp_ta_oa_corresponding_author_articles / scp_oa_corresponding_author_articles,
    wos_first_oa_prop = wos_ta_oa_first_author_articles / wos_oa_first_author_articles,
    wos_corresponding_oa_prop = wos_ta_oa_corresponding_author_articles / wos_oa_corresponding_author_articles
  ) |>
  select(country_code, contains("prop")) |>
  create_correlation_table(vars =  c("hoad_oa_prop", "scp_first_oa_prop", 
            "scp_corresponding_oa_prop", "wos_first_oa_prop", "wos_corresponding_oa_prop"), "% of Hybrid OA via Agreement")
cat(create_pandoc_table(ta_oa_prop))
```

</details>

### % of Hybrid OA via Agreement–Spearman Correlation Matrix

| Variable | hoad_oa_prop | scp_first_oa_prop | scp_corresponding_oa_prop | wos_first_oa_prop | wos_corresponding_oa_prop |
|:---|:---|:---|:---|:---|:---|
| hoad_oa_prop | \- | 0.86\*\*\* | 0.85\*\*\* | 0.89\*\*\* | 0.89\*\*\* |
| scp_first_oa_prop | 0.86\*\*\* | \- | 0.98\*\*\* | 0.85\*\*\* | 0.87\*\*\* |
| scp_corresponding_oa_prop | 0.85\*\*\* | 0.98\*\*\* | \- | 0.86\*\*\* | 0.87\*\*\* |
| wos_first_oa_prop | 0.89\*\*\* | 0.85\*\*\* | 0.86\*\*\* | \- | 0.99\*\*\* |
| wos_corresponding_oa_prop | 0.89\*\*\* | 0.87\*\*\* | 0.87\*\*\* | 0.99\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

<details class="code-fold">
<summary>Code</summary>

``` r
ta_oa_prop <- my_df_ind |>
 filter(hoad_ta_oa_articles > 1000) |>
  mutate(
    hoad_oa_prop = hoad_ta_oa_articles / hoad_oa_articles,
    scp_first_oa_prop = scp_ta_oa_first_author_articles / scp_oa_first_author_articles,
    scp_corresponding_oa_prop = scp_ta_oa_corresponding_author_articles / scp_oa_corresponding_author_articles,
    wos_first_oa_prop = wos_ta_oa_first_author_articles / wos_oa_first_author_articles,
    wos_corresponding_oa_prop = wos_ta_oa_corresponding_author_articles / wos_oa_corresponding_author_articles
  ) |>
  select(country_code, contains("prop")) |>
  create_correlation_table(vars =  c("hoad_oa_prop", "scp_first_oa_prop", 
            "scp_corresponding_oa_prop", "wos_first_oa_prop", "wos_corresponding_oa_prop"), "% of Hybrid OA via Agreement (min 1.000 OA articles)")
cat(create_pandoc_table(ta_oa_prop))
```

</details>

### % of Hybrid OA via Agreement (min 1.000 OA articles)–Spearman Correlation Matrix

| Variable | hoad_oa_prop | scp_first_oa_prop | scp_corresponding_oa_prop | wos_first_oa_prop | wos_corresponding_oa_prop |
|:---|:---|:---|:---|:---|:---|
| hoad_oa_prop | \- | 0.96\*\*\* | 0.94\*\*\* | 0.96\*\*\* | 0.97\*\*\* |
| scp_first_oa_prop | 0.96\*\*\* | \- | 0.99\*\*\* | 0.96\*\*\* | 0.97\*\*\* |
| scp_corresponding_oa_prop | 0.94\*\*\* | 0.99\*\*\* | \- | 0.96\*\*\* | 0.96\*\*\* |
| wos_first_oa_prop | 0.96\*\*\* | 0.96\*\*\* | 0.96\*\*\* | \- | 1\*\*\* |
| wos_corresponding_oa_prop | 0.97\*\*\* | 0.97\*\*\* | 0.96\*\*\* | 1\*\*\* | \- |

\* p \< 0.05 \*\* p \< 0.01 \*\*\* p \< 0.001

# References

<div id="refs" class="references csl-bib-body hanging-indent"
entry-spacing="0">

<div id="ref-Akbaritabar_2024" class="csl-entry">

Akbaritabar, Aliakbar, Tom Theile, and Emilio Zagheni. 2024. “Bilateral
Flows and Rates of International Migration of Scholars for 210 Countries
for the Period 1998-2020.” *Scientific Data* 11 (1).
<https://doi.org/10.1038/s41597-024-03655-9>.

</div>

<div id="ref-alperin2024analysissuitabilityopenalexbibliometric"
class="csl-entry">

Alperin, Juan Pablo, Jason Portenoy, Kyle Demes, Vincent Larivière, and
Stefanie Haustein. 2024. “An Analysis of the Suitability of OpenAlex for
Bibliometric Analyses.” *arXiv*. <https://arxiv.org/abs/2404.17663>.

</div>

</div>
