# ============================================================================
# Query4_Tariffs_USITC.R
#
# Phase 1 — Exploratory single query: USITC DataWeb
# HTS heading 0201 (Beef, fresh/chilled) × Mexico × 2010-2025
#
# Retrieves all three required measures in one call:
#   CONS_CUSTOMS_VALUE          → import_value_usd   (CIF / customs value)
#   CONS_CUSTOMS_VALUE_SUB_DUTY → dutiable_value_usd
#   CONS_CALC_DUTY              → duties_collected_usd
#
# Computes:
#   effective_tariff_rate = duties_collected / import_value
#   implied_tariff_rate   = dutiable_value   / import_value
#
# Validation target (from DataWebQueryExport.xlsx, HTS 0201, Mexico, 2022):
#   import_value_usd     = 1,629,985,825
#   duties_collected_usd =         1,251
#   dutiable_value_usd   =       205,956
#
# ============================================================================

pacman::p_load(httr2, jsonlite, tidyverse, lubridate)

# ── 0. Configuration ──────────────────────────────────────────────────────────

BASE_URL  <- "https://datawebws.usitc.gov/dataweb"
API_TOKEN <- Sys.getenv("DATAWEB_TOKEN")
stopifnot("DATAWEB_TOKEN not found in .Renviron" = nchar(API_TOKEN) > 0)

HTS_CODE <- "0201"
COUNTRY  <- "2010"
YEARS    <- 2010:2025

# ── 1. Build query body ───────────────────────────────────────────────────────

query_body <- list(
  
  reportOptions = list(
    tradeType            = "Import",
    classificationSystem = "HTS"
  ),
  
  searchOptions = list(
    
    componentSettings = list(
      dataToReport = list(
        "CONS_CUSTOMS_VALUE",
        "CONS_CUSTOMS_VALUE_SUB_DUTY",
        "CONS_CALC_DUTY"
      ),
      scale               = "1",
      timeframeSelectType = "fullYears",
      years               = as.list(as.character(YEARS)),
      yearsTimeline       = "Monthly",
      startDate           = NULL,
      endDate             = NULL,
      startMonth          = NULL,
      endMonth            = NULL
    ),
    
    countries = list(
      aggregation         = "Break Out Countries",
      countriesSelectType = "list",
      countryGroups       = list(systemGroups = list(), userGroups = list()),
      countries           = list(COUNTRY),
      countriesExpanded   = list(
        list(name = "Mexico - MX - MEX", value = COUNTRY)
      )
    ),
    
    commodities = list(
      aggregation         = "Break Out Commodities",
      codeDisplayFormat   = "YES",
      commoditySelectType = "list",
      granularity         = "4",
      groupGranularity    = NULL,
      searchGranularity   = NULL,
      showHTSValidDetails = "",
      commoditiesManual   = HTS_CODE,
      commodityGroups     = list(systemGroups = list(), userGroups = list()),
      commodities         = list(HTS_CODE),
      commoditiesExpanded = list(
        list(name = "BOVINE ANIMALS, FRESH OR CHILLED", value = HTS_CODE)
      )
    ),
    
    MiscGroup = list(
      importPrograms = list(
        aggregation        = NULL,
        importPrograms     = list(),
        programsSelectType = "all"
      ),
      provisionCodes = list(
        aggregation              = "Aggregate RPCODE",
        provisionCodesSelectType = "all",
        rateProvisionCodes       = list()
      ),
      districts = list(
        aggregation    = "Aggregate District",
        districtGroups = list(userGroups = list()),
        districts      = list()
      )
    )
  ),
  
  sortingAndDataFormat = list(
    DataSort = list(
      columnOrder = list("COUNTRY", "HTS6 & DESCRIPTION")
    ),
    reportCustomizations = list(
      exportCombineTables = FALSE,
      totalRecords        = "20000",
      exportRawData       = FALSE
    )
  )
)

# ── 2. Send request ───────────────────────────────────────────────────────────

message("Sending DataWeb query: HTS ", HTS_CODE, " | Country ", COUNTRY,
        " | Years ", min(YEARS), "-", max(YEARS), " | Monthly")

resp <- request(paste0(BASE_URL, "/api/v2/report2/runReport")) |>
  req_headers(
    "Content-Type"  = "application/json; charset=utf-8",
    "Authorization" = paste("Bearer", API_TOKEN)
  ) |>
  req_body_raw(
    toJSON(query_body, auto_unbox = TRUE, null = "null"),
    "application/json"
  ) |>
  req_error(is_error = \(r) FALSE) |>
  req_perform()

http_status <- resp_status(resp)
message("HTTP status: ", http_status)

if (http_status >= 400) {
  stop("API error ", http_status, ": ", resp_body_string(resp))
}

resp_json <- resp_body_string(resp) |>
  fromJSON(simplifyVector = FALSE)

n_tables <- length(resp_json$dto$tables)
message("Tables returned: ", n_tables)

if (n_tables == 0) {
  stop("No tables returned. Check HTS code, country code, and year.")
}

# ── 3. Parse response ─────────────────────────────────────────────────────────
# The API returns columns: Country | Year | HTS Number | Description | January | February | ...
# "Year" is an identifier, not a time column. Month names are the time columns.
# We carry "Year" through so we can combine it with the month name to build a date.

parse_table <- function(table_obj, measure_name) {
  
  col_labels <- table_obj$column_groups |>
    map(\(g) map_chr(g$columns, \(c) c$label)) |>
    unlist()
  
  message("  [", measure_name, "] col_labels: ",
          paste(head(col_labels, 8), collapse = " | "),
          if (length(col_labels) > 8) " ..." else "")
  
  rows <- table_obj$row_groups[[1]]$rowsNew
  
  wide <- map_dfr(rows, function(row) {
    vals <- map_chr(row$rowEntries, \(e) as.character(e$value))
    setNames(as.list(vals), col_labels) |> as_tibble()
  })
  
  # Identifier columns — Year is an id here, not a time period
  id_cols   <- c("Country", "COUNTRY", "Year", "YEAR",
                 "HTS Number", "HTS NUMBER", "Description", "DESCRIPTION")
  time_cols <- col_labels[!col_labels %in% id_cols]
  
  if (length(time_cols) == 0) {
    stop("parse_table(): no time columns found for '", measure_name,
         "'. col_labels: ", paste(col_labels, collapse = ", "))
  }
  
  wide |>
    pivot_longer(
      cols      = all_of(time_cols),
      names_to  = "month_name",
      values_to = measure_name
    ) |>
    rename(
      country  = any_of(c("Country",    "COUNTRY")),
      hts_code = any_of(c("HTS Number", "HTS NUMBER")),
      year     = any_of(c("Year",       "YEAR"))
    ) |>
    select(country, hts_code, year, month_name, all_of(measure_name)) |>
    mutate(
      !!measure_name := as.numeric(str_remove_all(.data[[measure_name]], ","))
    )
}

# ── 4. Apply parser, join three measures, build date ─────────────────────────

measure_names <- c("import_value_usd", "dutiable_value_usd", "duties_collected_usd")

df_rates <- map2(
  resp_json$dto$tables[seq_len(min(n_tables, 3))],
  measure_names[seq_len(min(n_tables, 3))],
  parse_table
) |>
  reduce(left_join, by = c("country", "hts_code", "year", "month_name")) |>
  mutate(
    # Combine "January" + "2010" → Date
    fecha = lubridate::my(paste(month_name, year), quiet = TRUE),
    effective_tariff_rate = duties_collected_usd / import_value_usd,
    implied_tariff_rate   = dutiable_value_usd   / import_value_usd
  ) |>
  select(
    country, hts_code, year, month_name, fecha,
    import_value_usd, dutiable_value_usd, duties_collected_usd,
    effective_tariff_rate, implied_tariff_rate
  ) |>
  arrange(country, hts_code, fecha)

# ── 5. Quick diagnostic ───────────────────────────────────────────────────────

cat("\nDate range:", format(min(df_rates$fecha, na.rm = TRUE)),
    "→", format(max(df_rates$fecha, na.rm = TRUE)), "\n")
cat("Rows:", nrow(df_rates), " | NAs in fecha:",
    sum(is.na(df_rates$fecha)), "\n")
cat("Sample periods:", paste(head(unique(paste(df_rates$month_name, df_rates$year)), 5),
                             collapse = ", "), "\n")

# ── 6. Print results ──────────────────────────────────────────────────────────

cat("\n=== Result — HTS", HTS_CODE, "| Mexico | Monthly 2010-2025 ===\n\n")
df_rates |>
  mutate(
    import_value_usd      = scales::comma(import_value_usd),
    duties_collected_usd  = scales::comma(duties_collected_usd),
    dutiable_value_usd    = scales::comma(dutiable_value_usd),
    effective_tariff_rate = scales::percent(effective_tariff_rate, accuracy = 0.001),
    implied_tariff_rate   = scales::percent(implied_tariff_rate,   accuracy = 0.001)
  ) |>
  print(width = 120)

# ── 7. Validation against DataWebQueryExport.xlsx (2022 annual total) ─────────

if (any(year(df_rates$fecha) == 2022, na.rm = TRUE)) {
  cat("\n=== Validation — 2022 annual sum vs. DataWebQueryExport.xlsx ===\n")
  df_2022 <- df_rates |> filter(year(fecha) == 2022)
  validation <- tibble(
    measure   = c("import_value_usd", "duties_collected_usd", "dutiable_value_usd"),
    expected  = c(1629985825, 1251, 205956),
    retrieved = c(
      sum(df_2022$import_value_usd,     na.rm = TRUE),
      sum(df_2022$duties_collected_usd, na.rm = TRUE),
      sum(df_2022$dutiable_value_usd,   na.rm = TRUE)
    )
  ) |>
    mutate(
      match    = abs(retrieved - expected) < 1,
      pct_diff = (retrieved - expected) / expected
    )
  print(validation)
  if (all(validation$match)) {
    message("\n✓ 2022 totals match the validation benchmark.")
  } else {
    warning("\n✗ 2022 validation mismatch — check HTS granularity or measure field names.")
  }
} else {
  message("Validation skipped — 2022 not in data.")
}

# ── 8. Save output ────────────────────────────────────────────────────────────

# saveRDS(df_rates, here::here("RDS", "tariffs_hts0201_mex_monthly.rds"))
# write_csv(df_rates, here::here("RDS", "tariffs_hts0201_mex_monthly.csv"))
# message("Saved: RDS/tariffs_hts0201_mex_monthly.rds / .csv")