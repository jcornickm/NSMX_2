# ==============================================================================
# Query3_USA_Imp_Mex_raw.R
# Importaciones de EUA provenientes de México — descarga raw, todos los niveles HS
# Fuente: US Census Bureau — International Trade API
# Período: 2010–2025
# =============================================================================

# NOTAS SOBRE EL API
# • COMM_LVL omitido intencionalmente. La combinación CTY_CODE + COMM_LVL
#   genera error del servidor para HS4 y HS6 (confirmado abril 2026).
#   Sin COMM_LVL, el API devuelve todos los niveles mezclados en I_COMMODITY:
#     nchar == 1-2  →  total ("-") y Capítulo (HS2)
#     nchar == 4    →  Partida (HS4)
#     nchar == 6    →  Subpartida (HS6)
#     nchar == 10   →  Schedule B (10 dígitos)
#   Se separan en el script de procesamiento por nchar(I_COMMODITY).
# • CTY_CODE = "2010" corresponde a México.
# • Se itera año por año — el API falla con rangos largos.
# • Cada año se guarda inmediatamente como RDS individual para proteger
#   el progreso ante fallos de conexión.


pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse,
               here, janitor, censusapi, scales)

# — Clave del API -------------------------------------------------------------
api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("CENSUS_API_KEY no encontrado" = nchar(api_key) > 0)

dir.create(here("RDS", "raw"), recursive = TRUE, showWarnings = FALSE)


# ============================================================================
# DESCARGA ÚNICA: todos los niveles de agregación, México → EUA
# ============================================================================
# Se omite COMM_LVL intencionalmente — ver notas del API arriba.
# El resultado incluye HS2, HS4, HS6 y Schedule B (10 dígitos) mezclados.
# Se separará por nchar(I_COMMODITY) en la limpieza.

descargar_año <- function(año) {
  message("  Año: ", año)
  tryCatch({
    resultado <- getCensus(
      name     = "timeseries/intltrade/imports/hs",
      vars     = c("I_COMMODITY",
                   "I_COMMODITY_LDESC",
                   "GEN_VAL_MO",
                   "GEN_VAL_YR"),
      time     = paste0("from ", año, " to ", año),
      key      = api_key,
      CTY_CODE = "2010"
      
    )
    # Guardar inmediatamente
    saveRDS(resultado, here("RDS", "raw", paste0("raw_hs6_", año, ".rds")))
    message("  Guardado: raw_hs6_", año, ".rds")
    resultado
  }, error = function(e) {
    message("  ERROR en año ", año, ": ", conditionMessage(e))
    NULL
  })
}

años               <- 2025:2025

message("\n=== Descargando datos — México → EUA ) ===")

# ===========================================================================
# ENSAMBLAR EN UN UNICO ARCHIVO CON TODOS LOS AÑOS
# ==========================================================================

raw_list <- map(2010:2025, ~ readRDS(here("RDS", "raw", paste0("raw_hs6_", .x, ".rds"))))

raw_df <- raw_list |>
  compact() |>
  bind_rows() |>
  as_tibble() |>
  mutate(
    fecha   = as.Date(paste0(time, "-01")),
    cod     = as.character(I_COMMODITY),
    nivel   = case_when(
      cod == "-"        ~ "total",
      nchar(cod) == 2   ~ "HS2",
      nchar(cod) == 4   ~ "HS4",
      nchar(cod) == 6   ~ "HS6",
      nchar(cod) == 10  ~ "HS10"
    ),
    Val_mes  = as.numeric(GEN_VAL_MO),
    Val_acum = as.numeric(GEN_VAL_YR)
  )



# Distribución de niveles recibidos (diagnóstico)
cat("\nDistribución de longitudes de código (capítulos seleccionados):\n")
raw_df |> count(n_dig) |> print()

# ============================================================================
# BLOQUE 1: Partidas (HS4) — códigos de 4 dígitos
# ============================================================================

message("\n=== Construyendo objeto HS4 ===")

imp_mex_hs4 <- raw_df |>
  filter(n_dig == 4) |>
  left_join(caps_es, by = "Capítulo") |>
  mutate(
    Cap_corto   = factor(Cap_corto,   levels = caps_es$Cap_corto),
    Cap_desc_es = factor(Cap_desc_es, levels = caps_es$Cap_desc_es),
    Partida_desc = I_COMMODITY_LDESC
  ) |>
  select(
    fecha,
    Capítulo,
    Cap_corto,
    Cap_desc_es,
    cod_hs4      = cod,
    Partida_desc,
    Val_mes,
    Val_acum
  ) |>
  arrange(fecha, Capítulo, cod_hs4)

# Verificación: partidas por capítulo
cat("\nPartidas por Capítulo (HS4):\n")
imp_mex_hs4 |>
  distinct(Capítulo, cod_hs4) |>
  count(Capítulo, name = "n_partidas") |>
  left_join(caps_es, by = "Capítulo") |>
  select(Capítulo, Cap_corto, n_partidas) |>
  print()

cat("\nFilas en imp_mex_hs4:", nrow(imp_mex_hs4), "\n")

# ============================================================================
# BLOQUE 2: Subpartidas (HS6) — códigos de 6 dígitos
# ============================================================================

message("\n=== Construyendo objeto HS6 ===")

imp_mex_hs6 <- raw_df |>
  filter(n_dig == 6) |>
  left_join(caps_es, by = "Capítulo") |>
  mutate(
    Cap_corto      = factor(Cap_corto,   levels = caps_es$Cap_corto),
    Cap_desc_es    = factor(Cap_desc_es, levels = caps_es$Cap_desc_es),
    Subpartida_desc = I_COMMODITY_LDESC,
    cod_hs4        = substr(cod, 1, 4)   # Partida padre
  ) |>
  select(
    fecha,
    Capítulo,
    Cap_corto,
    Cap_desc_es,
    cod_hs4,
    cod_hs6         = cod,
    Subpartida_desc,
    Val_mes,
    Val_acum
  ) |>
  arrange(fecha, Capítulo, cod_hs6)

# Verificación: subpartidas por capítulo
cat("\nSubpartidas por Capítulo (HS6):\n")
imp_mex_hs6 |>
  distinct(Capítulo, cod_hs6) |>
  count(Capítulo, name = "n_subpartidas") |>
  left_join(caps_es, by = "Capítulo") |>
  select(Capítulo, Cap_corto, n_subpartidas) |>
  print()

cat("\nFilas en imp_mex_hs6:", nrow(imp_mex_hs6), "\n")

# ============================================================================
# VERIFICACIÓN DE CONSISTENCIA: HS4 vs. imp_mex_sec_cap (Query 2)
# ============================================================================

rds_sec_cap <- here("RDS", "imp_mex_sec_cap.rds")

if (file.exists(rds_sec_cap)) {
  
  imp_mex_sec_cap <- readRDS(rds_sec_cap)
  
  fechas_comunes <- intersect(
    unique(imp_mex_hs4$fecha),
    unique(imp_mex_sec_cap$fecha)
  )
  
  suma_hs4 <- imp_mex_hs4 |>
    filter(fecha %in% fechas_comunes) |>
    group_by(fecha, Capítulo) |>
    summarise(suma_partidas = sum(Val_mes, na.rm = TRUE), .groups = "drop")
  
  suma_cap <- imp_mex_sec_cap |>
    filter(fecha %in% fechas_comunes,
           Capítulo %in% caps_seleccionados) |>
    select(fecha, Capítulo, Val_cap = Val_mes)
  
  verif_hs4 <- left_join(suma_hs4, suma_cap, by = c("fecha", "Capítulo")) |>
    mutate(
      diferencia = suma_partidas - Val_cap,
      dif_pct    = diferencia / Val_cap * 100
    )
  
  cat("\n=== Verificación HS4 vs. Query2 (imp_mex_sec_cap) ===\n")
  cat("Diferencia máxima (USD):",
      scales::comma(max(abs(verif_hs4$diferencia), na.rm = TRUE)), "\n")
  cat("Diferencia máxima (%)  :",
      round(max(abs(verif_hs4$dif_pct), na.rm = TRUE), 4), "\n")
  
  if (max(abs(verif_hs4$diferencia), na.rm = TRUE) == 0) {
    cat("✔  Las sumas de Partidas coinciden exactamente con imp_mex_sec_cap.\n")
  } else {
    cat("⚠️  Existen discrepancias — revisar 'verif_hs4' para el detalle.\n")
  }
  
} else {
  message("  imp_mex_sec_cap.rds no encontrado — se omite verificación de consistencia.")
}

# ============================================================================
# METADATOS
# ============================================================================

meta_query3 <- list(
  fuente         = "US Census Bureau — International Trade API",
  endpoint       = "timeseries/intltrade/imports/hs",
  url            = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga = Sys.time(),
  país_origen    = "México (CTY_CODE = 2010)",
  capítulos      = "84 (Maquinaria), 85 (Eléctrico), 87 (Automóviles), 90 (Óptica)",
  nivel_hs4      = "Partida (4 dígitos) — filtrado por nchar(I_COMMODITY) == 4",
  nivel_hs6      = "Subpartida (6 dígitos) — filtrado por nchar(I_COMMODITY) == 6",
  período        = paste(range(imp_mex_hs4$fecha), collapse = " – "),
  años_con_error = if (length(años_fail) > 0) paste(años_fail, collapse = ", ") else "ninguno",
  notas          = "COMM_LVL omitido intencionalmente: la combinación CTY_CODE + COMM_LVL='HS4'
                    devuelve error del servidor (confirmado abril 2026). El API devuelve todos
                    los niveles mezclados cuando COMM_LVL se omite; se extrae HS4 y HS6
                    filtrando por nchar(I_COMMODITY). Val_mes y Val_acum en dólares corrientes.
                    No incluye filas de totales; calcular con group_by()."
)

# ============================================================================
# GUARDAR
# ============================================================================

saveRDS(imp_mex_hs4,  here("RDS", "imp_mex_hs4.rds"))
saveRDS(imp_mex_hs6,  here("RDS", "imp_mex_hs6.rds"))
saveRDS(meta_query3,  here("RDS", "meta_query3.rds"))

cat("\n✔  imp_mex_hs4.rds guardado.  Filas:", nrow(imp_mex_hs4), "\n")
cat("✔  imp_mex_hs6.rds guardado.  Filas:", nrow(imp_mex_hs6), "\n")
cat("✔  meta_query3.rds guardado.\n")