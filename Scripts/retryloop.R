años_pendientes <- 2010:2025
año_actual <- años_pendientes[1]

while (length(años_pendientes) > 0) {
  año_actual <- años_pendientes[1]
  message("Intentando año: ", año_actual)
  
  # Reiniciar sesión HTTP
  httr::handle_reset("https://api.census.gov")
  
  resultado <- tryCatch({
    getCensus(
      name     = "timeseries/intltrade/imports/hs",
      vars     = c("I_COMMODITY", "I_COMMODITY_LDESC", "GEN_VAL_MO", "GEN_VAL_YR"),
      time     = paste0("from ", año_actual, " to ", año_actual),
      key      = api_key,
      CTY_CODE = "2010"
    )
  }, error = function(e) {
    message("  ERROR: ", conditionMessage(e))
    NULL
  })
  
  if (!is.null(resultado)) {
    saveRDS(resultado, here("RDS", "raw", paste0("raw_hs6_", año_actual, ".rds")))
    message("  Guardado: raw_hs6_", año_actual, ".rds")
    años_pendientes <- años_pendientes[-1]  # avanzar al siguiente año
  } else {
    message("  Reintentando ", año_actual, " en 10 segundos...")
    Sys.sleep(10)  # breve pausa antes de reintentar
  }
}