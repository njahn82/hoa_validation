# Correlation tests


## About

The aim of this document is to determine the correlation between
coefficients for several hybrid open access indicators between hoaddata,
Web of Science and Scopus.

## Data preparation

<details class="code-fold">
<summary>Code</summary>

``` r
library(tidyverse)
library(corrr)
library(stats)
library(Hmisc)
library(here)
library(gt)


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
  
  # Create a nicer version of variable names for display
  nice_names <- gsub("_", " ", vars)
  nice_names <- stringr::str_to_title(nice_names)
  
  # Set row and column names
  rownames(corr_df) <- nice_names
  colnames(corr_df) <- nice_names
  
  return(list(df = corr_df, title = paste("Spearman Correlation Matrix -", group_name)))
}

#' Display correlation matrix using gt package with row names
#'
#' @param corr_list A list containing the correlation data frame and title
#' @return A gt table object
#' @importFrom gt gt tab_header tab_footnote cells_body everything tab_options fmt_number
create_gt_upper_triangle <- function(corr_list) {
  footnote_text <- c("* p < 0.05", "** p < 0.01", "*** p < 0.001")
  
  # Convert the correlation dataframe to include row names as a column
  corr_df <- corr_list$df
  corr_df <- rownames_to_column(corr_df, var = "Variable")
  
  # Create the gt table
  gt_table <- gt(corr_df) %>%
    # Add title as header
    tab_header(
      title = corr_list$title
    ) %>%
    # Set the Variable column as row labels
    tab_stubhead(label = "Variable") %>%
    # Add footnotes for significance levels
    tab_footnote(
      footnote = footnote_text[1],
      locations = cells_body(
        columns = everything(),
        rows = everything()
      )
    ) %>%
    tab_footnote(
      footnote = footnote_text[2],
      locations = cells_body(
        columns = everything(),
        rows = everything()
      )
    ) %>%
    tab_footnote(
      footnote = footnote_text[3],
      locations = cells_body(
        columns = everything(),
        rows = everything()
      )
    ) %>%
    # Add styling
    tab_options(
      heading.title.font.size = px(16),
      heading.subtitle.font.size = px(13),
      table.font.size = px(12),
      column_labels.font.weight = "bold",
      table.width = pct(100),
      column_labels.background.color = "#f8f8f8",
      row_group.background.color = "#f8f8f8"
    ) %>%
    # Format any numeric columns
    fmt_number(
      columns = where(is.numeric),
      decimals = 2
    )
  
  return(gt_table)
}
```

</details>

## Results

### Article volume 2019-23

<details class="code-fold">
<summary>Code</summary>

``` r
cor_articles <- create_correlation_table(my_df_ind, vars = c("hoad_articles", "scp_first_author_articles", "wos_first_author_articles", 
            "scp_corresponding_author_articles", "wos_corresponding_author_articles"), "Article volume")
create_gt_upper_triangle(cor_articles)
```

</details>

<div id="hsftwgtopg" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>#hsftwgtopg table {
  font-family: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
&#10;#hsftwgtopg thead, #hsftwgtopg tbody, #hsftwgtopg tfoot, #hsftwgtopg tr, #hsftwgtopg td, #hsftwgtopg th {
  border-style: none;
}
&#10;#hsftwgtopg p {
  margin: 0;
  padding: 0;
}
&#10;#hsftwgtopg .gt_table {
  display: table;
  border-collapse: collapse;
  line-height: normal;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 12px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: 100%;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_caption {
  padding-top: 4px;
  padding-bottom: 4px;
}
&#10;#hsftwgtopg .gt_title {
  color: #333333;
  font-size: 16px;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}
&#10;#hsftwgtopg .gt_subtitle {
  color: #333333;
  font-size: 13px;
  font-weight: initial;
  padding-top: 3px;
  padding-bottom: 5px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}
&#10;#hsftwgtopg .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_col_heading {
  color: #333333;
  background-color: #F8F8F8;
  font-size: 100%;
  font-weight: bold;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}
&#10;#hsftwgtopg .gt_column_spanner_outer {
  color: #333333;
  background-color: #F8F8F8;
  font-size: 100%;
  font-weight: bold;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}
&#10;#hsftwgtopg .gt_column_spanner_outer:first-child {
  padding-left: 0;
}
&#10;#hsftwgtopg .gt_column_spanner_outer:last-child {
  padding-right: 0;
}
&#10;#hsftwgtopg .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}
&#10;#hsftwgtopg .gt_spanner_row {
  border-bottom-style: hidden;
}
&#10;#hsftwgtopg .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #F8F8F8;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  text-align: left;
}
&#10;#hsftwgtopg .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #F8F8F8;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}
&#10;#hsftwgtopg .gt_from_md > :first-child {
  margin-top: 0;
}
&#10;#hsftwgtopg .gt_from_md > :last-child {
  margin-bottom: 0;
}
&#10;#hsftwgtopg .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}
&#10;#hsftwgtopg .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#hsftwgtopg .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}
&#10;#hsftwgtopg .gt_row_group_first td {
  border-top-width: 2px;
}
&#10;#hsftwgtopg .gt_row_group_first th {
  border-top-width: 2px;
}
&#10;#hsftwgtopg .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#hsftwgtopg .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_first_summary_row.thick {
  border-top-width: 2px;
}
&#10;#hsftwgtopg .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#hsftwgtopg .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_last_grand_summary_row_top {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: double;
  border-bottom-width: 6px;
  border-bottom-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}
&#10;#hsftwgtopg .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#hsftwgtopg .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}
&#10;#hsftwgtopg .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}
&#10;#hsftwgtopg .gt_left {
  text-align: left;
}
&#10;#hsftwgtopg .gt_center {
  text-align: center;
}
&#10;#hsftwgtopg .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
&#10;#hsftwgtopg .gt_font_normal {
  font-weight: normal;
}
&#10;#hsftwgtopg .gt_font_bold {
  font-weight: bold;
}
&#10;#hsftwgtopg .gt_font_italic {
  font-style: italic;
}
&#10;#hsftwgtopg .gt_super {
  font-size: 65%;
}
&#10;#hsftwgtopg .gt_footnote_marks {
  font-size: 75%;
  vertical-align: 0.4em;
  position: initial;
}
&#10;#hsftwgtopg .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}
&#10;#hsftwgtopg .gt_indent_1 {
  text-indent: 5px;
}
&#10;#hsftwgtopg .gt_indent_2 {
  text-indent: 10px;
}
&#10;#hsftwgtopg .gt_indent_3 {
  text-indent: 15px;
}
&#10;#hsftwgtopg .gt_indent_4 {
  text-indent: 20px;
}
&#10;#hsftwgtopg .gt_indent_5 {
  text-indent: 25px;
}
&#10;#hsftwgtopg .katex-display {
  display: inline-flex !important;
  margin-bottom: 0.75em !important;
}
&#10;#hsftwgtopg div.Reactable > div.rt-table > div.rt-thead > div.rt-tr.rt-tr-group-header > div.rt-th-group:after {
  height: 0px !important;
}
</style>

| Spearman Correlation Matrix - Article volume |  |  |  |  |  |
|----|----|----|----|----|----|
| Variable | Hoad Articles | Scp First Author Articles | Wos First Author Articles | Scp Corresponding Author Articles | Wos Corresponding Author Articles |
| Hoad Articles<span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> - | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.99\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.94\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.99\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.94\*\*\* |
| Scp First Author Articles<span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.99\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> - | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.96\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 1\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.95\*\*\* |
| Wos First Author Articles<span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.94\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.96\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> - | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.95\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 1\*\*\* |
| Scp Corresponding Author Articles<span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.99\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 1\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.95\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> - | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.95\*\*\* |
| Wos Corresponding Author Articles<span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.94\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.95\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 1\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> 0.95\*\*\* | <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1,2,3</sup></span> - |
| <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>1</sup></span> \* p \< 0.05 |  |  |  |  |  |
| <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>2</sup></span> \*\* p \< 0.01 |  |  |  |  |  |
| <span class="gt_footnote_marks" style="white-space:nowrap;font-style:italic;font-weight:normal;line-height:0;"><sup>3</sup></span> \*\*\* p \< 0.001 |  |  |  |  |  |

</div>
