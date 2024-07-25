## Motivation

Throughout this thesis, I use open data to examine hybrid open access. 
For instance, in my most recent paper, Crossref was used to determine hybrid journal publication volume and open access.
OpenAlex was used to obtain the country affiliation of the first authors of these publications.
To analyse the prevalence of articles published under transformative agreements, information about participating institutions according to the Journal Checker Tool (JCT) and first auhtor affiliation data from OpenAlex were macthed using the ROR-ID.

{hoaddata} ships data along with the code, unit testing suite and documentation.

 Two questions arise concerning the representation and validity of the open scholarly metadata used:

1. Are open data sources suitable to measure transformative agreements? More specifically, fo analyses based on {hoaddata} yield comparable results compared to WoS and Scopus? (see RQ2 in https://arxiv.org/pdf/2404.17663)

- Article volume 
	- Issue: document type definitions differ
- Country affiliations (first and corresponding authors)
	- Issue: corresponding authors detection in OpenAlex not widely implemented (test)
- Affiliation with eligible institutions
	- Issue: WoS and Scopus do not support ROR, need to be matched
- Open Access evidence
	- Comparison with publisher-provided data in Crossref

WHat to measure:

Shared corpus: Intersection of all three databases (stipulate Web of Science and Scopus as gold standard to study the correctness of information provided)
Inclusivity: What is in Crossref/OpenAlex, which is not indexed in Web Of Science or Scopus
Gap analyses: Added information of Web of Science and Scopus (likely due to corresponding auhtor data including affiliation)


Potential levels of analyses

1) Publisher portfolios.

- Following Jahn 2024: Big 3 (Elsevier, Wiley and Springer), Other.

2) Journals

- Influenced by publisher!


Five-years period 2019 - 2023! We must be carfeul beacause of Corona!







