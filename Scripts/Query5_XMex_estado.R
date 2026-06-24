# ============================================================================
# Query5_XMex_estado.R
# Exportaciones mexicanas por entidad federativa — ETEF / BIE INEGI
# Fuente: INEGI Banco de Información Económica (BIE)
# Período: 2007/Q1 – 2025/Q4 | Frecuencia: trimestral
# Unidad: miles de dólares estadounidenses
# ============================================================================

pacman::p_load(httr2, jsonlite, tidyverse, here)

bie_token <- Sys.getenv("BIE_TOKEN")
stopifnot("BIE_TOKEN no encontrado" = nchar(bie_token) > 0)

# — Claves BIE ----------------------------------------------------------------
# Fuente: Constructor de consultas BIE
# Rama: Economía y Sectores Productivos > Comercio exterior >
#        Exportaciones por entidad federativa
CLAVE_TOTAL <- "6207095692"

# — Catálogo de entidades federativas (claves INEGI) --------------------------
entidades <- tribble(
  ~cve_geo, ~nombre,
  "01", "Aguascalientes",
  "02", "Baja California",
  "03", "Baja California Sur",
  "04", "Campeche",
  "05", "Coahuila",
  "06", "Colima",
  "07", "Chiapas",
  "08", "Chihuahua",
  "09", "Ciudad de México",
  "10", "Durango",
  "11", "Guanajuato",
  "12", "Guerrero",
  "13", "Hidalgo",
  "14", "Jalisco",
  "15", "Estado de México",
  "16", "Michoacán",
  "17", "Morelos",
  "18", "Nayarit",
  "19", "Nuevo León",
  "20", "Oaxaca",
  "21", "Puebla",
  "22", "Querétaro",
  "23", "Quintana Roo",
  "24", "San Luis Potosí",
  "25", "Sinaloa",
  "26", "Sonora",
  "27", "Tabasco",
  "28", "Tamaulipas",
  "29", "Tlaxcala",
  "30", "Veracruz",
  "31", "Yucatán",
  "32", "Zacatecas"
)

# — Función de descarga (una entidad, una clave) -------------------------------
fetch_bie_entidad <- function(clave, cve_geo) {
  url <- paste0(
    "https://www.inegi.org.mx/app/api/indicadores/desarrolladores/jsonxml/",
    "INDICATOR/", clave,
    "/es/", cve_geo,
    "/false/BISE/2.0/", bie_token,
    "?type=json"
  )
  
  tryCatch({
    resp <- request(url) |>
      req_error(is_error = \(r) FALSE) |>
      req_perform()
    
    if (resp_status(resp) >= 400) {
      message("  HTTP ", resp_status(resp), " — cve_geo: ", cve_geo)
      return(NULL)
    }
    
    raw <- resp_body_string(resp) |> fromJSON(simplifyVector = FALSE)
    
    map_dfr(raw$Series[[1]]$OBSERVATIONS, \(o) tibble(
      TIME_PERIOD = o$TIME_PERIOD,
      OBS_VALUE   = as.numeric(o$OBS_VALUE),
      COBER_GEO   = o$COBER_GEO
    ))
    
  }, error = function(e) {
    message("  ERROR cve_geo ", cve_geo, ": ", conditionMessage(e))
    NULL
  })
}

# — Descarga: iterar sobre las 32 entidades -----------------------------------
message("\n=== Descargando exportaciones totales por entidad federativa ===")

raw_list <- map(entidades$cve_geo, \(cve) {
  message("  Entidad: ", cve)
  fetch_bie_entidad(CLAVE_TOTAL, cve)
})

# — Ensamblar y limpiar -------------------------------------------------------
xmex_total_ef <- raw_list |>
  set_names(entidades$cve_geo) |>
  list_rbind(names_to = "cve_geo") |>
  left_join(entidades, by = "cve_geo") |>
  mutate(
    año       = as.integer(substr(TIME_PERIOD, 1, 4)),
    trimestre = as.integer(substr(TIME_PERIOD, 6, 7)),
    # Fecha: primer mes del trimestre
    fecha     = as.Date(paste0(año, "-", (trimestre - 1) * 3 + 1, "-01")),
    val_miles = OBS_VALUE   # unidad original: miles de USD
  ) |>
  select(cve_geo, nombre, año, trimestre, fecha, val_miles) |>
  arrange(nombre, fecha)

# — Verificación rápida -------------------------------------------------------
cat("\nEntidades descargadas:", n_distinct(xmex_total_ef$cve_geo), "\n")
cat("Rango temporal:", min(xmex_total_ef$fecha) |> as.character(),
    "—", max(xmex_total_ef$fecha) |> as.character(), "\n")
cat("Filas totales:", nrow(xmex_total_ef), "\n")

# Top 5 entidades por valor acumulado 2024
xmex_total_ef |>
  filter(año == 2024) |>
  group_by(nombre) |>
  summarise(val_anual = sum(val_miles, na.rm = TRUE) / 1e6, .groups = "drop") |>
  slice_max(val_anual, n = 5) |>
  mutate(val_anual = scales::comma(val_anual, accuracy = 0.1)) |>
  print()


# — Metadatos -----------------------------------------------------------------
meta_xmex_total_ef <- list(
  fuente         = "INEGI — Exportaciones Trimestrales por Entidad Federativa (ETEF)",
  sistema        = "Banco de Información Económica (BIE)",
  endpoint       = "https://www.inegi.org.mx/app/api/indicadores/desarrolladores/jsonxml/INDICATOR",
  url_proyecto   = "https://www.inegi.org.mx/programas/exporta_ef/",
  fecha_descarga = Sys.time(),
  clave_bie      = CLAVE_TOTAL,
  cobertura_geo  = "32 entidades federativas (claves INEGI 01–32)",
  período        = paste(range(xmex_total_ef$fecha), collapse = " – "),
  frecuencia     = "Trimestral",
  unidad         = "Miles de dólares estadounidenses (val_miles)",
  clasificación  = "Total de exportaciones; sin desglose sectorial",
  metodología    = "Las exportaciones se asignan a la entidad de origen de la producción,
                    no al punto de salida aduanal ni al domicilio fiscal de la empresa.
                    El cálculo vincula registros aduanales con Censos Económicos,
                    Encuestas Manufactureras, IMMEX y registros de Pemex/CNH,
                    usando el RENEM como eje de unión.",
  notas          = "Descarga entidad por entidad (geo = '01' a '32'); el parámetro
                    geo = '99' (todas las entidades) no es compatible con este indicador.
                    Los datos de 2024–2025 son preliminares (sujetos a revisión).
                    La ETEF no incluye exportaciones de Comercio y Servicios, ni
                    operaciones aduanales no vinculables al RENEM (~9–10% del total
                    de la Balanza Comercial).
                    Última actualización INEGI: 31/03/2026."
)


# - Guardar -------------------------------------------------------------------

tryCatch({
  saveRDS(xmex_total_ef, here("RDS", "xmex_total_ef.rds"))
  message("✔ Guardado: RDS/xmex_total_ef.rds  — Filas: ", nrow(xmex_total_ef))
}, error = function(e) {
  message("✗ ERROR guardando xmex_total_ef.rds: ", conditionMessage(e))
})

tryCatch({
  saveRDS(meta_xmex_total_ef, here("RDS", "meta_xmex_total_ef.rds"))
  message("✔ Guardado: RDS/meta_xmex_total_ef.rds")
}, error = function(e) {
  message("✗ ERROR guardando meta_xmex_total_ef.rds: ", conditionMessage(e))
})


#  Parte 2 Transportes  --------------------------------------------------------

CLAVE_TRANSPORTE <- "6207095715"

# Prueba con una sola entidad (Coahuila = "05", importante para autos)
test_336 <- fetch_bie_entidad(CLAVE_TRANSPORTE, "05")

cat("Filas devueltas:", nrow(test_336), "\n")
cat("Rango temporal:", min(test_336$TIME_PERIOD), "—", max(test_336$TIME_PERIOD), "\n")
print(head(test_336, 8))


# Prueba nacional (geo = "00")
test_336_nacional <- fetch_bie_entidad(CLAVE_TRANSPORTE, "00")

cat("Filas devueltas:", nrow(test_336_nacional), "\n")
print(head(test_336_nacional, 5))


# Prueba: Transporte nacional, serie completa
test_336_nacional <- fetch_bie_entidad(CLAVE_TRANSPORTE, "00")

cat("Filas devueltas:", nrow(test_336_nacional), "\n")
cat("Rango temporal:", min(test_336_nacional$TIME_PERIOD), "—", max(test_336_nacional$TIME_PERIOD), "\n")
print(head(test_336_nacional, 8))
