# Project Instructions: US Tariff Analysis — Mexico Competitiveness

*Working document for Claude — last updated April 2026*

---

## 1. Purpose and Research Question

This project tracks how US tariffs — particularly those introduced or escalated during the Trump administrations — have affected Mexico's competitive position relative to other exporters to the United States. The analysis covers the period 2017 to 2025, spanning the pre-Trump baseline, the first Trump administration tariff actions (Section 301, 232, 201), the Biden-era continuations and modifications, and the second Trump administration.

The goal is to move beyond qualitative statements such as "Mexico's position in auto parts has improved" to precise, quantitative comparisons: by how much, relative to which competitors, and for which specific HS lines.

A parallel project is identifying the most important product categories within US imports from Mexico, working down from HS Chapters to Headings (4-digit) and, where warranted, to the most important Subheadings (6-digit). The tariff analysis in this project will be applied to those priority product lines once they are identified.

---

## 2. Key Definitions

This project adopts the definitions used by the IADB Tariff Tracker (Espinoza):

- **Statutory tariff:** The rate specified in the HTS schedule. Source: Federal Register and USTR published schedules. Already complex because a single 10-digit HTS can carry an MFN rate, special program rates (USMCA, CAFTA, GSP), a Column 2 rate, and stacked Section 301/232/201 rates.

- **Effective tariff:** Duties paid divided by total import value. This is the primary measure of actual tariff burden and is the one most useful for competitive analysis. Source: US Census Bureau.

- **Implied tariff:** Dutiable value divided by total import value. Measures the share of imports that actually face the tariff (i.e., are not duty-free under a special program). Useful for diagnosing how much of the trade is sheltered by exemptions. Source: US Census Bureau.

> **Note on the gap between statutory and effective rates:** This gap is where the analytically interesting material lives. It reflects special trade programs (USMCA, CAFTA, GSP), AD/CVD orders, Section 301/232/201 exclusions, and compliance/enforcement variation. The `Tariff_layers.md` file in this project provides a detailed taxonomy of these layers.

---

## 3. Data Sources

### 3.1 Primary: USITC DataWeb

DataWeb (`dataweb.usitc.gov`) is the primary extraction tool. It provides import values, quantities, and duties collected, queryable by HTS code, country of origin, year, import program, and rate provision code. The DataWeb API allows programmatic access; documentation is in `DatawebQuery.pdf` in this project.

**Authentication:** An API token is required, generated from the API tab within a DataWeb account. The token is stored as an environment variable (`DATAWEB_TOKEN`) and never hard-coded.

All R code uses `httr2` (preferred) for HTTP calls. The `DatawebQuery.pdf` examples are in Python; translate all patterns to R.

**Key fields to retrieve:** import value (CIF), duties collected, dutiable value, quantity. The exact field names available in the API must be verified empirically in the first exploratory query.

### 3.2 Supporting: US Census / USA Trade

Census/USA Trade is a familiar source already used in related projects. It provides import values but not duties paid directly. Relevant Census queries from prior work are uploaded to this project's Files section for reference.

### 3.3 Reference: IADB Tariff Tracker

The IADB Tariff Tracker (Angel Espinoza) provides statutory, effective, and implied tariff series for benchmarking and methodology validation. Link is stored in project Files. Their source for effective and implied tariffs is the US Census Bureau, which confirms Census as the underlying data provider.

### 3.4 For Statutory Rates: USITC HTS Portal and Federal Register

Statutory rates by HTS code are available from the USITC HTS Portal (`hts.usitc.gov`). Section 301, 232, and 201 tariff layers require cross-referencing Federal Register notices and USTR schedules. This is a secondary activity — the DataWeb effective tariff computation implicitly captures the statutory rate net of exemptions.

### 3.5 For Competitor Identification: OEC

The Observatory of Economic Complexity (`oec.world`) is used to identify the principal exporting countries for each HTS Heading or Subheading of interest. Competitors vary by product; the relevant set is determined dynamically for each tariff line rather than fixed in advance.

---

## 4. Analytical Approach

### 4.1 Unit of Analysis

The fundamental unit is the triple: **HTS code × country of origin × year**. The target output is a tidy data frame (or set of data frames) with columns for HTS code, country, year, import value, duties collected, dutiable value, effective tariff rate, and implied tariff rate. Additional columns for statutory rate may be added later.

### 4.2 HTS Aggregation Levels

Analysis may be conducted at different levels of the HTS hierarchy:

- **Chapter (2-digit):** Broad sectoral overview.
- **Heading (4-digit):** Primary working level, consistent with the product identification work in the parallel project.
- **Subheading (6-digit) or HTS line (8/10-digit):** Used when a Heading is too heterogeneous and the most important Subheading needs to be isolated.

### 4.3 Time Period

2017 to 2025. The year 2017 serves as the pre-Trump-tariff baseline. Annual data is the default aggregation; monthly data may be used for event-study analysis around specific tariff announcements.

### 4.4 Computed Measures

For each HTS × country × year cell:

```
effective_tariff_rate = duties_collected_usd / import_value_usd
implied_tariff_rate   = dutiable_value_usd  / import_value_usd
```

These rates are computed in R from raw DataWeb extracts, not taken directly from a pre-computed source. This allows verification and custom aggregation.

---

## 5. Phased Workflow

### 5.1 Phase 1 — Exploratory single query *(current phase)*

- Authenticate with DataWeb API using R (`httr2`).
- Submit a minimal query for a single HTS Heading, a single country, and a single year. The specific HTS line and test country/year will be specified by the user before coding begins.
- Parse the JSON response; identify which measures are exposed (import value, duties, dutiable value).
- Validate against the IADB Tariff Tracker for the same line/country/year.

### 5.2 Phase 2 — Expand to full country × year panel

- For a given HTS line, retrieve all relevant competitor countries (identified via OEC) for 2017–2025.
- Build the tidy data frame. Compute effective and implied tariff rates.

### 5.3 Phase 3 — Multi-product analysis

- Apply the Phase 2 workflow to the priority HTS Headings identified in the parallel product-importance project.
- Produce comparative summaries: Mexico vs. each major competitor, by Heading, by year.

---

## 6. Code and File Conventions

- **Language:** R exclusively. Use `httr2` for HTTP, `jsonlite` for JSON parsing, `dplyr`/`tidyr` for data manipulation.
- **API token:** stored as environment variable `DATAWEB_TOKEN`; retrieved with `Sys.getenv("DATAWEB_TOKEN")`.
- **Output:** tidy data frames saved as `.rds` and/or `.csv`. Column names in `snake_case`:

| Column | Description |
|---|---|
| `hts_code` | HTS code at the relevant digit level |
| `country_iso3` | ISO 3-letter country code |
| `year` | Calendar year |
| `import_value_usd` | Total import value (CIF), USD |
| `duties_collected_usd` | Duties collected, USD |
| `dutiable_value_usd` | Dutiable value, USD |
| `effective_tariff_rate` | duties_collected / import_value |
| `implied_tariff_rate` | dutiable_value / import_value |

- **Build incrementally:** start with one HTS × one country × one year, validate, then expand. Do not attempt to pull all data at once before the query structure is confirmed.

---

## 7. Key Files in This Project

| File | Purpose |
|---|---|
| `Tariff_layers.md` | Taxonomy of tariff layers — essential background |
| `DatawebQuery.pdf` | USITC DataWeb API documentation (Python; translate to R) |
| IADB Tariff Tracker link | Definitions and validation benchmarks |
| Census query files | Prior Census/USA Trade queries from related projects |

---

## 8. Open Questions to Resolve in Phase 1

1. Does DataWeb expose duties collected and dutiable value directly, or only import value? If not, is there a Census API endpoint that provides these?
2. What is the exact `dataToReport` field name for duties collected in the DataWeb query JSON?
3. Can DataWeb return data broken out by import program (USMCA, MFN, etc.) to allow separation of duty-free from duty-paying shipments?
4. Which specific HTS Heading and which test country/year will be used for the Phase 1 validation query? *(To be specified by user before coding begins.)*