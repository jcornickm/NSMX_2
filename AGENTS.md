# NSMX — Project Memory

Book/report project on nearshoring (NS) in Mexico. Chapters are Quarto `.docx`
documents in [Quarto/](Quarto); data pipelines are standalone R scripts in
[Scripts/](Scripts) that save intermediate results as `.rds` in [RDS/](RDS).

## Project layout

- `Scripts/` — `QueryNN_*.R` scripts ingest an external source (API pull or hand-downloaded Excel/CSV: US Census
  Intl Trade API, USITC tariffs, WDI, IMMEX, Media Cloud, etc.) and run first; then
  `PrepNN_*.R` scripts (numbered in run order) that use only data already stored locally to build derived/analysis-ready tables; `Explora_*.R` are exploratory and outside the pipeline; and
  `funciones.R`, sourced by everything else (see below).
- `RDS/` — intermediate and final data objects (`raw/` subfolder holds raw
  per-year API pulls). Treat as a cache: re-derivable from `Scripts/`.
- `Quarto/` — chapter `.qmd` files, rendered to `.docx` against
  `reference-doc.docx`. `C2_Revised_October_2026_v2.qmd` is the main active
  chapter (Ch. 2); `C3_Tiempos_turbulentos_v2.qmd` is Ch. 3.
- `Plots/` — `.png`/`.pdf` figures saved by the `.qmd` files' plot-generation
  chunks; referenced back into the documents via `knitr::include_graphics()`.
- `Tablas/` — formatted tables saved as flextable `.rds` by the scripts; the
  `.qmd` only does `readRDS()` and prints them (table counterpart of `Plots/`).
- `Excel/` — manually curated lookup tables (e.g. `hs_nombres_cortos.csv`
  for HS short names), edited by hand, not generated.
- `geodata/` — cached `sf`/GADM shapefiles for Mexico state maps.

## Key conventions

- **`Scripts/funciones.R`** is sourced at the top of every script/qmd and
  defines shared constants and helpers:
  - `ANIO_FIN <- 2024L`, `FECHA_FIN <- as.Date("2024-12-31")` — the data
    cutoff for Chapter 2 (all its figures/tables end in Dec 2024). Chapter 3
    uses the most recent data and does *not* use these constants.
  - `sa_adj(x, dates, freq = NULL)` — seasonal adjustment via the `seasonal`
    package (X-13ARIMA-SEATS), auto-detects monthly/quarterly frequency.
  - `hs_cargar()`, `hs_tablas()`, `hs_agregar_etiquetas()`,
    `hs_etiquetas_partida()`, `hs_relabel()` — Harmonized System (HS)
    code labeling. Single source of truth is `RDS/hs_dictionary.rds`,
    built by `Scripts/build_hs_dictionary.R` from
    `Excel/naladisa_2022.xlsx` + `Excel/hs_nombres_cortos.csv`. Short names
    are edited **only** in the CSV — never hardcode HS labels as ad hoc
    tribbles in query scripts or `.qmd` files.
  - `breaks_tcac`, `labels_tcac`, `paleta_tcac` — shared CAGR/TCAC bins and
    palette so maps and tables stay visually consistent.
- **Quarto chunk pattern in `.qmd` chapters**: plot-generating chunks are
  placed at the front of each document section, before the prose that
  discusses them, and are marked `#| eval: false` so they do **not** run
  during a normal `quarto render` — they must be run manually/interactively
  whenever their code or upstream data changes. When asked to "rerun the
  plot chunks," this means running the `eval: false` chunks, not just
  re-rendering. Within a plot chunk:
  - The plot itself is built with `p <- local({ ... })` so intermediate
    objects used only to construct the plot don't leak into the global
    environment.
  - The result is always saved as both `.png` and `.pdf` via two `ggsave()`
    calls to `Plots/`.
  - The actual in-document chunk for a figure (the one that *does* run on
    every render) just does
    `knitr::include_graphics(here::here("Plots", "<file>.png"))`.
  - At the end of each document section, a cleanup chunk (also
    `eval: false`) `rm()`s objects that were only needed within that
    section, keeping the environment uncluttered for everything that
    follows.
- Heavy/plot-only packages (`patchwork`, `sf`, `cowplot`, `ggrepel`,
  `treemapify`, `glue`, `WDI`) are loaded lazily inside the `eval: false`
  chunks that need them, not in the top-level `loadlibs` chunk, to keep
  normal renders fast.
- **Tables use `flextable`, not `gt()`** — `gt()` doesn't emit `<w:tblGrid>`
  column widths when exporting to Word in the version used here, producing
  tables with text split letter-by-letter. `flextable` renders as a native
  Word table with correct widths and preserves cell shading/highlighting.
  Pattern: `flextable() |> ... |> theme_booktabs() |> autofit() |>
  fit_to_width(max_width = 6, unit = "in")` (6" = usable width inside
  `reference-doc.docx`'s 1.25" margins on letter paper).
- US Census International Trade API: omit `COMM_LVL` intentionally — combined
  with `CTY_CODE` it errors on HS4/HS6 queries. Without it, the API returns
  all HS levels mixed in `I_COMMODITY`, split by `nchar()` after download.
  Download is iterated year-by-year (fails on long ranges) and each year is
  cached as an individual RDS immediately.
- `CTY_CODE = "2010"` = Mexico in Census API country codes.

## Environments

- Sync is done with `sync(msg = NULL)`, defined in the user's personal
  `.Rprofile` (not in the repo): it stages and commits everything, then
  `gert::git_pull()` (errors on conflict) and `git_push()`. **Never make
  manual commits or pushes**; the user runs `sync()` themselves.

- Work happens in two places, synced via Git at the start and end of each
  session: local RStudio (Surface ARM, Windows) and Posit Cloud.
- **Do not render Quarto in local RStudio** (`quarto render`, `quarto preview`,
  or equivalents): Quarto doesn't work well on the Surface ARM. Renders are
  done only in Posit Cloud. Locally, editing `.qmd`/scripts, running the
  `eval: false` plot/table chunks, and running `Scripts/` pipelines is fine.

## Preferences

- Use the `here` package for all paths (`here::here(...)`), not relative or
  absolute hardcoded paths.
- Pipeline scripts guard expensive re-downloads with a `repull` switch
  (default `FALSE`): when `FALSE`, rebuild everything from cached RDS;
  when `TRUE`, re-call the API (requires an API key in `.Renviron`).

## Detailed instructions (read at the start of every session)

Full project conventions live in [MD/instrucciones_posit_ai.md](MD/instrucciones_posit_ai.md)
(shared with the other assistant, Claude, so the repo is the common memory).
**Read it at the start of each session**, together with `Scripts/funciones.R`,
and `MD/Pendientes_NSMX_*.md`. It covers: working style, script
naming, R code conventions, plot theme/palettes (`paleta_pais`, `COL_*`,
`paleta_seccion`, `paleta_tcac`; never loose hex), saving figures, qmd chunk
patterns, flextable tables, HS dictionary, periods/dates (2010-2017 vs 2018-2024,
base 2017), and known source pitfalls. Highlights:

- Wait for an explicit "adelante" before editing files or running work; plans
  mentioned by Jorge are context, not instructions.
- The "do not run interactively" rule in `instrucciones_posit_ai.md` is for Claude only.
  Posit Assistant MAY run code and chunks interactively (Jorge works with me when he
  wants interactivity). Still wait for "adelante" before editing files.
- Font: ignore the `[VERIFICAR: IBM Plex Sans]` note; match what existing plots do
  (`theme_bw()` + short `theme()`, no custom font).
- (Claude-only rule, for reference) Jorge runs scripts himself, one by one, in a fresh session. Do not re-run
  sections interactively unless asked (e.g. asked to run the `eval: false` chunks).
- Code comments and variable names in Spanish, `snake_case`; `pacman::p_load()`.
- Country names must match `paleta_pais` keys exactly ("EUA", "Taiwán", "Vietnam",
  "Corea del Sur"); never invent colors for missing countries, flag them.
- Never print or commit credentials; read them with `Sys.getenv()`.
- Orphan files go to `RDS/Por_eliminar/` or `Excel/Por_eliminar/`, not deleted.

## Reference-file digest (read once on 2026-11-01; re-open only when needed)

`Scripts/funciones.R` (already sourced; objects live in the R session) defines,
in order: `Sys.umask("022")`; `ANIO_FIN`, `FECHA_FIN`; `sa_adj()`; HS helpers
(`hs_cargar`, `hs_tablas`, `hs_agregar_etiquetas`, `hs_etiquetas_partida`,
`hs_agregar_etiquetas_seccion`, `hs_relabel`); `breaks_tcac`/`labels_tcac`/
`paleta_tcac`; `paleta_pais` (12 keys); `COL_TOTAL/RESTO/SERIE/TENDENCIA/HITO`;
`paleta_seccion` (XVI, XVII, XVIII, Otras); `etiqueta_periodo(ini, fin)`.
There is NO shared ggplot theme function.

`Quarto/CATALOGOS_NSMX.qmd` (current as of 2026-10-24; replaces the deleted
`MD/Catalogo_RDS.md`) is the data/script catalogue: RDS files by topic (contents,
producer, readers, status), figures, tables, Query/Prep cards, dependency map.
Consult it (read the .qmd; do not render) when:
- loading/using any `RDS/*.rds` and unsure of its contents, producer or status;
- tracing which script produces a file or what must be re-run (Part II run
  order, Part III dependency map);
- touching FDI (`ied_*`: `ied_acum_mdd` is CUMULATIVE within year; annual =
  `trim == 4`, never sum quarters), Media Cloud, IMMEX, ETEF, tariffs, or Census
  imports; see "Trampas conocidas" in Part I.
It has no row/column counts or date ranges for files regenerated in the last
repull; inspect the RDS directly (or its appendix chunk) for those.
Other MD files not yet read: `Pendientes_NSMX_2026-10-24.md`,
`Fuentes_APIs.md`, `Pendientes_periodos_2017.md`, `fuentes_ied.md`.
Read `Pendientes_*` before suggesting next steps or when asked about open items.
