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
