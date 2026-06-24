# =============================================================================
# US Import Data — Census Bureau International Trade API
# Script:  00_descarga_importaciones.R
# Purpose: Download (1) total imports by country, (2) imports from Mexico
#          by HS level (Chapter / Heading / Subheading)
# Period:  January 2010 – latest available month
# Author:  [your name]
# =============================================================================
# NOTES ON API BEHAVIOUR (read before running)
# -----------------------------------------------------------------------------
# • The Census API cannot handle a single call for ALL countries + ALL
#   commodities + a long date range.  We always split by time and/or
#   commodity and then bind the pieces together.
# • "from 2010 to 2025" is valid syntax for the `time` parameter in
#   getCensus(), but for trade endpoints it is safer to loop year-by-year:
#   the API frequently times out on multi-year, many-row requests.
# • Parameters like COMM_LVL are passed via `time` or `vars` in some
#   censusapi versions, but the correct way is through the `...` (dots)
#   argument as named parameters.
# • Mexico CTY_CODE = "2010"
# • Monthly data starts January 2013 in the API.
#   Annual data goes back to 2002 via a different endpoint (not used here).
#   We therefore start at 2013 for monthly series.
# =============================================================================

library(censusapi)
library(dplyr)
library(purrr)
library(here)

# — API key -------------------------------------------------------------------
# Store your key in .Renviron as CENSUS_API_KEY=xxxxx
# then restart R.  Never hard-code it in a script.
api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("Census API key not found — set CENSUS_API_KEY in .Renviron" =
            nchar(api_key) > 0)

# — Output folder -------------------------------------------------------------
dir.create(here("RDS"), showWarnings = FALSE)

# — Helper: attach standard source attributes ---------------------------------
add_source_attr <- function(df, endpoint, notes = NULL) {
  attr(df, "source_info") <- list(
    source         = "US Census Bureau — International Trade API",
    endpoint       = endpoint,
    url            = paste0("https://api.census.gov/data/timeseries/", endpoint),
    fecha_descarga = Sys.time(),
    periodo        = paste(range(df$YEAR), collapse = " – "),
    notes          = notes
  )
  df
}

# — Years to download ---------------------------------------------------------
# Monthly trade data available from 2013 onward via this endpoint.
# Change start_year if you later find annual data for 2010-2012 elsewhere.
years <- 2013:2025


# =============================================================================
# QUERY 1 — Total US imports by country of origin (all commodities rolled up)
# =============================================================================
# Strategy: one call per year, no commodity dimension → the API rolls up to
# the country total automatically (CTY_CODE is the only dimension).
# We include CTY_CODE = "-" which is the "all countries" grand total row.
# -----------------------------------------------------------------------------

message("=== Query 1: Total imports by country ===")

fetch_imports_by_country <- function(year) {
  message("  Downloading year: ", year)
  tryCatch({
    getCensus(
      name = "timeseries/intltrade/imports/hs",
      vars = c("CTY_CODE", "CTY_NAME",
               "GEN_VAL_MO",   # general imports value, current month (USD)
               "GEN_VAL_YR"),  # cumulative year-to-date value (USD)
      time = paste0("from ", year, " to ", year),
      key  = api_key
    )
  }, error = function(e) {
    message("  ERROR for year ", year, ": ", conditionMessage(e))
    NULL
  })
}

raw_by_country <- map(years, fetch_imports_by_country)

# Drop failed years, bind, clean
imp_total_por_pais <- raw_by_country |>
  compact() |>
  bind_rows() |>
  mutate(
    YEAR       = as.integer(YEAR),
    MONTH      = as.integer(MONTH),
    GEN_VAL_MO = as.numeric(GEN_VAL_MO),
    GEN_VAL_YR = as.numeric(GEN_VAL_YR),
    fecha      = as.Date(paste(YEAR, MONTH, "01", sep = "-"))
  ) |>
  arrange(YEAR, MONTH, CTY_CODE) |>
  add_source_attr(
    endpoint = "timeseries/intltrade/imports/hs",
    notes    = "All commodities rolled up; one row per country per month.
                CTY_CODE = '-' is the grand total for all countries."
  )

saveRDS(imp_total_por_pais,
        here("RDS", "imp_total_por_pais.rds"))
message("  Saved: RDS/imp_total_por_pais.rds — ",
        nrow(imp_total_por_pais), " rows")


# =============================================================================
# QUERY 2a — Mexico imports at Chapter level (HS 2-digit)
# =============================================================================
# CTY_CODE = "2010" (Mexico), COMM_LVL = "HS2"
# One call per year is sufficient at this aggregation level.
# We add the HS chapter description variable.
# -----------------------------------------------------------------------------

message("\n=== Query 2a: Mexico imports — Chapter (HS2) ===")

fetch_mexico_hs2 <- function(year) {
  message("  Downloading year: ", year)
  tryCatch({
    getCensus(
      name    = "timeseries/intltrade/imports/hs",
      vars    = c("I_COMMODITY",        # HS code at requested digit level
                  "I_COMMODITY_LDESC",  # long description
                  "I_COMMODITY_SDESC",  # short description
                  "GEN_VAL_MO",
                  "GEN_VAL_YR"),
      time    = paste0("from ", year, " to ", year),
      key     = api_key,
      CTY_CODE  = "2010",   # Mexico
      COMM_LVL  = "HS2"     # Chapter level
    )
  }, error = function(e) {
    message("  ERROR for year ", year, ": ", conditionMessage(e))
    NULL
  })
}

raw_mexico_hs2 <- map(years, fetch_mexico_hs2)

imp_mexico_hs2 <- raw_mexico_hs2 |>
  compact() |>
  bind_rows() |>
  mutate(
    YEAR             = as.integer(YEAR),
    MONTH            = as.integer(MONTH),
    GEN_VAL_MO       = as.numeric(GEN_VAL_MO),
    GEN_VAL_YR       = as.numeric(GEN_VAL_YR),
    hs_chapter       = as.integer(I_COMMODITY),
    fecha            = as.Date(paste(YEAR, MONTH, "01", sep = "-"))
  ) |>
  arrange(YEAR, MONTH, I_COMMODITY) |>
  add_source_attr(
    endpoint = "timeseries/intltrade/imports/hs",
    notes    = "Mexico (CTY_CODE=2010), COMM_LVL=HS2.
                One row per HS chapter (2-digit) per month."
  )

# Add HS Section lookup (21 sections mapped to chapter ranges)
hs_sections <- tribble(
  ~section, ~section_desc,                                              ~ch_from, ~ch_to,
  "I",    "Live animals; animal products",                                  1,   5,
  "II",   "Vegetable products",                                             6,  14,
  "III",  "Animal or vegetable fats and oils",                             15,  15,
  "IV",   "Prepared foodstuffs; beverages; tobacco",                       16,  24,
  "V",    "Mineral products",                                              25,  27,
  "VI",   "Chemical and allied industries",                                28,  38,
  "VII",  "Plastics and rubber",                                           39,  40,
  "VIII", "Raw hides, skins, leather, furskins",                           41,  43,
  "IX",   "Wood and articles of wood",                                     44,  46,
  "X",    "Pulp of wood; paper and paperboard",                            47,  49,
  "XI",   "Textiles and textile articles",                                 50,  63,
  "XII",  "Footwear, headgear, umbrellas",                                 64,  67,
  "XIII", "Articles of stone, plaster, ceramics, glass",                   68,  70,
  "XIV",  "Natural or cultured pearls, precious metals",                   71,  71,
  "XV",   "Base metals and articles",                                      72,  83,
  "XVI",  "Machinery and mechanical appliances; electrical equipment",      84,  85,
  "XVII", "Vehicles, aircraft, vessels",                                   86,  89,
  "XVIII","Optical, photographic, medical instruments",                     90,  92,
  "XIX",  "Arms and ammunition",                                           93,  93,
  "XX",   "Miscellaneous manufactured articles",                           94,  96,
  "XXI",  "Works of art, collectors' pieces",                              97,  99
)

imp_mexico_hs2 <- imp_mexico_hs2 |>
  rowwise() |>
  mutate(
    section      = hs_sections$section[
      which(hs_sections$ch_from <= hs_chapter &
              hs_sections$ch_to   >= hs_chapter)[1]],
    section_desc = hs_sections$section_desc[
      which(hs_sections$ch_from <= hs_chapter &
              hs_sections$ch_to   >= hs_chapter)[1]]
  ) |>
  ungroup()

saveRDS(imp_mexico_hs2, here("RDS", "imp_mexico_hs2.rds"))
message("  Saved: RDS/imp_mexico_hs2.rds — ", nrow(imp_mexico_hs2), " rows")


# =============================================================================
# QUERY 2b — Mexico imports at Heading level (HS 4-digit)
# =============================================================================
# At HS4 there are ~1,200 headings × 12 months × 13 years = large but
# manageable.  We still loop by year to stay well within API limits.
# -----------------------------------------------------------------------------

message("\n=== Query 2b: Mexico imports — Heading (HS4) ===")

fetch_mexico_hs4 <- function(year) {
  message("  Downloading year: ", year)
  tryCatch({
    getCensus(
      name    = "timeseries/intltrade/imports/hs",
      vars    = c("I_COMMODITY",
                  "I_COMMODITY_LDESC",
                  "I_COMMODITY_SDESC",
                  "GEN_VAL_MO",
                  "GEN_VAL_YR"),
      time    = paste0("from ", year, " to ", year),
      key     = api_key,
      CTY_CODE = "2010",
      COMM_LVL = "HS4"
    )
  }, error = function(e) {
    message("  ERROR for year ", year, ": ", conditionMessage(e))
    NULL
  })
}

raw_mexico_hs4 <- map(years, fetch_mexico_hs4)

imp_mexico_hs4 <- raw_mexico_hs4 |>
  compact() |>
  bind_rows() |>
  mutate(
    YEAR             = as.integer(YEAR),
    MONTH            = as.integer(MONTH),
    GEN_VAL_MO       = as.numeric(GEN_VAL_MO),
    GEN_VAL_YR       = as.numeric(GEN_VAL_YR),
    hs_chapter       = as.integer(substr(I_COMMODITY, 1, 2)),
    fecha            = as.Date(paste(YEAR, MONTH, "01", sep = "-"))
  ) |>
  arrange(YEAR, MONTH, I_COMMODITY) |>
  add_source_attr(
    endpoint = "timeseries/intltrade/imports/hs",
    notes    = "Mexico (CTY_CODE=2010), COMM_LVL=HS4.
                One row per HS heading (4-digit) per month."
  )

saveRDS(imp_mexico_hs4, here("RDS", "imp_mexico_hs4.rds"))
message("  Saved: RDS/imp_mexico_hs4.rds — ", nrow(imp_mexico_hs4), " rows")


# =============================================================================
# QUERY 2c — Mexico imports at Subheading level (HS 6-digit)
# =============================================================================
# HS6 is significantly larger (~5,000 subheadings).  The API guide warns
# that country × all-commodities at fine grain can timeout.
# Strategy: split by first digit of HS code (1–9) to keep each call small,
# exactly as the Census guide recommends.
# -----------------------------------------------------------------------------

message("\n=== Query 2c: Mexico imports — Subheading (HS6) ===")

fetch_mexico_hs6_chunk <- function(year, first_digit) {
  # first_digit: integer 1–9, used to filter commodity codes
  tryCatch({
    getCensus(
      name    = "timeseries/intltrade/imports/hs",
      vars    = c("I_COMMODITY",
                  "I_COMMODITY_LDESC",
                  "I_COMMODITY_SDESC",
                  "GEN_VAL_MO",
                  "GEN_VAL_YR"),
      time    = paste0("from ", year, " to ", year),
      key     = api_key,
      CTY_CODE   = "2010",
      COMM_LVL   = "HS6",
      I_COMMODITY = paste0(first_digit, "*")  # wildcard: all codes starting with digit
    )
  }, error = function(e) {
    message("    ERROR year=", year, " digit=", first_digit,
            ": ", conditionMessage(e))
    NULL
  })
}

# Build a grid of all year × first-digit combinations
grid_hs6 <- expand.grid(year = years, first_digit = 1:9,
                        stringsAsFactors = FALSE)

message("  Total chunks to download: ", nrow(grid_hs6),
        " (", length(years), " years × 9 digit groups)")

raw_mexico_hs6 <- map2(
  grid_hs6$year,
  grid_hs6$first_digit,
  function(y, d) {
    message("  year=", y, "  digit=", d)
    fetch_mexico_hs6_chunk(y, d)
  }
)

imp_mexico_hs6 <- raw_mexico_hs6 |>
  compact() |>
  bind_rows() |>
  distinct() |>                        # guard against any overlap
  mutate(
    YEAR       = as.integer(YEAR),
    MONTH      = as.integer(MONTH),
    GEN_VAL_MO = as.numeric(GEN_VAL_MO),
    GEN_VAL_YR = as.numeric(GEN_VAL_YR),
    hs_chapter = as.integer(substr(I_COMMODITY, 1, 2)),
    fecha      = as.Date(paste(YEAR, MONTH, "01", sep = "-"))
  ) |>
  arrange(YEAR, MONTH, I_COMMODITY) |>
  add_source_attr(
    endpoint = "timeseries/intltrade/imports/hs",
    notes    = "Mexico (CTY_CODE=2010), COMM_LVL=HS6.
                Downloaded in 9 chunks by first digit of I_COMMODITY.
                One row per HS subheading (6-digit) per month."
  )

saveRDS(imp_mexico_hs6, here("RDS", "imp_mexico_hs6.rds"))
message("  Saved: RDS/imp_mexico_hs6.rds — ", nrow(imp_mexico_hs6), " rows")


# =============================================================================
# SUMMARY
# =============================================================================
message("\n=== Download complete ===")
message("Files saved to ", here("RDS"), ":")
message("  imp_total_por_pais.rds — total imports by country (all commodities)")
message("  imp_mexico_hs2.rds     — Mexico imports, Chapter level (HS2) + Section")
message("  imp_mexico_hs4.rds     — Mexico imports, Heading level (HS4)")
message("  imp_mexico_hs6.rds     — Mexico imports, Subheading level (HS6)")
message("\nTo reload any file:")
message("  df <- readRDS(here('RDS', 'imp_mexico_hs4.rds'))")
message("  attr(df, 'source_info')   # inspect provenance")