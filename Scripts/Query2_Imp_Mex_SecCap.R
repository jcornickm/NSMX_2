# ============================================================================
# Query2
# US imports from Mexico, all aggregation levels 2010–2025
# Nota: COMM_LVL omitido intencionalmente. La combinación CTY_CODE + COMM_LVL
#       (para HS4 y HS6) genera error del servidor. Sin COMM_LVL, el API
#       devuelve todos los niveles mezclados (HS2, HS4, HS6, 10 dígitos);
#       se separan después por nchar(I_COMMODITY).
# Download one year at a time
# Incorporate retry loop later
# April 29 2026
# ============================================================================



# =============================================================================
# NOTAS SOBRE EL API (leer antes de ejecutar)
# -----------------------------------------------------------------------------
# • El API devuelve una columna `time` con formato 'AAAA-MM'. No devuelve
#   columnas separadas YEAR y MONTH. Se extraen con substr().
# • Se itera año por año para evitar timeouts en rangos largos.
# • CTY_CODE = "2010" corresponde a México.
# • Datos mensuales disponibles desde enero 2010 en este endpoint.
# • Los totales (por Sección, país, año) se calculan bajo demanda con
#   group_by() |> summarise(). Este archivo almacena un registro por
#   Capítulo por mes; no incluye filas de totales agregados.
# • Las variables de texto descriptivo (nombres de Sección y Capítulo)
#   se almacenan como factores ordenados por su número/roman numeral.
# =============================================================================

pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse,
               here, janitor, censusapi, scales)

# — Clave del API -------------------------------------------------------------
api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("Clave del Census API no encontrada — definir CENSUS_API_KEY en .Renviron" =
            nchar(api_key) > 0)

# — Años a descargar ----------------------------------------------------------
años <- 2010:2025

source(here("Scripts", "funciones.R"))   # hs_agregar_etiquetas(), hs_etiquetas_partida(), sa_adj()

# — Etiquetas del SA ----------------------------------------------------------
# Secciones y Capítulos (nombre corto) salen de RDS/hs_dictionary.rds, que se
# construye con Scripts/build_hs_dictionary.R (editar nombres en
# Excel/hs_nombres_cortos.csv). Ya no hay tribbles de nombres en este script.

# — Función de descarga (un año a la vez) -------------------------------------
descargar_mexico_hs2 <- function(año) {
  message("  Descargando año: ", año)
  tryCatch({
    getCensus(
      name     = "timeseries/intltrade/imports/hs",
      vars     = c("I_COMMODITY",
                   "I_COMMODITY_LDESC",
                   "GEN_VAL_MO",
                   "GEN_VAL_YR"),
      time     = paste0("from ", año, " to ", año),
      key      = api_key,
      CTY_CODE = "2010"
      )
  }, error = function(e) {
    message("  ERROR en año ", año, ": ", conditionMessage(e))
    NULL
  })
}

# — Descarga ------------------------------------------------------------------
message("\n=== Descargando: importaciones de EUA desde México por Capítulo SA ===")
raw_list <- map(años, descargar_mexico_hs2)

# — Limpieza y construcción del tibble final ----------------------------------
imp_mex_sec_cap <- raw_list |>
  compact() |>
  bind_rows() |>
  as_tibble() |>
  mutate(
    fecha    = as.Date(paste0(time, "-01")),
    capitulo = as.integer(I_COMMODITY),
    val_mes  = as.numeric(GEN_VAL_MO),
    val_acum = as.numeric(GEN_VAL_YR)
  ) |>
  hs_agregar_etiquetas(col_cap = "capitulo") |>
  select(
    fecha,
    Sección,
    Sección_corto,
    Capítulo          = capitulo,
    Cap_corto,
    Cap_desc_api      = I_COMMODITY_LDESC,
    Val_mes           = val_mes,
    Val_acum          = val_acum
  ) |>
  arrange(fecha, Capítulo)

# — Seasonal adjustment -------------------------------------------------------
imp_mex_sec_cap <- imp_mex_sec_cap |>
  group_by(Capítulo) |>
  arrange(fecha, .by_group = TRUE) |>
  mutate(
    Val_mes_sa = tryCatch(
      sa_adj(Val_mes, fecha),
      error = function(e) {
        message("  SA failed for Capítulo ", first(Capítulo), " — returning unadjusted values. Reason: ", conditionMessage(e))
        Val_mes
      }
    )
  ) |>
  ungroup()

# — Verificación de NAs en columnas clave ------------------------------------
nas_sección  <- sum(is.na(imp_mex_sec_cap$Sección))
nas_cap_desc <- sum(is.na(imp_mex_sec_cap$Cap_corto))

cat("\nNAs en 'Sección':     ", nas_sección,  "\n")
cat("NAs en 'Cap_corto':", nas_cap_desc, "\n")

if (nas_sección > 0 | nas_cap_desc > 0) {
  message("  ⚠️  Capítulos sin correspondencia en las tablas de referencia:")
  imp_mex_sec_cap |>
    filter(is.na(Sección) | is.na(Cap_corto)) |>
    distinct(Capítulo, Cap_desc_api) |>
    print()
}

# — Verificación de consistencia: suma de Capítulos vs. imp_por_pais ----------
if (!exists("imp_por_pais")) {
  rds_path <- here("RDS", "imp_por_pais.rds")
  if (file.exists(rds_path)) {
    imp_por_pais <- readRDS(rds_path)
    message("  imp_por_pais cargado desde RDS.")
  } else {
    message("  ⚠️  imp_por_pais no encontrado. Se omite la verificación de consistencia.")
    imp_por_pais <- NULL
  }
}

if (!is.null(imp_por_pais)) {
  
  fechas_comunes <- intersect(
    unique(imp_mex_sec_cap$fecha),
    unique(imp_por_pais$fecha)
  )
  
  total_caps <- imp_mex_sec_cap |>
    filter(fecha %in% fechas_comunes) |>
    group_by(fecha) |>
    summarise(suma_caps = sum(Val_mes, na.rm = TRUE), .groups = "drop")
  
  total_q1 <- imp_por_pais |>
    filter(fecha %in% fechas_comunes, iso3 == "MEX") |>
    select(fecha, val_q1 = Imp_mes)
  
  verificación <- left_join(total_caps, total_q1, by = "fecha") |>
    mutate(diferencia = suma_caps - val_q1,
           dif_pct    = diferencia / val_q1 * 100)
  
  cat("\n=== Verificación de consistencia: suma de Capítulos vs. imp_por_pais ===\n")
  cat("Fechas comparadas:       ", length(fechas_comunes), "\n")
  cat("Diferencia máxima (USD): ", comma(max(abs(verificación$diferencia), na.rm = TRUE)), "\n")
  cat("Diferencia máxima (%):   ", round(max(abs(verificación$dif_pct),    na.rm = TRUE), 4), "\n")
  
  if (max(abs(verificación$diferencia), na.rm = TRUE) == 0) {
    cat("✔  Las sumas coinciden exactamente con imp_por_pais en todos los meses.\n")
  } else {
    cat("⚠️  Existen discrepancias. Revisar el objeto 'verificación' para el detalle.\n")
    verificación |>
      filter(abs(diferencia) > 0) |>
      print()
  }
}

# — Metadatos -----------------------------------------------------------------
meta_imp_mex_sec_cap <- list(
  fuente         = "US Census Bureau — International Trade API",
  endpoint       = "timeseries/intltrade/imports/hs",
  url            = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga = Sys.time(),
  país_origen    = "México (CTY_CODE = 2010)",
  nivel          = "Capítulo SA (2 dígitos); Sección derivada por agrupación",
  período        = paste(range(imp_mex_sec_cap$fecha), collapse = " – "),
  notas          = "Val_mes y Val_acum en dólares corrientes.
                    Sección_corto y Cap_corto: nombres cortos de RDS/hs_dictionary.rds
                    (fuente única; editar en Excel/hs_nombres_cortos.csv).
                    Cap_desc_api: nombre devuelto por el API en inglés (referencia).
                    Capítulos 98-99 incluidos (provisiones especiales EUA).
                    Variables descriptivas de texto almacenadas como factores ordenados
                    según el orden natural del SA (Secciones I–XXI; Capítulos 1–99).
                    No incluye filas de totales agregados; calcular con group_by()."
)

# — Guardar -------------------------------------------------------------------
saveRDS(imp_mex_sec_cap,      here("RDS", "imp_mex_sec_cap.rds"))
saveRDS(meta_imp_mex_sec_cap, here("RDS", "meta_imp_mex_sec_cap.rds"))

cat("\nListo. Filas:", nrow(imp_mex_sec_cap),
    "\nGuardado en: RDS/imp_mex_sec_cap.rds\n")