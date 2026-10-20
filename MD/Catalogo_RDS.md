# Data catalog: `RDS/` folder (NSMX)

Snapshot taken 2026-10-19, before the reorganization of the repository. Purpose: a reference to rewind to if files are moved or renamed.

**How it was built.** Every `.rds` in `RDS/` was opened and inspected (class, dimensions, columns, ranges). Sources and producers come from the `saveRDS()` calls in `Scripts/` (and in the Quarto/Rmd files for files no script writes). `RDS/raw/` was inventoried by name and size only; its files were not opened.

**Conventions seen across files**
- `fecha` = first day of the month (monthly series) or of the quarter (quarterly series).
- Census/USITC values are in current US dollars. `Val_mes` is the monthly value (`GEN_VAL_MO`). `Val_acum` is the year-to-date cumulative value (`GEN_VAL_YR`).
- Census country codes: Mexico = 2010, Vietnam = 5520, Taiwán = 5830.
- `meta_*.rds` are provenance lists (source, endpoint, download date, notes) that accompany a data file.
- Counts: `RDS/` has 53 files plus the `raw/` subfolder. Of the 53 files, 50 are catalogued `.rds`, 1 has no extension (`impMex_sec_pct`), 1 is `.gitkeep`, and 1 is a formatted-table object deliberately left out of this catalog. `raw/` holds 67 `.rds` files (160 MB).
- Section L lists files that the scripts write but that are **not on disk today**; re-run the named script to regenerate them.
- Hand-downloaded inputs in `Excel/` are listed in section 5.

---

## 1. Summary table

| File | Size | Rows × cols | Content (one line) | Source | Producer |
|---|---|---|---|---|---|
| **A. US imports by country (Census)** | | | | | |
| `imp_por_pais.rds` | 28 KB | 4,224 × 7 | Monthly US imports: Total, Top 20 origin countries, "Resto" | Census Intl Trade API | Query1 |
| `imp_por_pais_all.rds` | 246 KB | 44,371 × 7 | Monthly US imports for all 235 origin codes; `País` filled only for top 20 | Census Intl Trade API | Query1 |
| `meta_imp_por_pais.rds` | 0.5 KB | list (6) | Provenance for the two files above | | Query1 |
| `impPais_Perc.rds` | 5 KB | 336 × 5 | Annual import value and share by country, 2010–2025, 21 countries | derived from `imp_por_pais` | Quarto chunk (see §3) |
| **B. US imports from Mexico by HS (Census)** | | | | | |
| `imp_mex_sec_cap.rds` | 336 KB | 18,791 × 12 | Monthly imports from Mexico, Sección (21) × Capítulo (98), with a seasonally adjusted value | Census Intl Trade API | Query2 |
| `meta_imp_mex_sec_cap.rds` | 0.7 KB | list (8) | Provenance | | Query2 |
| `raw_df.rds` | 45 MB | 2,443,910 × 6 | Raw monthly imports from Mexico, all HS levels, 2010-01 to 2025-12 | Census Intl Trade API | Query3 |
| `USallImpMex.rds` | 45 MB | 2,443,910 × 6 | **Byte-identical copy of `raw_df.rds`** (same MD5) | Census Intl Trade API | Query3 |
| `imp_mex_hs4.rds` | 7.5 MB | 198,680 × 11 | Monthly imports from Mexico, all HS4 partidas, labeled | derived from `raw_df` | Query3 |
| `imp_mex_hs6.rds` | 18.6 MB | 651,943 × 12 | Monthly imports from Mexico, all HS6 subpartidas, labeled | derived from `raw_df` | Query3 |
| `imp_mex_hs4_84858790.rds` | 386 KB | 33,226 × 11 | HS4 subset: Capítulos 84, 85, 87, 90 | derived | Query3 |
| `imp_mex_hs6_84858790.rds` | 4.1 MB | 153,458 × 12 | HS6 subset: Capítulos 84, 85, 87, 90 | derived | Query3 |
| `imp_mex_top_hs4.rds` | 77 KB | 5,568 × 13 | Monthly series for the 29 selected top HS4 partidas within Caps. 84/85/87/90, with short names | derived | Query3 |
| `TCAC_y_shares_84858790.rds` | 4 KB | 33 × 14 | Per-partida values (2010, 2018, 2024, 2025), TCAC and shares, with "Resto" rows | derived | Query3 |
| `meta_TCAC_y_shares.rds` | 0.7 KB | list (10) | Definitions of the TCAC and share columns | | Query3 |
| `meta_query3.rds` | 0.9 KB | list (12) | Provenance for the Query3 outputs | | Query3 |
| `raw/raw_hs6_2010…2025.rds` | 16 files | | Per-year API responses cached by Query3 | Census Intl Trade API | Query3 |
| **C. Top partidas, curated lists** | | | | | |
| `partidas_valor_depurado.rds` | 4 KB | 30 × 7 | Top 30 HS4 partidas by 2024–2025 value after cleaning, with Spanish names | derived from `imp_mex_hs4` | Query10 |
| `decomp_jerarquica_2025.rds` | 1 KB | 17 × 7 | 2025 hierarchical decomposition (Total → Sección → Capítulo → Partida) | derived | **producer not found** |
| `datos_847150_hs6.rds` | 4.6 KB | 309 × 9 | Monthly imports of HS6 847150 (digital processing units) from MX/VN/TW, 2018-01 to 2026-07 | Census Intl Trade API | **producer not found** (read by C3 qmd) |
| **D. Mexico vs Vietnam vs Taiwán (Census)** | | | | | |
| `raw_df_mex_vnm_twn.rds` | 115 MB | 6,091,012 × 8 | Raw monthly imports from MX, VN, TW, all HS levels, 2010-01 to 2026-07 | Census Intl Trade API | Query11 |
| `imp_competidores_hs4.rds` | 19.6 MB | 516,483 × 12 | Monthly HS4 imports from MX, VN, TW, labeled | derived | Query11 |
| `meta_query11.rds` | 0.9 KB | list (10) | Provenance | | Query11 |
| `listas_finales_NS_mex_vnm_twn.rds` | 5 KB | 94 × 6 | Final lists of nearshoring-relevant partidas per country, with 2024–25 value | derived | Query12 |
| `tabla_competencia_mex_vnm_twn.rds` | 5 KB | 58 × 8 | Union of the three lists, value by country (NA if not on the country's list) | derived | Query12 |
| `tabla_overlap_mex_vnm_twn.rds` | 4 KB | 24 × 10 | Partidas in Caps. 84–90 where Mexico overlaps with VN and/or TW, with Spanish names | derived | Query12 |
| `meta_query12.rds` | 1 KB | list (7) | Method notes (volume threshold, excluded categories) | | Query12 |
| `raw/raw_hs_{2010,5520,5830}_YYYY.rds` | 51 files | | Per-country, per-year API cache (2010–2025 + 2026 Jan–Jul) | Census Intl Trade API | Query11 |
| **E. Tariffs** | | | | | |
| `aranceles_hts8703_mex_kor_mensual.rds` | 12 KB | 384 × 8 | Monthly import value, dutiable value, duties and effective/implicit rates, HTS 8703 (cars), Mexico vs South Korea, 2010-01 to 2025-12 | USITC DataWeb API | Query4 |
| `usitc_prueba_cruda.rds` | 0.5 KB | list (1) | Raw test response from the DataWeb API (a list with one element `dto`) | USITC DataWeb API | test run, **producer not found** |
| **F. Mexican exports by state (INEGI)** | | | | | |
| `xmex_total_ef.rds` | 11 KB | 2,432 × 6 | Quarterly total exports by state (32), 2007Q1–2025Q4, thousand USD | INEGI BIE (ETEF) | Query5 |
| `meta_xmex_total_ef.rds` | 1 KB | list (13) | Provenance (BIE indicator 6207095692) | | Query5 |
| `etef_tidy.rds` | 188 KB | 68,096 × 11 | Quarterly exports by state × SCIAN sector (27 codes), with flags for suppressed or n/a cells | INEGI ETEF Excel | Query6 |
| `meta_etef.rds` | 0.9 KB | list (12) | Provenance and flag definitions | | Query6 |
| `supresion_ns_wide.rds` | 0.6 KB | 25 × 5 | By state, suppression statistic for SCIAN 333, 334, 335, 336 | derived from ETEF | Query6 |
| **G. IMMEX employment (INEGI)** | | | | | |
| `immex_empleo.rds` | 77 KB | 3,686 × 15 | Monthly IMMEX (manufacturing) establishments and employment: 17 states + ZLF + national total | INEGI IMMEX open data | Query7 |
| `immex_empleo_ef.rds` | 62 KB | 3,104 × 15 | Same variables, 16 states only | derived from `immex_empleo` | **producer not found** |
| `immex_empleo_zlfn.rds` | 5 KB | 194 × 11 | Same variables, ZLFN aggregate only | derived from `immex_empleo` | **producer not found** |
| `meta_immex_empleo.rds` | 1 KB | list (10) | Provenance and variable definitions | | Query7 |
| **H. Foreign direct investment (Secretaría de Economía)** | | | | | |
| `ied_por_origen.rds` | 44 KB | 12,166 × 5 | Quarterly FDI flows by origin country (154) | SE Excel `IED_flujos.xlsx` | Query8 |
| `ied_por_actividad.rds` | 194 KB | 31,363 × 7 | Quarterly FDI flows by SCIAN activity (396 codes; total/sector/subsector/rama) | SE Excel `IED_flujos.xlsx` | Query8 |
| `ied_flujos_tipo.rds` | 3 KB | 316 × 5 | Quarterly FDI flows by type (new investment, reinvested earnings, intercompany accounts, total) | SE Excel `IED_flujos.xlsx` | Query8 |
| `ied_pib.rds` | 4 KB | 135 × 7 | FDI, GDP and FDI/GDP %, annual + quarterly, 1999–2025 | SE Excel `IED_PIB_6.xlsx` | Query8 |
| `ied_fbkf.rds` | 4 KB | 135 × 7 | FDI, gross fixed capital formation and FDI/GFCF %, annual + quarterly | SE Excel `IED_FBKF_7.xlsx` | Query8 |
| `meta_ied.rds` | 0.6 KB | list (8) | Provenance | | Query8 |
| `ied_pib_wdi_comp.rds` | 1 KB | 63 × 3 | FDI/GDP % for Mexico, Costa Rica, Dominican Republic, Vietnam, 2010–2025 | World Bank WDI | Quarto/Rmd chunk (see §3) |
| **I. Media and attention to nearshoring** | | | | | |
| `gdelt_nearshoring_mx.rds` | 0.6 KB | 74 × 4 | Monthly count of GDELT articles on "nearshoring" located in Mexico, 2018-03 to 2026-06 | GDELT GKG v2 via BigQuery | Query9_Media |
| `meta_gdelt_nearshoring_mx.rds` | 0.5 KB | list (7) | Provenance and method | | Query9_Media |
| `media_cloud_raw.rds` | 31 KB | 2,954 × 4 | Daily mentions of "nearshoring Mexico", 2018-05-10 to 2026-06-10 | Media Cloud (CSV export) | Query9_NS_MentionsMX |
| `media_cloud_mensual.rds` | 1.6 KB | 98 × 4 | Monthly aggregation (mentions, total, ratio) | derived from `media_cloud_raw` | Query9_NS_MentionsMX |
| `meta_media_cloud.rds` | 0.3 KB | 1 × 7 | Provenance | | Query9_NS_MentionsMX |
| **J. Reference** | | | | | |
| `hs_dictionary.rds` | 15 KB | 299 × 5 | HS dictionary: 21 Secciones, 96 Capítulos, 182 Partidas (Caps. 84, 85, 87, 90 only), with parent code, short name, official Spanish name | WCO Trade Tools HS 2022 / NALADISA 2022 | `build_hs_dictionary.R` |
| **K. Unsorted: no producer script** | | | | | |
| `impMex_sec_pct` (no extension) | 5.7 KB | 336 × 6 | Annual import value and share by Sección, 2010–2025 | derived from `imp_mex_sec_cap` | Quarto (see §3) |
| **L. Written by scripts, NOT on disk today** | | | | | |
| `etef_raw.rds` | – | not on disk | ETEF Excel sheets stacked in long format before classification, with the raw value (`val_raw`), the `suprimido` flag and total/unspecified flags; `etef_tidy` is derived from it | INEGI ETEF Excel | Query6 |
| `etef_supresion_check.rds` | – | not on disk | Per state × SCIAN subsector: `n_obs`, `n_suprimidos`, `pct_C` (% of quarterly cells suppressed) | derived from `etef_raw` | Query6 |
| `mediacloud_nearshoring_mx.rds` | – | not on disk | Monthly Media Cloud story counts mentioning "nearshoring" in the Mexico National collection (id 34412427): `fecha, n_articulos, n_total, año, mes, pct`; 2018-01 to 2026-05 | Media Cloud API | Query9_Media |
| `meta_mediacloud_nearshoring_mx.rds` | – | not on disk | Provenance for the file above (collection, 647 sources, definition of `n_articulos` and `pct`) | | Query9_Media |
| `meta_aranceles_hts8703.rds` | – | not on disk | Provenance for the tariff file: USITC DataWeb endpoint, HTS 8703, Mexico (2010) and South Korea (5800), variable mapping, definitions of effective and implicit rates | | Query4 |

---

## 2. Detail by group

### A. US imports by origin country (Query1)
- Source: US Census Bureau International Trade API, `timeseries/intltrade/imports/hs`. Downloaded 2026-04-20. Period 2010-01 to 2025-12.
- **`imp_por_pais.rds`**: `fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo`. `grupo` is Total / Top20 / Resto. The top 20 countries are ranked by cumulative value Jan 2024 – Nov 2025 (from `meta_imp_por_pais`). `CTY_CODE = "TOT"` is the Total row. Never sum countries to get the total (see `data-sources` notes on regional aggregates).
- **`imp_por_pais_all.rds`**: `fecha, CTY_CODE, CTY_NAME, Imp_mes, País, rank, Imp_total`. 235 codes. `País` and `rank` are NA outside the top 20 (40,531 NA ranks).
- **`impPais_Perc.rds`**: `año, País, rank, Imp_anual, share`. 21 countries × 16 years. Annual totals and share of US imports. It feeds the diverging-bar charts (`Rec_Diverging_Bars.R`).

### B. US imports from Mexico by HS (Query2, Query3)
- Source: Census Intl Trade API, Mexico (`CTY_CODE = 2010`). Query2 downloaded 2026-04-19, Query3 on 2026-04-29. Period 2010-01 to 2025-12.
- **`imp_mex_sec_cap.rds`**: `fecha, Sección (ordered I–XXI), Sección_corto, Sección_desc_es, Sección_desc_orig, Capítulo (1–99), Cap_corto, Cap_desc_es, Cap_desc_api, Val_mes, Val_acum, Val_mes_sa`. `Val_mes_sa` is a seasonally adjusted monthly value (X-13, `sa_adj()` in `funciones.R`). Sección is derived by grouping capítulos.
- **`raw_df.rds` / `USallImpMex.rds`**: `time ("YYYY-MM"), I_COMMODITY (HS 2–10 digit), I_COMMODITY_LDESC, GEN_VAL_MO, GEN_VAL_YR, CTY_CODE`. 24,349 distinct commodity codes. Assembled from the per-year files in `raw/raw_hs6_YYYY.rds`. Query3 saves the same object under both names.
- **`imp_mex_hs4.rds`** (HS4) and **`imp_mex_hs6.rds`** (HS6): `fecha, Sección*, Cap*, Cod_partida, [Cod_subpartida], Desc_api_*, Val_mes, Val_acum`. Obtained by filtering `nchar(I_COMMODITY)` to 4 or 6, joined to Sección/Capítulo labels. The `_84858790` versions keep Capítulos 84, 85, 87 and 90 (machinery, electrical, vehicles, optics).
- **`imp_mex_top_hs4.rds`**: the 29 top partidas within Caps. 84/85/87/90. It adds `Part_corto, Part_desc_es`.
- **`TCAC_y_shares_84858790.rds`**: `Capítulo, Cap_corto, Cod_partida, Part_corto, Part_desc_es, val_2010, val_2018, val_2024, val_2025, TCAC_1018, TCAC_1824, Crec_2425, pct_cap, pct_total`. Values are 12-month sums per year. TCAC is NA when the initial value is 0. The "Resto" row is the chapter total minus the listed partidas. Definitions are in `meta_TCAC_y_shares`.

### C. Curated partida lists
- **`partidas_valor_depurado.rds`** (Query10): the top 30 HS4 partidas by 2024–2025 value after removing special classification categories. Columns: `ranking, Cod_partida, Cap_corto, Desc_api_partida, Val_2024_2025, Desc_es, Nombre_corto_partida`.
- **`decomp_jerarquica_2025.rds`**: 17-row table with `nivel (TOTAL/Sección/Capítulo/Partida), codigo, etiqueta, valor, pct, valor_mmd, pct_fmt`. Total = US$534.9 bn (2025 imports from Mexico). No `saveRDS` for it appears in any script, Quarto or Rmd file (see §3).
- **`datos_847150_hs6.rds`**: exploratory series for HS6 847150, "digital processing units". It has columns `time, I_COMMODITY, I_COMMODITY_LDESC, GEN_VAL_MO, GEN_VAL_YR, CTY_CODE, CTY_CODE_dl, País, fecha` for Mexico, Vietnam and Taiwán, 2018-01 to 2026-07. It is read by `C3_Tiempos_turbulentos*.qmd` (figure "EXPLORATORIO"). No producer found.

### D. Mexico / Vietnam / Taiwán (Query11, Query12)
- Source: Census Intl Trade API for CTY_CODE 2010, 5520 and 5830. Downloaded 2026-10-13. Period 2010-01 to 2025-12 plus a partial 2026 (Jan–Jul).
- **`raw_df_mex_vnm_twn.rds`**: the same six raw columns as `raw_df`, plus `CTY_CODE_dl, Pais`. 27,263 commodity codes, all HS levels.
- **`imp_competidores_hs4.rds`**: HS4 only, with Sección/Capítulo labels and a `Pais` column. Same value columns as `imp_mex_hs4`. Includes the partial 2026 months.
- **`listas_finales_NS_mex_vnm_twn.rds`**: long format, `Pais, Capítulo, Cap_corto, Cod_partida, Desc_api_partida, Val_2024_2025`. Per country, the Top-50-by-value list after cleaning, plus the nearshoring-relevant selection. Growth comparison uses full years 2018 vs 2025 (`meta_query12`).
- **`tabla_competencia_mex_vnm_twn.rds`**: wide format by country (`México, Vietnam, Taiwán`), `n_paises` = number of lists that include the partida. NAs mean the partida is not on that country's list.
- **`tabla_overlap_mex_vnm_twn.rds`**: only partidas with `n_paises >= 2` in Caps. 84–90, with Spanish descriptions (`Desc_es, Nombre_corto_partida`).

### E. Tariffs (Query4)
- Not on disk: `meta_aranceles_hts8703.rds` (see section L).
- **`aranceles_hts8703_mex_kor_mensual.rds`**: `pais, cod_hts, fecha, val_imp, val_gravable, derechos, tasa_efectiva, tasa_implicita`. HTS 8703 (passenger cars), Mexico and South Korea, monthly 2010-01 to 2025-12. `tasa_efectiva` = duties / import value; `tasa_implicita` = dutiable value / import value.
- Source: USITC DataWeb API (`datawebws.usitc.gov/dataweb`, endpoint `v2/report2/runReport`; token in `.Renviron`).
- **`usitc_prueba_cruda.rds`**: a raw list (`dto`) from a test call of the API.

### F. Exports by state (Query5, Query6)
- **`xmex_total_ef.rds`**: `cve_geo, nombre, año, trimestre, fecha, val_miles`. Total exports by state, thousand USD, 2007Q1–2025Q4. Source: INEGI BIE, ETEF, indicator 6207095692, downloaded 2026-05-03. Per `data-sources`, these are the correct state denominators.
- **`etef_tidy.rds`**: `entidad, codigo_scian, desc_scian, es_total, es_no_especificado, año, trimestre, fecha, val_miles_usd, suprimido, no_aplica`. 32 states × SCIAN 2018 sector/subsector codes, quarterly 2007–2025, thousand USD. Source: INEGI ETEF Excel `Excel/ETEF_Entidad_Subsector.xlsx`, processed 2026-05-03. NA in `val_miles_usd` (32,929 cells) covers suppressed ("C", confidential) and not-applicable cells. State "Exportaciones Totales" rows built from this file understate totals.
- **`supresion_ns_wide.rds`**: by state (25), columns `sec_333, sec_334, sec_335, sec_336`. Each value is the percentage of a state's quarterly observations in that SCIAN sector that are suppressed ("C") in ETEF (`pct_C`, 0–97). It is NA where the state has no exports in that sector.

### G. IMMEX (Query7)
- Source: INEGI, Estadística Mensual sobre Establecimientos con Programa IMMEX (manufacturing segment), open data. Downloaded 2026-05-15. Monthly, 2010-01 to 2026-02.
- **`immex_empleo.rds`**: `fecha, año, ID_MES, CVE_ENT, nombre, abrev, NUM_DE_ESTAB_ACT, emp_prod_directo, emp_prod_externo, emp_prod_total, emp_adm_directo, emp_adm_externo, emp_adm_total, emp_total, ESTATUS`. 19 `CVE_ENT` values: 17 states, `TOT` (national) and `ZLF` (Zona Libre de la Frontera Norte). Baja California (`02`) is built by summing four municipios. `ESTATUS` is Cifras Definitivas or Preliminares (NA for some aggregates).
- **`immex_empleo_ef.rds`**: 16 entidades, same columns. Checked against `immex_empleo`: it equals that file without `CVE_ENT` 02 (Baja California), `TOT` and `ZLF`.
- **`immex_empleo_zlfn.rds`**: the `ZLF` rows of `immex_empleo` (194 months; `emp_total` matches exactly), without the state columns. ZLFN follows the 2018 DOF decree, with Ensenada excluded.
- Input: the 20 yearly CSV files `Excel/IMMEX/immex_manu_ent_2007.csv … 2026.csv`, downloaded by hand from INEGI. Query7 reads 2010 onward.

### H. FDI (Query8)
- Source: Secretaría de Economía, Inversión Extranjera Directa (information to 31 Dec 2025). Input Excel files in `Excel/`: `IED_flujos.xlsx`, `IED_PIB_6.xlsx`, `IED_FBKF_7.xlsx`. Downloaded 2026-05-20. "C" cells (confidential) become NA.
- Units: the column is `ied_mdd` (millones de dólares). **`meta_ied.rds` labels the unit "Miles de millones de dólares", which looks wrong**: the largest value is 48,356 for a year in which Mexico's FDI was about US$48 bn. Values are therefore millions of USD, and the meta field should be corrected.
- SE data are cumulative within the year, so the Q4 value equals the annual total (not the Q4 flow).
- **`ied_por_origen.rds`**: `origen, año, trim, fecha, ied_mdd`. **`ied_por_actividad.rds`**: `codigo_scian, nivel, descripcion, año, trim, fecha, ied_mdd`, for 2006–2025. **`ied_flujos_tipo.rds`**: `tipo, año, trim, fecha, ied_mdd`, 2006Q1–2025Q3.
- **`ied_pib.rds`** / **`ied_fbkf.rds`**: `frecuencia (anual/trimestral), año, trim, fecha, ied_mdd, pib_mdd | fbkf_mdd, ied_pib_pct | ied_fbkf_pct`. 1999–2025.
- **`ied_pib_wdi_comp.rds`**: `país, year, ied_pib_pct`, from World Bank WDI via the `WDI` package, saved from a chunk in the Quarto/Rmd chapter files. Use `iso2c` for joins, since WDI returns "Viet Nam".

### I. Media (Query9_Media, Query9_NS_MentionsMX)
- **`gdelt_nearshoring_mx.rds`**: `fecha, año, mes, n_articulos`. GDELT GKG v2 (`gdelt-bq.gdeltv2.gkg`) through BigQuery. Counts articles whose LOCATIONS field contains Mexico and whose text mentions nearshoring. Downloaded 2026-06-09.
- **`media_cloud_raw.rds`**: `date, count, total_count, ratio`. Daily counts from a Media Cloud CSV export (`Excel/mc-onlinenews-mediacloud-20260611141803-counts.csv`), search "nearshoring Mexico", downloaded 2026-06-11. **`media_cloud_mensual.rds`**: `anio_mes, menciones, total_dias, ratio_mensual`.

### J. Reference
- **`hs_dictionary.rds`**: `nivel (Sección/Capítulo/Partida), codigo, codigo_padre, nombre_corto, nombre_oficial`. Secciones (21) come from WCO Trade Tools HS 2022 in Spanish, transcribed by hand. Capítulos and Partidas come from `Excel/naladisa_2022.xlsx` (NALADISA 2022). Capítulos cover the 96 active ones, excluding 77 and the US-specific 98/99. Partidas are included only for Caps. 84, 85, 87 and 90. `nombre_corto` is defined for Sección and Capítulo only (NA for Partida). Built by `Scripts/build_hs_dictionary.R`.

---

## 3. Items needing a decision before the reorganization

1. **Duplicate:** `raw_df.rds` and `USallImpMex.rds` are identical (same MD5, 45 MB each). Query3 writes both (lines 225 and 256). A case-insensitive search of every `.R`, `.qmd`, `.Rmd` and `.md` file in the repo (including `Quarto/OldQmd/` and `Scripts/old/`) found **no code that reads either name**, only Query3 writing them. If some document loads one of them, it must do so indirectly (a built path or `list.files()`), so check by running the renders after removing one.
   - **Likely bug in Query3:** line 233 builds a cleaned `USallImpMex` object (adds `fecha`, `nivel`, `Capítulo`, `Val_mes`, `Val_acum`), but line 256 saves `raw_df` under the name `USallImpMex.rds`. The cleaned object is never saved, which is why the two files are identical.
2. **No producer script found** for these files: `decomp_jerarquica_2025`, `immex_empleo_ef`, `immex_empleo_zlfn`, `usitc_prueba_cruda`, `datos_847150_hs6`. I searched `Scripts/`, `Scripts/old/`, `Quarto/`, `Quarto/OldQmd/` and `RMD/`. They were presumably created interactively. Their provenance above is inferred from content (for the two IMMEX files I verified it against `immex_empleo`).
3. **Saved from Quarto/Rmd, not from a Query script:** `ied_pib_wdi_comp.rds` (chunk in `C2_Revised_October_2026_v2.qmd`); `impPais_Perc.rds` (old chunk in `C2_texto_abril2026_oldchunks.qmd`, and recomputed in the current qmd). `impMex_sec_pct` was saved without the `.rds` extension by an old chunk, and the current qmd recomputes it in memory.
4. **Written by scripts but absent from `RDS/`:** now catalogued in section L. If a later step expects them, re-run the script. Query10 also has a commented-out save for `top50_partidas_crecimiento.rds`; it is not produced and not catalogued.
5. **`meta_ied.rds` unit label** (see §2H).
6. `meta_query3` / `meta_query11` each contain an `archivos` list. I did not print its contents.

## 4. Regeneration order (dependencies)

- Query1 → `imp_por_pais*`; Query2 reads `imp_por_pais.rds` (top-country list) → `imp_mex_sec_cap`.
- Query3 → `raw/raw_hs6_*`, `raw_df`, `USallImpMex`, `imp_mex_hs4/hs6(+84858790)`, `imp_mex_top_hs4`, `TCAC_y_shares_84858790`. It reads `imp_mex_sec_cap`.
- Query10 reads `imp_mex_hs4.rds`. Query11 → `raw_df_mex_vnm_twn`, `imp_competidores_hs4`. Query12 reads `imp_competidores_hs4`.
- Query5, Query6 (reads `Excel/ETEF_Entidad_Subsector.xlsx`), Query7, Query8 (reads three Excel files), Query9_NS_MentionsMX (reads the Media Cloud CSV) are independent of one another.
- Query4 (USITC), Query9_Media (GDELT via BigQuery, Media Cloud API) and the WDI chunk are also independent API pulls.
- API credentials in `.Renviron`: `CENSUS_API_KEY`, `DATAWEB_TOKEN`, `BIE_TOKEN`, `MEDIACLOUD_API_KEY`, `GCP_PROJECT_ID`.

## 5. Hand-downloaded inputs (`Excel/`)

These files are the only copy of the source for the `.rds` files that come from Excel/CSV downloads. They cannot be regenerated by an API call, so they must move with the repository.

| Input | Content | Feeds | Read by |
|---|---|---|---|
| `Excel/ETEF_Entidad_Subsector.xlsx` | INEGI ETEF: one sheet per state (32), exports by SCIAN subsector, quarterly | `etef_tidy`, `meta_etef`, `supresion_ns_wide`, and (not on disk) `etef_raw`, `etef_supresion_check` | Query6 |
| `Excel/IED_flujos.xlsx` | SE FDI flows. Sheets: Por tipo de inversión, Por origen, Por actividad económica, Por entidad federativa | `ied_por_origen`, `ied_por_actividad`, `ied_flujos_tipo` | Query8 |
| `Excel/IED_PIB_6.xlsx` | SE FDI/GDP. Sheets: IED_PIB_Trimestral, IED_PIB_Anual, Metodología | `ied_pib` | Query8 |
| `Excel/IED_FBKF_7.xlsx` | SE FDI/GFCF. Sheets: IED_FBKF_Trimestral, IED_FBKF_Anual, Metodología | `ied_fbkf` | Query8 |
| `Excel/2025_4T_Flujos_PTI_ACT_3_.xlsx` | Identical to `IED_flujos.xlsx` (same MD5); looks like the original SE file name before renaming | nothing (read by no script) | none |
| `Excel/IMMEX/immex_manu_ent_2007.csv … 2026.csv` | INEGI IMMEX manufacturing segment, one CSV per year (20 files; Query7 uses 2010 onward) | `immex_empleo` (and the two files derived from it) | Query7 |
| `Excel/mc-onlinenews-mediacloud-20260611141803-counts.csv` | Media Cloud daily counts export, downloaded 2026-06-11 | `media_cloud_raw`, `media_cloud_mensual` | Query9_NS_MentionsMX |
| `Excel/naladisa_2022.xlsx` | NALADISA 2022 nomenclature (sheet NALADISA 2022) | `hs_dictionary` | build_hs_dictionary.R |

The sheet "Por entidad federativa" in `IED_flujos.xlsx` is not read by any script (SE assigns investment to legal domicile, which makes it unsuitable for geographic analysis).
