# Tariff Tracker Reference List

*Compiled April 2026 for the US Tariff Analysis — Mexico Competitiveness project.*

This document catalogs the principal online trackers, databases, and reference tools relevant to US tariff analysis, with notes on what each provides and how it relates to the project's analytical needs. Sources are grouped by function: primary data (rates and flows), policy-event timelines, and effective-rate trackers.

---

## A. Primary Data Sources (Statutory Rates, Import Values, Duties Collected)

### 1. USITC DataWeb
**URL:** https://dataweb.usitc.gov  
**Type:** Interactive database + REST API  
**Coverage:** All US imports and exports, 1989–present; queryable by HTS code × country × year/month  
**Key measures:** Import value (CIF), duties collected, dutiable value, quantity; also queryable by import program (USMCA, MFN, etc.) and rate provision code  
**Notes:** Primary source for this project. The raw fields — duties collected and dutiable value — allow direct computation of effective and implied tariff rates as defined in the project instructions. API documented in `DatawebQuery.pdf`. Requires a free account and API token (`DATAWEB_TOKEN`). The most recent data release typically lags by 2–3 months. This is also the underlying data source for the Penn Wharton Budget Model's effective tariff rate estimates.

---

### 2. USITC HTS Portal
**URL:** https://hts.usitc.gov  
**Type:** Statutory rate schedule  
**Coverage:** All 10-digit HTS items; updated with each supplement (several times per year)  
**Key measures:** MFN (general) rate, special program rates (USMCA, CAFTA-DR, GSP, etc.), Column 2 rate  
**Notes:** Authoritative source for statutory rates. Archives of prior editions (CSV, XLS, JSON) are available for historical statutory rate reconstruction. Does *not* include Section 301/232/201 overlay rates — those require Federal Register cross-referencing. For enacted rates on Customs documents, this is the legal authority.

---

### 3. US Census / USA Trade Online
**URL:** https://usatrade.census.gov  
**Type:** Interactive database  
**Coverage:** All US imports and exports, 1989–present; HTS × country × month  
**Key measures:** Import value (customs value and CIF), quantity — does **not** provide duties paid directly  
**Notes:** Familiar source from related projects. Confirmed as the underlying data provider for the IADB Tariff Tracker's effective and implied tariff series (per project instructions). Complementary to DataWeb: DataWeb adds the duties-collected dimension. Useful for import value cross-checks.

---

### 4. USITC Tariff Database (legacy lookup)
**URL:** https://dataweb.usitc.gov/tariff/database  
**Type:** Statutory rate lookup tool  
**Coverage:** HTS-level statutory rates  
**Key measures:** Approximate duty rate by HTS item and country of origin  
**Notes:** Advisory tool for quick statutory rate spot-checks at the HTS line level. For legal rates on Customs documents, defer to hts.usitc.gov. Useful for exploratory classification checks.

---

### 5. CBP Trade Statistics
**URL:** https://trade.cbp.gov  
**Type:** Public-facing summary statistics  
**Coverage:** Aggregate trade and revenue data  
**Key measures:** Duties collected (aggregate, not queryable by HTS); trade volumes by port  
**Notes:** Public summaries from CBP's ACE (Automated Commercial Environment) system. Less granular than DataWeb for analytical work but useful for cross-checking aggregate revenue figures. Backs up PIIE's tariff revenue tracker numbers.

---

## B. Policy-Event Timelines (What Happened and When)

### 6. PIIE: Trump's Trade War Timeline 2.0 (Bown)
**URL:** https://www.piie.com/blogs/realtime-economics/2025/trumps-trade-war-timeline-20-date-guide  
**Type:** Continuously updated narrative timeline  
**Coverage:** Second Trump administration trade actions, January 2025–present; links to first-term timeline for 2017–2021  
**Key measures:** Chronological log of tariff announcements, implementations, pauses, exclusions, and foreign retaliations; links to underlying data  
**Notes:** The single most useful policy-event reference for dating tariff changes. Maintained by Chad Bown at PIIE. Essential for constructing event-study windows around specific Section 301/232/201 actions. The first-term version (2017–2021) is separately maintained and covers the tariff actions most relevant to the 2017–2025 analytical window in this project.

---

### 7. Trade Compliance Resource Hub: Trump 2.0 Tariff Tracker
**URL:** https://www.tradecomplianceresourcehub.com/2026/04/19/trump-2-0-tariff-tracker/  
**Type:** Practitioner-oriented timeline and legal tracker  
**Coverage:** Second Trump administration, January 2025–present; includes Federal Register notices, legal challenges, and HTS code-level implementation details  
**Key measures:** Specific HTSUS codes affected by each action; Federal Register citations; Section 232 inclusion/exclusion process dates  
**Notes:** More granular on the legal and HTS implementation details than PIIE's timeline. Particularly useful for tracking Section 232 derivative product expansions and Section 301 exclusion renewals, which affect specific HTS subheadings rather than broad product groups.

---

### 8. Congress.gov / CRS: Presidential 2025 Tariff Actions
**URL:** https://www.congress.gov/crs-product/R48549  
**Type:** Congressional Research Service report (periodically updated)  
**Coverage:** All presidential tariff actions January 20–December 31, 2025  
**Key measures:** Tabular summary of each action by legal authority (IEEPA, Section 232, Section 301), status, and timeline; also covers foreign retaliatory actions  
**Notes:** Authoritative, non-partisan government source. Five tables cover IEEPA actions, Section 232 actions, bilateral framework agreements, and foreign retaliation. Useful for legal status tracking, especially given the Supreme Court's February 2026 ruling striking down IEEPA tariffs and the ongoing Section 122 transition.

---

## C. Effective Tariff Rate Trackers (Computed from Actual Data)

### 9. PIIE: Tariff Revenue Tracker (Hufbauer & Zhang)
**URL:** https://www.piie.com/research/piie-charts/2025/trumps-tariff-revenue-tracker-how-much-us-collecting-which-imports-are  
**Type:** Monthly chart tracker  
**Coverage:** US imports overall, by broad product category, and by country; January 2025–present  
**Key measures:** Effective tariff rate = (monthly duties collected) / (monthly import value), by category and by country; tariff revenue in dollars  
**Notes:** Operationally defines effective tariff rate exactly as this project does. Data sourced from USITC DataWeb. Updated monthly. Provides the product-category and country-level breakdown (Figure 1 and Figure 2) that directly parallels this project's HTS × country unit of analysis. Best for benchmarking effective rates against independently computed DataWeb figures.

---

### 10. Penn Wharton Budget Model: Effective Tariff Rates and Revenues
**URL:** https://budgetmodel.wharton.upenn.edu/p/2026-04-15-effective-tariff-rates-and-revenues-updated-april-15-2026/  
**Type:** Monthly econometric tracker (most recent update: April 15, 2026)  
**Coverage:** All US imports; major trading partners; broad product categories; January 2022–present  
**Key measures:** Observed average effective tariff rate (duties/import value); pre-substitution counterfactual rate; USMCA utilization rate for Canada and Mexico; tariff revenue  
**Notes:** Methodologically sophisticated — distinguishes between observed ETR and a counterfactual that strips out behavioral responses (import substitution). Uses USITC DataWeb as primary source. The USMCA utilization series (Figure 4) is directly relevant to Mexico's competitive position: it shows the share of Mexican imports claiming USMCA duty-free treatment surging to ~86% by February 2026. Data downloadable. Updated roughly monthly after USITC DataWeb releases.

---

### 11. The Budget Lab at Yale: Tariff Rate Tracker
**URL:** https://budgetlab.yale.edu/research/introducing-tariff-rate-tracker-open-source-tool-daily-effective-tariff-rates  
**Type:** Open-source daily ETR tool  
**Coverage:** ~20,000 HS10 products × 240 trading partners; daily rates, January 1, 2025–present  
**Key measures:** Daily statutory effective tariff rate by product × country; decomposed by tariff authority (Section 301, 232, IEEPA/Section 122, fentanyl surcharges); stacking rules modeled explicitly  
**Notes:** The most granular and transparent statutory ETR tool available. Open-source (GitHub); all code and modeling assumptions are public. Crucially, it handles tariff stacking rules — which authorities stack vs. are mutually exclusive — a problem that is highly relevant for Mexico (USMCA exemptions interact with Section 232 and the new Section 122 global tariff). Incorporates HTS revisions as they are published. Useful for constructing daily rate series for event-study analysis.

---

### 12. Center for Global Development: US Tariff Tracker
**URL:** https://www.cgdev.org/media/us-tariff-tracker-measuring-effective-tariff-rates  
**Type:** Country-level ETR tracker (periodically updated)  
**Coverage:** All US trading partners; country-level aggregate ETRs; 2024–present  
**Key measures:** Estimated effective tariff rate by country, weighted by 2024 import composition; breakdown by tariff category (reciprocal/IEEPA, sector-specific, exemptions)  
**Notes:** Particularly useful for a global competitive comparison — it computes a single ETR for each country that summarizes all applicable tariff actions. Uses 2024 US Census import data as trade weights. Most recent update covers tariff actions through early August 2025. Less granular than DataWeb at the HTS level, but good for quickly comparing Mexico's position against all competitor countries simultaneously.

---

### 13. Tax Policy Center: TPC Tariff Tracker
**URL:** https://taxpolicycenter.org/features/tracking-trump-tariffs  
**Type:** Revenue and distributional tracker  
**Coverage:** All Trump 2.0 tariff actions through December 4, 2025  
**Key measures:** Projected tariff revenue (10-year); average household tax burden by income quintile; ETR by country (Figure 2); tariff category breakdown  
**Notes:** Strong on distributional and revenue modeling. The country-level ETR chart (Figure 2) provides a cross-check. TPC collaborated with the Budget Lab at Yale to validate early ETR estimates. Less useful for HTS-level analysis but valuable for understanding the aggregate fiscal context of the tariff regime. Notes that the Supreme Court's February 2026 IEEPA ruling altered the tariff landscape substantially.

---

## D. US-China Specific Trackers

### 14. PIIE: US-China Trade War Tariffs Chart (Bown)
**URL:** https://www.piie.com/research/piie-charts/2019/us-china-trade-war-tariffs-date-chart  
**Type:** Chart tracker, updated periodically (last update: November 14, 2025)  
**Coverage:** US–China bilateral, 2018–present  
**Key measures:** Average US tariff on Chinese exports; average Chinese tariff on US exports; % of bilateral trade covered  
**Notes:** The reference chart for US-China tariff war chronology. Currently shows average US tariff on Chinese goods at 47.5%, covering 100% of Chinese exports. Covers Section 301 and IEEPA actions. Does **not** include AD/CVD. Underlying data downloadable as xlsx. Essential background for understanding why China faces a radically different tariff environment from Mexico, which is the comparative backdrop for assessing Mexico's competitive gain.

---

## E. Statutory and Reference Tools

### 15. USTR Section 301 Docket / Federal Register
**URL:** https://ustr.gov/issue-areas/enforcement/section-301-investigations  
**Type:** Official regulatory source  
**Coverage:** Section 301 tariff lists (Lists 1–4B on Chinese goods), exclusion processes, extensions  
**Key measures:** Specific HTS codes covered by each Section 301 list; rates; exclusion expiration dates  
**Notes:** Required for any analysis of Section 301 applicability at the HTS subheading level. Section 301 exclusions — granted to specific HTS codes or product descriptions — are frequently extended, allowed to expire, or reinstated, creating variation in effective rates across time and importer. The DataWeb `dataToReport` fields implicitly capture whether Section 301 was paid, but the USTR docket is needed to understand which lines are theoretically exposed.

---

### 16. Observatory of Economic Complexity (OEC)
**URL:** https://oec.world  
**Type:** Trade data visualization and analytics platform  
**Coverage:** Global bilateral trade flows, 1962–present; HS classification  
**Key measures:** Export and import values by country × HS product; market share; trade complexity indices  
**Notes:** As specified in the project instructions, the OEC is used to identify principal exporting competitors for each HTS Heading or Subheading under analysis. For a given product line, a quick OEC query reveals which countries compete with Mexico in the US import market, allowing dynamic competitor identification before pulling DataWeb data for those countries.

---

## F. Methodology Benchmark

### 17. IADB Tariff Tracker (Angel Espinoza)
**URL:** https://angelespinozae.github.io/tariff-tracker.html  
**Type:** Research tracker / preliminary working tool (hosted on personal GitHub Pages)  
**Coverage:** US imports by country and HTS; effective and implied tariff series  
**Key measures:** Effective tariff rate (duties paid / import value); implied tariff rate (dutiable value / import value); underlying source is the US Census Bureau  
**Notes:** This is the **methodology benchmark** for this project, as specified in the project instructions. The definitions of effective and implied tariff adopted here match Espinoza's exactly. The tracker appears to be a preliminary or working version — it is not linked from the main IADB institutional website, which explains why it is difficult to locate. Hosted at a personal GitHub Pages address (`angelespinozae.github.io`) rather than on an IADB domain. Should be used to validate Phase 1 DataWeb query results against independently computed figures for the same HTS × country × year cell.

---

## G. Notes on Coverage Gaps

Several gaps are worth flagging for the project:

1. **AD/CVD data** is not covered by any of the trackers above in a queryable form. The Commerce Department's antidumping and countervailing duty order database is at https://access.trade.gov. AD/CVD rates vary by *specific foreign producer*, not just country, and the gap between assessed and collected AD/CVD (particularly for Chinese exporters) is a known analytical problem documented in `Tariff_layers.md`.

2. **The IADB Tariff Tracker (Espinoza)** — now located; see entry 17 above. Note that the tracker appears to be a preliminary/working version hosted on a personal GitHub Pages site rather than on the IADB institutional domain, which explains why it is difficult to find through normal IADB navigation.

3. **Zonos US Import Tariff Tracker** (https://zonos.com/docs/guides/us-tariff-changes) provides a practitioner-oriented timeline focused on e-commerce and de minimis policy. Less relevant for HTS-level analytical work but useful for tracking real-time policy announcements.

---

*Last updated: April 2026*