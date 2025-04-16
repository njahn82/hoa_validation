## Data and source code supplement &mdash; Estimating transformative agreement impact on hybrid open access: A comparative large-scale study using Scopus, Web of Science and open metadata

### Overview

This repository contains the data and source code used for the manuscript:

Jahn, N. (2025). Estimating transformative agreement impact on hybrid open access: A comparative large-scale study using Scopus, Web of Science and open metadata. arxiv: tbc.

This repository is structured as a [research compendium](https://doi.org/10.7287/peerj.preprints.3192v2). 

A research compendium contains data, code, and text associated with it. 

## Repository Structure


- The [Quarto](https://quarto.org/) files in the [`analysis/`](analysis/) directory provide details about the data analysis, including underlying analytical code including figures and statistical correlation tests for the submitted manuscript. 
- The [`data/`](data/) directory contains aggregated data used. 
- The [`data-raw/`](data-raw/) directory provides R scripts used to gather raw data from external sources, in particular from the [Kompetenznetzwerk Bibliometrie (KB)](https://bibliometrie.info/) and the [SUB Göttingen Open Scholarly Data Warehouse](https://subugoe.github.io/scholcomm_analytics/data.html) hosted on Google BigQuery.

### Analysis Files

The [`analysis/`](analysis/) directory contains the manuscript written as dynamic Quarto document with embedded R code, executed with [knitr](https://yihui.org/knitr/):

- **Main manuscript** :[`analysis/manuscript.qmd`](analysis/manuscript.qmd)

The Quarto is rendered to a Latex document, following the APA 6 style guide.

- **Rendered PDF:** The rendered version is [`analysis/manuscript.pdf`](analysis/manuscript.pdf).

- **Supplementary correlation tests:** The folder also contains a supplement with the correlation tests. Rendered version [`analysis/cor_tables.md`](analysis/cor_tables.md), Quarto document: [`analysis/cor_tables.qmd`](analysis/cor_tables.qmd)

To speed up compilation, some data analytics steps were pre-computed using [`analysis/manuscript_preprocessing_data.R`](analysis/manuscript_preprocessing_data.R).

### Data files

#### Aggregated data

The [`data`](data) folder contains aggregated data sets used for the manuscript's data analysis. See [`data/README.md`](data/README.md) for an overview.

#### Data retrieval

The [`data-raw`](data-raw) folder contains analytical steps for obtaining the data. 

-  [`data-raw/data_gathering.R`](data-raw/data_gathering.R) provides the source code used to obtain data from the Scopus and Web of Science KB in-house databases. The resulting datasets are safeguarded in the KB data infrastructure.
- [`data-raw/indicators.R`](data-raw/indicators.R) comprises the generation of the aggregated datasets. For performance reasons, the calculation was carried out using Google BigQuery.

Data and source code used to generate hoaddata, v0.3., can be found on GitHub: <https://github.com/subugoe/hoaddata/releases/tag/v.0.3>

### Reproducibility notes

Scopus and Web of Science are proprietary data and can be openly shared within the KB. To improve reproducibility, safeguarded versions were used (see <https://zenodo.org/records/13935407> for comprehensive description). 

However, data analytics including figures reported in the manuscript can be re-generated using Quarto and R. Please load the correpsonding renv environment before re-generatign the manuscript.

### License

The manuscript is made available under the [CC-BY 4.0 license](https://creativecommons.org/licenses/by/4.0/).

### Funding

This work is supported by the Federal Ministry of Education and Research of Germany (BMBF), grants 16WIK2301E / 16WIK2101F.

The proprietary bibliometric data from Scopus and Web of Science was provided by the German Competence Network for Bibliometrics, BMBF grant 16WIK2101A. 

### Contact

Najko Jahn [najko.jahn@sub.uni-goettingen.de](mailto:najko.jahn@sub.uni-goettingen.de)