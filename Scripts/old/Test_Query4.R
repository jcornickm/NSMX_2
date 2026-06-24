# ============================================================================
# Query4_USITC_03.R
# HTS 847150 — México y Taiwán — 2025 — Customs Value
# Body construido desde payload real capturado del UI
# ============================================================================

pacman::p_load(httr, jsonlite, tidyverse, here)

api_token <- Sys.getenv("DATAWEB_TOKEN")
stopifnot("Token no encontrado" = nchar(api_token) > 0)

base_url <- "https://datawebws.usitc.gov/dataweb"
headers  <- c(
  "Content-Type"  = "application/json; charset=utf-8",
  "Authorization" = paste("Bearer", api_token)
)

query_body <- list(
  reportOptions = list(
    tradeType            = "Import",
    classificationSystem = "HTS"
  ),
  searchOptions = list(
    
    componentSettings = list(
      dataToReport = list("CONS_CUSTOMS_VALUE", "CONS_CUSTOMS_VALUE_SUB_DUTY", "CONS_CALC_DUTY"),
      scale               = "1",
      timeframeSelectType = "fullYears",
      years               = as.list(as.character(2010:2025)),
      yearsTimeline       = "Annual",
      endDate             = NULL,
      endMonth            = NULL,
      startDate           = NULL,
      startMonth          = NULL
    ),
    
    countries = list(
      aggregation        = "Break Out Countries",
      countriesSelectType = "list",
      countryGroups      = list(systemGroups = list(), userGroups = list()),
      countries          = list("2010", "5830"),
      countriesExpanded  = list(
        list(name = "Mexico - MX - MEX",   value = "2010"),
        list(name = "Taiwan - TW - TWN",   value = "5830")
      )
    ),
    
    commodities = list(
      aggregation        = "Break Out Commodities",  # clave que faltaba
      codeDisplayFormat  = "YES",
      commoditySelectType = "list",                  # clave que faltaba
      granularity        = "6",                      # clave que faltaba
      groupGranularity   = NULL,
      searchGranularity  = NULL,
      showHTSValidDetails = "",
      commoditiesManual  = "847150",                 # clave que faltaba
      commodityGroups    = list(systemGroups = list(), userGroups = list()),
      commodities        = list("847150"),
      commoditiesExpanded = list(
        list(
          name  = "DIGITAL PROCESSING UNITS OTHER THAN THOSE OF 8471.41 AND 8471.49, N.E.S.O.I.",
          value = "847150"
        )
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

# — Llamada -------------------------------------------------------------------
message("Enviando consulta...")

response <- POST(
  url    = paste0(base_url, "/api/v2/report2/runReport"),
  add_headers(.headers = headers),
  body   = toJSON(query_body, auto_unbox = TRUE, null = "null"),
  encode = "raw"
)

cat("HTTP:", status_code(response), "\n")

resp_json <- fromJSON(content(response, "text", encoding = "UTF-8"),
                      simplifyVector = FALSE)

cat("Tablas:", length(resp_json$dto$tables), "\n")
cat("hts2Selections:", paste(unlist(resp_json$dto$hts2Selections), collapse = ", "), "\n")

# — Extracción ----------------------------------------------------------------
if (length(resp_json$dto$tables) > 0) {
  
  # Labels de columnas
  col_labels <- resp_json$dto$tables[[1]]$column_groups |>
    map(~ map_chr(.x$columns, ~ .x$label)) |>
    unlist()
  cat("\nColumnas:", paste(col_labels, collapse = " | "), "\n\n")
  
  filas <- resp_json$dto$tables[[1]]$row_groups[[1]]$rowsNew
  
  df <- map_dfr(filas, function(fila) {
    vals <- map_chr(fila$rowEntries, ~ as.character(.x$value))
    setNames(as.list(vals), col_labels) |> as_tibble()
  })
  
  print(df)
  
} else {
  cat("Sin datos\n")
  str(resp_json$dto, max.level = 2)
}

# Ver el título de cada tabla — debería identificar qué variable es cada una
map_chr(resp_json$dto$tables, ~ .x$title %||% "sin título")

# Extraer las tres tablas y unir
df_final <- map_dfr(seq_along(resp_json$dto$tables), function(i) {
  
  tabla <- resp_json$dto$tables[[i]]
  
  col_labels <- tabla$column_groups |>
    map(~ map_chr(.x$columns, ~ .x$label)) |>
    unlist()
  
  filas <- tabla$row_groups[[1]]$rowsNew
  
  map_dfr(filas, function(fila) {
    vals <- map_chr(fila$rowEntries, ~ as.character(.x$value))
    setNames(as.list(vals), col_labels) |> as_tibble()
  }) |>
    mutate(tabla_idx = i)
})

print(df_final)

var_names <- c("customs_value", "dutiable_value", "calc_duties")

df_final <- map2_dfr(resp_json$dto$tables, var_names, function(tabla, var) {
  
  col_labels <- tabla$column_groups |>
    map(~ map_chr(.x$columns, ~ .x$label)) |>
    unlist()
  
  filas <- tabla$row_groups[[1]]$rowsNew
  
  map_dfr(filas, function(fila) {
    vals <- map_chr(fila$rowEntries, ~ as.character(.x$value))
    setNames(as.list(vals), col_labels) |> as_tibble()
  }) |>
    rename(value = `2025`) |>
    mutate(variable = var)
}) |>
  mutate(value = as.numeric(str_remove_all(value, ","))) |>
  pivot_wider(names_from = variable, values_from = value) |>
  rename(country = Country, hts_code = `HTS Number`, year = Description) |>
  mutate(
    year = 2025,
    effective_tariff_rate = calc_duties   / customs_value,
    implied_tariff_rate   = dutiable_value / customs_value
  ) |>
  select(country, hts_code, year, customs_value, dutiable_value, 
         calc_duties, effective_tariff_rate, implied_tariff_rate)

print(df_final)
