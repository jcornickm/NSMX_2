# Explora_BIE_ETEF_Claves.R   ####
# Objetivo: encontrar las claves BIE de las series
#   "Exportaciones trimestrales de mercancías por entidad federativa, sector y
#    subsector de actividad SCIAN" (total + 27 filas de sector/subsector).
#
# Método: se barren claves consecutivas a partir de la del total (Query04:
# 6207095692), consultando Aguascalientes ("01") y Coahuila ("05"). Los
# valores de Aguascalientes en 2026/02 se comparan con los que muestra el
# árbol del BIE (captura del 22-oct-2026) para identificar cada subsector.
# Coahuila sirve para verificar que la clave responde a nivel estatal.
#
# Es exploratorio: no guarda nada. Salida: tabla en consola.

pacman::p_load(httr2, jsonlite, tidyverse)

bie_token <- Sys.getenv("BIE_TOKEN")
stopifnot("BIE_TOKEN no encontrado" = nchar(bie_token) > 0)

CLAVE_TOTAL <- 6207095692
CLAVES      <- as.character(CLAVE_TOTAL + 0:40)   # 41 claves: sobra margen

# Valores de Aguascalientes, 2026 2T, tomados del árbol del BIE (miles de USD).
# NA = "-" o "C" en pantalla (no sirven para identificar).
referencia <- tribble(
  ~subsector, ~valor_ags_2026_2T,
  "Total",   3447099,
  "111",       17667,
  "112",         452,
  "114",           0,
  "311",       75046,
  "312",        3322,
  "314",        8874,
  "315",       38283,
  "325",        5808,
  "326",       28890,
  "327",       23809,
  "332",       16936
)

fetch_serie <- function(clave, cve_geo) {
  url <- paste0(
    "https://www.inegi.org.mx/app/api/indicadores/desarrolladores/jsonxml/",
    "INDICATOR/", clave, "/es/", cve_geo, "/false/BISE/2.0/", bie_token,
    "?type=json"
  )
  resp <- request(url) |>
    req_error(is_error = \(r) FALSE) |>
    req_perform()
  
  if (resp_status(resp) >= 400) return(tibble(status = resp_status(resp)))
  
  raw <- resp_body_string(resp) |> fromJSON(simplifyVector = FALSE)
  obs <- raw$Series[[1]]$OBSERVATIONS
  if (length(obs) == 0) return(tibble(status = 200L))
  
  map_dfr(obs, \(o) tibble(
    status      = 200L,
    TIME_PERIOD = o$TIME_PERIOD,
    OBS_VALUE   = suppressWarnings(as.numeric(o$OBS_VALUE))
  ))
}

resumen_clave <- function(clave) {
  Sys.sleep(0.2)
  ags <- tryCatch(fetch_serie(clave, "01"), error = \(e) tibble(status = NA_integer_))
  coa <- tryCatch(fetch_serie(clave, "05"), error = \(e) tibble(status = NA_integer_))
  
  ult <- function(d) if ("TIME_PERIOD" %in% names(d) && nrow(d) > 0) {
    d |> arrange(desc(TIME_PERIOD)) |> slice(1)
  } else tibble(TIME_PERIOD = NA_character_, OBS_VALUE = NA_real_)
  
  tibble(
    clave        = clave,
    status_ags   = ags$status[1],
    n_ags        = if ("TIME_PERIOD" %in% names(ags)) nrow(ags) else 0L,
    ult_periodo  = ult(ags)$TIME_PERIOD,
    valor_ags    = ult(ags)$OBS_VALUE,
    status_coah  = coa$status[1],
    n_coah       = if ("TIME_PERIOD" %in% names(coa)) nrow(coa) else 0L
  )
}

message("Barriendo ", length(CLAVES), " claves (2 llamadas cada una)...")
barrido <- map_dfr(CLAVES, \(k) { message("  ", k); resumen_clave(k) }) |>
  left_join(referencia, by = c("valor_ags" = "valor_ags_2026_2T"))

cat("\n=== Barrido de claves BIE (Aguascalientes y Coahuila) ===\n")
barrido |>
  select(clave, subsector, valor_ags, ult_periodo, n_ags, n_coah, status_ags, status_coah) |>
  print(n = Inf, width = 140)

cat("\nLectura:\n",
    "- subsector no vacío = el valor de Aguascalientes en 2026/02 coincide con el del árbol.\n",
    "- n_coah > 0 = la clave responde también a nivel de otro estado.\n",
    "- status distinto de 200 o n_ags = 0: la clave no existe o no es de esta rama.\n", sep = "")
