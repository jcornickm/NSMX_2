# ============================================================================
# Query6_ETEF_procesamiento.R
#
# Objetivo: leer ETEF_Entidad_Subsector.xlsx del INEGI y producir un
#   tibble tidy guardado como RDS con exportaciones por entidad fedrativa y sector
#
# Estructura verificada del archivo:
#   Fila 1-3: título, rango, unidad
#   Fila 4:   vacía
#   Fila 5:   col 0-1 = "Código"/"Descripción"; luego años en col 2, 7, 12...
#             (patrón: 4 trimestres + 1 col vacía separadora = 5 cols por año)
#             Años con sufijos: "2018 R/" (revisado), "2025 P/" (preliminar)
#   Fila 6:   trimestres "I","II","III","IV" alineados bajo cada año
#   Fila 7:   Exportaciones totales (código = NA, es_total = TRUE)
#   Filas 8-34: subsectores SCIAN
#   Fila 34:  "Subsectores no especificados" (código = NA)
#   Filas 35+: notas — excluir
#
# Valores especiales:
#   "-"  → NA (no aplica / sin información)
#   "C"  → NA (suprimido por confidencialidad)
#   "0"  → 0  (cero real: no hubo exportaciones)
#
# Salida: RDS/etef_tidy.rds
# ============================================================================

pacman::p_load(tidyverse, readxl, here, janitor)

# ── 0. Rutas ------------------------------------------------------------------

ruta_xlsx   <- here("Excel", "ETEF_Entidad_Subsector.xlsx")
ruta_salida <- here("RDS", "etef_tidy.rds")
ruta_meta   <- here("RDS", "meta_etef.rds")

stopifnot("Archivo ETEF no encontrado" = file.exists(ruta_xlsx))

hojas <- excel_sheets(ruta_xlsx)
message("Hojas: ", length(hojas), " entidades")

# ── 1. Función para procesar una hoja ----------------------------------------

procesar_hoja <- function(nombre_hoja) {
  
  message("  ", nombre_hoja)
  
  # Leer todo como texto para preservar "C", "-", "0"
  raw <- read_excel(
    ruta_xlsx,
    sheet     = nombre_hoja,
    col_names = FALSE,
    col_types = "text"
  )
  
  # — 1a. Construir mapa de columnas (año × trimestre) -----------------------
  # Fila 5 (índice R = 5): años; Fila 6 (índice R = 6): trimestres
  fila_anos <- as.character(unlist(raw[5, ]))
  fila_trim <- as.character(unlist(raw[6, ]))
  
  # Limpiar sufijos de año: "2018 R/" → 2018, "2025 P/" → 2025
  anos_limpios <- str_extract(fila_anos, "\\d{4}") |> as.integer()
  
  # Forward-fill: el año aparece solo en la primera col del grupo
  for (i in seq_along(anos_limpios)) {
    if (is.na(anos_limpios[i]) && i > 1) {
      anos_limpios[i] <- anos_limpios[i - 1]
    }
  }
  
  trimestres_validos <- c("I", "II", "III", "IV")
  
  col_mapa <- tibble(
    col_idx   = seq_along(anos_limpios),
    año       = anos_limpios,
    trimestre = fila_trim
  ) |>
    filter(trimestre %in% trimestres_validos, !is.na(año))
  
  # — 1b. Identificar filas de datos ----------------------------------------
  # Datos: filas 7 en adelante (índice R = 7+)
  # Excluir desde la primera fila de notas (col A empieza con "Notas:" o "*")
  datos_raw <- raw[7:nrow(raw), ]
  
  col_a <- as.character(datos_raw[[1]])
  
  primera_nota <- which(
    str_detect(col_a, "^Notas:") |
      str_detect(col_a, "^\\* Las exportaciones") |
      str_detect(col_a, "^Fuente:")
  )[1]
  
  if (!is.na(primera_nota)) {
    datos_limpios <- datos_raw[1:(primera_nota - 1), ]
  } else {
    datos_limpios <- datos_raw
  }
  
  # — 1c. Ensamblar tibble largo --------------------------------------------
  map_dfr(seq_len(nrow(datos_limpios)), function(i) {
    
    fila     <- datos_limpios[i, ]
    cod_raw  <- as.character(fila[[1]])
    desc_raw <- as.character(fila[[2]])
    
    # Saltar filas completamente vacías
    if ((is.na(cod_raw) | cod_raw == "NA") &
        (is.na(desc_raw) | desc_raw == "NA")) return(NULL)
    
    # Código limpio (Excel agrega ".0" a enteros leídos como texto)
    codigo <- if (is.na(cod_raw) | cod_raw == "NA") {
      NA_character_
    } else {
      str_remove(cod_raw, "\\.0$")
    }
    
    desc <- if (is.na(desc_raw) | desc_raw == "NA") NA_character_ else str_trim(desc_raw)
    
    map_dfr(seq_len(nrow(col_mapa)), function(j) {
      ci      <- col_mapa$col_idx[j]
      val_raw <- as.character(fila[[ci]])
      if (is.na(val_raw) || val_raw == "NA") val_raw <- NA_character_
      
      tibble(
        entidad      = nombre_hoja,
        codigo_scian = codigo,
        desc_scian   = desc,
        año          = col_mapa$año[j],
        trimestre    = col_mapa$trimestre[j],
        val_raw      = val_raw
      )
    })
  })
}

# ── 2. Procesar todas las hojas ----------------------------------------------

message("\n=== Procesando las 32 entidades ===")
lista <- map(hojas, procesar_hoja)
names(lista) <- hojas

# ── 3. Combinar y clasificar valores ----------------------------------------

message("\n=== Limpiando y ensamblando ===")

etef_tidy <- lista |>
  compact() |>
  bind_rows() |>
  mutate(
    # Flags de valores especiales
    suprimido = !is.na(val_raw) & val_raw == "C",
    no_aplica = !is.na(val_raw) & val_raw == "-",
    
    # Valor numérico
    val_miles_usd = case_when(
      suprimido | no_aplica | is.na(val_raw) ~ NA_real_,
      TRUE ~ suppressWarnings(as.numeric(str_remove_all(val_raw, ",")))
    ),
    
    # Clasificar tipo de fila
    es_total = is.na(codigo_scian) &
      str_detect(str_to_lower(desc_scian), "exportaciones totales"),
    es_no_especificado = is.na(codigo_scian) &
      str_detect(str_to_lower(desc_scian), "subsectores no especificados"),
    
    # Trimestre como factor ordenado
    trimestre = factor(trimestre, levels = c("I","II","III","IV"), ordered = TRUE),
    
    # Fecha: primer día del trimestre (útil para joins temporales)
    mes_inicio = case_when(
      trimestre == "I"   ~ 1L,
      trimestre == "II"  ~ 4L,
      trimestre == "III" ~ 7L,
      trimestre == "IV"  ~ 10L
    ),
    fecha = as.Date(paste(año, mes_inicio, "01", sep = "-"))
  ) |>
  select(
    entidad, codigo_scian, desc_scian,
    es_total, es_no_especificado,
    año, trimestre, fecha,
    val_miles_usd, suprimido, no_aplica
  ) |>
  arrange(entidad, es_total, codigo_scian, año, trimestre)

cat("Filas totales:", nrow(etef_tidy), "\n")

# ── 4. Diagnóstico ----------------------------------------------------------

message("\n=== Diagnóstico ===")

cat("\nRango temporal:\n")
etef_tidy |>
  summarise(min_año = min(año), max_año = max(año)) |>
  print()

cat("\nSubsectores SCIAN presentes:\n")
etef_tidy |>
  filter(!es_total, !es_no_especificado, !is.na(codigo_scian)) |>
  distinct(codigo_scian, desc_scian) |>
  arrange(as.integer(codigo_scian)) |>
  print(n = 40)

cat("\nValores especiales (excluye totales y no-especificados):\n")
etef_tidy |>
  filter(!es_total, !es_no_especificado) |>
  summarise(
    n_obs          = n(),
    n_con_valor    = sum(!is.na(val_miles_usd)),
    n_suprimidos   = sum(suprimido),
    n_no_aplica    = sum(no_aplica),
    pct_suprimidos = round(mean(suprimido) * 100, 1),
    pct_no_aplica  = round(mean(no_aplica) * 100, 1)
  ) |>
  print()

# ── 5. Vista rápida: subsectores NS por entidad, 2024 -----------------------

cat("\nTop 10 entidades × subsector 336 (Transporte), 2024:\n")
etef_tidy |>
  filter(codigo_scian == "336", año == 2024, !is.na(val_miles_usd)) |>
  group_by(entidad) |>
  summarise(val_anual = sum(val_miles_usd), .groups = "drop") |>
  slice_max(val_anual, n = 10) |>
  mutate(val_anual = scales::comma(val_anual)) |>
  print()

cat("\nTop 10 entidades × subsector 334 (Electrónica), 2024:\n")
etef_tidy |>
  filter(codigo_scian == "334", año == 2024, !is.na(val_miles_usd)) |>
  group_by(entidad) |>
  summarise(val_anual = sum(val_miles_usd), .groups = "drop") |>
  slice_max(val_anual, n = 10) |>
  mutate(val_anual = scales::comma(val_anual)) |>
  print()

# ── 6. Metadatos y guardado -------------------------------------------------

meta_etef <- list(
  fuente         = "INEGI — Exportaciones Trimestrales por Entidad Federativa (ETEF)",
  url_fuente     = "https://www.inegi.org.mx/temas/exportacionesef/",
  archivo_origen = "ETEF_Entidad_Subsector.xlsx",
  fecha_proceso  = Sys.time(),
  clasificacion  = "SCIAN 2018",
  cobertura_geo  = "32 entidades federativas",
  unidad         = "Miles de dólares estadounidenses",
  frecuencia     = "Trimestral",
  periodo        = paste(range(etef_tidy$año), collapse = " – "),
  n_entidades    = n_distinct(etef_tidy$entidad),
  n_subsectores  = n_distinct(
    etef_tidy$codigo_scian[!etef_tidy$es_total & !etef_tidy$es_no_especificado],
    na.rm = TRUE
  ),
  notas = "
    suprimido = TRUE  : dato 'C' (confidencialidad estadística) → NA en val_miles_usd.
    no_aplica = TRUE  : dato '-' (sin información / no aplica)  → NA en val_miles_usd.
    El cero real (0) se preserva como 0 en val_miles_usd.
    es_total = TRUE   : fila de Exportaciones totales de la entidad.
    es_no_especificado: residual de datos suprimidos; incluido en el total ETEF.
    fecha             : primer día del trimestre (ene/abr/jul/oct).
    2018 publicado con sufijo 'R/' (revisado); 2025 con 'P/' (preliminar).
    Los sufijos se remueven; el año queda limpio en la columna 'año'.
    Asignación geográfica: entidad de ORIGEN de la producción (no aduana de salida).
    Subsectores NS relevantes: 333 (maquinaria), 334 (electrónica),
      335 (eléctrico), 336 (transporte).
  "
)

saveRDS(etef_tidy, ruta_salida)
saveRDS(meta_etef, ruta_meta)

message("\n✔  etef_tidy.rds  — ", nrow(etef_tidy), " filas")
message("✔  meta_etef.rds")
cat("Entidades: ", n_distinct(etef_tidy$entidad), "\n")
cat("Período:   ", paste(range(etef_tidy$año), collapse = " – "), "\n")
