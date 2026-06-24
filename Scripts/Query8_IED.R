# ============================================================================
# Query8_IED.R
#
# Objetivo: ingestar los archivos Excel de IED publicados por la Secretaría
#   de Economía y producir cinco RDS en formato tidy.
#
# Fuente:
#   Inversión Extranjera Directa | Secretaría de Economía
#   https://www.gob.mx/se/acciones-y-programas/competitividad-y-normatividad-
#   inversion-extranjera-directa
#   Información al 31 de diciembre de 2025.
#
# Archivos de entrada (carpeta Excel/):
#   IED_flujos.xlsx   → hojas: Por origen, Por actividad económica,
#                               Por tipo de inversión
#   IED_PIB_6.xlsx    → hojas: IED_PIB_Trimestral, IED_PIB_Anual
#   IED_FBKF_7.xlsx   → hojas: IED_FBKF_Trimestral, IED_FBKF_Anual
#
# RDS producidos (carpeta RDS/):
#   ied_por_origen.rds
#   ied_por_actividad.rds
#   ied_pib.rds
#   ied_fbkf.rds
#   ied_flujos_tipo.rds
#
# Convenciones de fecha:
#   Variable `fecha` = primer día del trimestre (Date)
#   Variable `año`   = integer
#   Variable `trim`  = integer 1-4
#
# Valores especiales en flujos:
#   "C"  → NA_real_  (suprimido por confidencialidad)
#   "0"  → 0         (cero real)
#
# ============================================================================

pacman::p_load(tidyverse, readxl, here, lubridate)

# Rutas de entrada
ruta_flujos <- here("Excel", "IED_flujos.xlsx")
ruta_pib    <- here("Excel", "IED_PIB_6.xlsx")
ruta_fbkf   <- here("Excel", "IED_FBKF_7.xlsx")

stopifnot(
  "IED_flujos.xlsx no encontrado"  = file.exists(ruta_flujos),
  "IED_PIB_6.xlsx no encontrado"   = file.exists(ruta_pib),
  "IED_FBKF_7.xlsx no encontrado"  = file.exists(ruta_fbkf)
)

# Función auxiliar: convierte año + trimestre (1-4) a fecha (primer día)
trim_a_fecha <- function(año, trim) {
  mes <- c(1L, 4L, 7L, 10L)[trim]
  ymd(paste0(año, "-", str_pad(mes, 2, pad = "0"), "-01"))
}

# Función auxiliar: parsea columna de valores de flujos (puede contener "C")
parse_flujos <- function(x) {
  suppressWarnings(
    case_when(
      x == "C" ~ NA_real_,
      TRUE      ~ as.numeric(x)
    )
  )
}

# ============================================================================
# PARTE 1 — ied_por_origen
# ============================================================================
# Hoja "Por origen" de IED_flujos.xlsx
# Estructura:
#   Fila 0:  título (ignorar)
#   Fila 2:  años (cada 4 columnas, empezando en col 1)
#   Fila 3:  trimestres 1-4 (repetidos)
#   Fila 4+: datos. Col 0 = país ("Origen").
#   Fila 4 = "Total general" (mantener para poder filtrar)
# ============================================================================

message("\n── Parte 1: ied_por_origen ─────────────────────────────────────────────────")

raw_origen <- read_excel(
  ruta_flujos,
  sheet     = "Por origen",
  col_names = FALSE,
  col_types = "text"
)

# Reconstruir encabezados: años (fila 3 en R) + trimestres (fila 4 en R)
años_raw  <- as.character(raw_origen[3, ])
trims_raw <- as.character(raw_origen[4, ])

# Fill-forward de años (merged: el año aparece solo en la primera col del grupo)
años_ff <- tibble(x = ifelse(str_detect(años_raw, "^\\d{4}"), años_raw, NA_character_)) |>
  fill(x) |>
  pull(x)

# Nombres de columna compuestos
col_nombres    <- paste0(años_ff, "_T", trims_raw)
col_nombres[1] <- "origen"

# Extraer datos desde fila 5 en adelante
datos_origen <- raw_origen[5:nrow(raw_origen), ]
names(datos_origen) <- col_nombres

# Eliminar filas de notas al pie
datos_origen <- datos_origen |>
  filter(
    !is.na(origen),
    !str_detect(origen, "^\\*/|^Fuente|^Nota")
  )

# Pivot a formato largo
ied_por_origen <- datos_origen |>
  pivot_longer(
    cols      = -origen,
    names_to  = c("año", "trim"),
    names_sep = "_T",
    values_to = "ied_mdd"
  ) |>
  mutate(
    año     = as.integer(año),
    trim    = as.integer(trim),
    ied_mdd = parse_flujos(ied_mdd),
    fecha   = trim_a_fecha(año, trim)
  ) |>
  filter(!is.na(año), !is.na(trim)) |>
  select(origen, año, trim, fecha, ied_mdd) |>
  arrange(origen, fecha)

message("Filas: ",             nrow(ied_por_origen))
message("Países/orígenes: ",   n_distinct(ied_por_origen$origen))
message("Rango temporal: ",    min(ied_por_origen$fecha), " → ", max(ied_por_origen$fecha))
message("NAs (supresión C): ", sum(is.na(ied_por_origen$ied_mdd)))

saveRDS(ied_por_origen, here("RDS", "ied_por_origen.rds"))
message("✓ Guardado: RDS/ied_por_origen.rds")


# ============================================================================
# PARTE 2 — ied_por_actividad
# ============================================================================
# Hoja "Por actividad económica" de IED_flujos.xlsx
# Estructura idéntica a Por origen salvo que:
#   - Col 0 = "Actividad Económica (sector, subsector y rama)"
#   - El código SCIAN va embebido al inicio del texto:
#       "11 Agricultura..."   → sector    (2 dígitos)
#       "111 Agricultura"     → subsector (3 dígitos)
#       "1111 Cultivo de..."  → rama      (4 dígitos)
#     "Total general" no tiene código → nivel = "total"
# ============================================================================

message("\n── Parte 2: ied_por_actividad ──────────────────────────────────────────────")

raw_act <- read_excel(
  ruta_flujos,
  sheet     = "Por actividad económica",
  col_names = FALSE,
  col_types = "text"
)

# Encabezados (misma lógica que Parte 1)
años_raw  <- as.character(raw_act[3, ])
trims_raw <- as.character(raw_act[4, ])

años_ff <- tibble(x = ifelse(str_detect(años_raw, "^\\d{4}"), años_raw, NA_character_)) |>
  fill(x) |>
  pull(x)

col_nombres    <- paste0(años_ff, "_T", trims_raw)
col_nombres[1] <- "actividad"

datos_act <- raw_act[5:nrow(raw_act), ]
names(datos_act) <- col_nombres

datos_act <- datos_act |>
  filter(
    !is.na(actividad),
    !str_detect(actividad, "^\\*/|^Fuente|^Nota|^Clasificación")
  )

# Extraer código SCIAN y nivel jerárquico
datos_act <- datos_act |>
  mutate(
    codigo_scian = str_extract(actividad, "^\\d+"),
    nivel = case_when(
      is.na(codigo_scian)          ~ "total",
      nchar(codigo_scian) == 2L    ~ "sector",
      nchar(codigo_scian) == 3L    ~ "subsector",
      nchar(codigo_scian) == 4L    ~ "rama",
      TRUE                         ~ "otro"
    ),
    descripcion = str_trim(str_remove(actividad, "^\\d+\\s*"))
  )

# Pivot a formato largo
ied_por_actividad <- datos_act |>
  pivot_longer(
    cols      = starts_with("20"),
    names_to  = c("año", "trim"),
    names_sep = "_T",
    values_to = "ied_mdd"
  ) |>
  mutate(
    año     = as.integer(año),
    trim    = as.integer(trim),
    ied_mdd = parse_flujos(ied_mdd),
    fecha   = trim_a_fecha(año, trim)
  ) |>
  filter(!is.na(año), !is.na(trim)) |>
  select(codigo_scian, nivel, descripcion, año, trim, fecha, ied_mdd) |>
  arrange(nivel, codigo_scian, fecha)

message("Filas: ",              nrow(ied_por_actividad))
message("Actividades únicas: ", n_distinct(ied_por_actividad$descripcion))
message("Niveles: ",            paste(sort(unique(ied_por_actividad$nivel)), collapse = ", "))
message("Rango temporal: ",     min(ied_por_actividad$fecha), " → ", max(ied_por_actividad$fecha))
message("NAs (supresión C): ",  sum(is.na(ied_por_actividad$ied_mdd)))

saveRDS(ied_por_actividad, here("RDS", "ied_por_actividad.rds"))
message("✓ Guardado: RDS/ied_por_actividad.rds")

# ============================================================================
# PARTE 3 — ied_pib
# ============================================================================
# IED_PIB_6.xlsx — hojas IED_PIB_Trimestral e IED_PIB_Anual
# Estructura:
#   Filas 0-5: título y encabezados (ignorar)
#   Fila 6:    unidades (ignorar)
#   Fila 7+:   datos
#   Col trimestral: Año | Trimestre | IED (MDD) | PIB (MDD) | IED/PIB (%)
#   Col anual:      Año | IED (MDD) | PIB (MDD) | IED/PIB (%)
#   Trimestres como romano: "I","II","III","IV" → 1,2,3,4
#   El año aparece solo en la primera fila de cada grupo → fill-down
# ============================================================================

message("\n── Parte 3: ied_pib ────────────────────────────────────────────────────────")

trim_romano <- c("I" = 1L, "II" = 2L, "III" = 3L, "IV" = 4L)

# ── 3a. Hoja trimestral ──────────────────────────────────────────────────────
pib_trim_raw <- read_excel(
  ruta_pib,
  sheet     = "IED_PIB_Trimestral",
  col_names = FALSE,
  col_types = "text",
  skip      = 6
)

pib_trim <- pib_trim_raw |>
  select(año = 1, trim_rom = 2, ied_mdd = 3, pib_mdd = 4, ied_pib_pct = 5) |>
  filter(!is.na(trim_rom), trim_rom %in% names(trim_romano)) |>
  mutate(
    año         = na_if(año, "NA"),
    año         = suppressWarnings(as.integer(año))
  ) |>
  fill(año) |>
  mutate(
    trim        = trim_romano[trim_rom],
    ied_mdd     = as.numeric(ied_mdd),
    pib_mdd     = as.numeric(pib_mdd),
    ied_pib_pct = as.numeric(ied_pib_pct),
    fecha       = trim_a_fecha(año, trim),
    frecuencia  = "trimestral"
  ) |>
  select(frecuencia, año, trim, fecha, ied_mdd, pib_mdd, ied_pib_pct)

# ── 3b. Hoja anual ───────────────────────────────────────────────────────────
pib_anual_raw <- read_excel(
  ruta_pib,
  sheet     = "IED_PIB_Anual",
  col_names = FALSE,
  col_types = "text",
  skip      = 6
)

pib_anual <- pib_anual_raw |>
  select(año = 1, ied_mdd = 2, pib_mdd = 3, ied_pib_pct = 4) |>
  filter(!is.na(año), suppressWarnings(!is.na(as.integer(año)))) |>
  mutate(
    año         = as.integer(año),
    ied_mdd     = as.numeric(ied_mdd),
    pib_mdd     = as.numeric(pib_mdd),
    ied_pib_pct = as.numeric(ied_pib_pct),
    trim        = NA_integer_,
    fecha       = ymd(paste0(año, "-01-01")),
    frecuencia  = "anual"
  ) |>
  select(frecuencia, año, trim, fecha, ied_mdd, pib_mdd, ied_pib_pct)

# ── 3c. Combinar ─────────────────────────────────────────────────────────────
ied_pib <- bind_rows(pib_trim, pib_anual) |>
  arrange(frecuencia, fecha)

message("Filas trimestral: ", nrow(pib_trim))
message("Filas anual: ",      nrow(pib_anual))
message("Rango trimestral: ", min(pib_trim$fecha), " → ", max(pib_trim$fecha))
message("Rango anual: ",      min(pib_anual$fecha), " → ", max(pib_anual$fecha))

saveRDS(ied_pib, here("RDS", "ied_pib.rds"))
message("✓ Guardado: RDS/ied_pib.rds")


# ============================================================================
# PARTE 4 — ied_fbkf
# ============================================================================
# IED_FBKF_7.xlsx — hojas IED_FBKF_Trimestral e IED_FBKF_Anual
# Estructura idéntica a IED_PIB_6.xlsx salvo que la tercera variable
# es FBKF (Formación Bruta de Capital Fijo) en lugar de PIB.
# ============================================================================

message("\n── Parte 4: ied_fbkf ───────────────────────────────────────────────────────")

# ── 4a. Hoja trimestral ──────────────────────────────────────────────────────
fbkf_trim_raw <- read_excel(
  ruta_fbkf,
  sheet     = "IED_FBKF_Trimestral",
  col_names = FALSE,
  col_types = "text",
  skip      = 6
)

fbkf_trim <- fbkf_trim_raw |>
  select(año = 1, trim_rom = 2, ied_mdd = 3, fbkf_mdd = 4, ied_fbkf_pct = 5) |>
  filter(!is.na(trim_rom), trim_rom %in% names(trim_romano)) |>
  mutate(
    año  = na_if(año, "NA"),
    año  = suppressWarnings(as.integer(año))
  ) |>
  fill(año) |>
  mutate(
    trim         = trim_romano[trim_rom],
    ied_mdd      = as.numeric(ied_mdd),
    fbkf_mdd     = as.numeric(fbkf_mdd),
    ied_fbkf_pct = as.numeric(ied_fbkf_pct),
    fecha        = trim_a_fecha(año, trim),
    frecuencia   = "trimestral"
  ) |>
  select(frecuencia, año, trim, fecha, ied_mdd, fbkf_mdd, ied_fbkf_pct)

# ── 4b. Hoja anual ───────────────────────────────────────────────────────────
fbkf_anual_raw <- read_excel(
  ruta_fbkf,
  sheet     = "IED_FBKF_Anual",
  col_names = FALSE,
  col_types = "text",
  skip      = 6
)

fbkf_anual <- fbkf_anual_raw |>
  select(año = 1, ied_mdd = 2, fbkf_mdd = 3, ied_fbkf_pct = 4) |>
  filter(!is.na(año), suppressWarnings(!is.na(as.integer(año)))) |>
  mutate(
    año          = as.integer(año),
    ied_mdd      = as.numeric(ied_mdd),
    fbkf_mdd     = as.numeric(fbkf_mdd),
    ied_fbkf_pct = as.numeric(ied_fbkf_pct),
    trim         = NA_integer_,
    fecha        = ymd(paste0(año, "-01-01")),
    frecuencia   = "anual"
  ) |>
  select(frecuencia, año, trim, fecha, ied_mdd, fbkf_mdd, ied_fbkf_pct)

# ── 4c. Combinar ─────────────────────────────────────────────────────────────
ied_fbkf <- bind_rows(fbkf_trim, fbkf_anual) |>
  arrange(frecuencia, fecha)

message("Filas trimestral: ", nrow(fbkf_trim))
message("Filas anual: ",      nrow(fbkf_anual))
message("Rango trimestral: ", min(fbkf_trim$fecha), " → ", max(fbkf_trim$fecha))
message("Rango anual: ",      min(fbkf_anual$fecha), " → ", max(fbkf_anual$fecha))

saveRDS(ied_fbkf, here("RDS", "ied_fbkf.rds"))
message("✓ Guardado: RDS/ied_fbkf.rds")

# ============================================================================
# PARTE 5 — ied_flujos_tipo
# ============================================================================
# Hoja "Por tipo de inversión" de IED_flujos.xlsx
# Estructura idéntica a Por origen salvo que solo hay 3 categorías:
#   Total general
#   Nuevas inversiones
#   Reinversión de utilidades
#   Cuentas entre compañías
# ============================================================================

message("\n── Parte 5: ied_flujos_tipo ────────────────────────────────────────────────")

raw_tipo <- read_excel(
  ruta_flujos,
  sheet     = "Por tipo de inversión",
  col_names = FALSE,
  col_types = "text"
)

# Encabezados (misma lógica que Partes 1 y 2)
años_raw  <- as.character(raw_tipo[3, ])
trims_raw <- as.character(raw_tipo[4, ])

años_ff <- tibble(x = ifelse(str_detect(años_raw, "^\\d{4}"), años_raw, NA_character_)) |>
  fill(x) |>
  pull(x)

col_nombres    <- paste0(años_ff, "_T", trims_raw)
col_nombres[1] <- "tipo"

datos_tipo <- raw_tipo[5:nrow(raw_tipo), ]
names(datos_tipo) <- col_nombres

datos_tipo <- datos_tipo |>
  filter(
    !is.na(tipo),
    !str_detect(tipo, "^\\*/|^Fuente|^Nota")
  )

# Pivot a formato largo
ied_flujos_tipo <- datos_tipo |>
  pivot_longer(
    cols      = starts_with("20"),
    names_to  = c("año", "trim"),
    names_sep = "_T",
    values_to = "ied_mdd"
  ) |>
  mutate(
    año     = as.integer(año),
    trim    = as.integer(trim),
    ied_mdd = parse_flujos(ied_mdd),
    fecha   = trim_a_fecha(año, trim)
  ) |>
  filter(!is.na(año), !is.na(trim)) |>
  select(tipo, año, trim, fecha, ied_mdd) |>
  arrange(tipo, fecha)

message("Filas: ",       nrow(ied_flujos_tipo))
message("Tipos: ",       paste(unique(ied_flujos_tipo$tipo), collapse = " | "))
message("Rango: ",       min(ied_flujos_tipo$fecha), " → ", max(ied_flujos_tipo$fecha))
message("NAs (C): ",     sum(is.na(ied_flujos_tipo$ied_mdd)))

saveRDS(ied_flujos_tipo, here("RDS", "ied_flujos_tipo.rds"))
message("✓ Guardado: RDS/ied_flujos_tipo.rds")

message("\n══ Query8_IED.R completado — 5 RDS guardados en RDS/ ══════════════════════")

meta_ied <- list(
  fuente         = "Secretaría de Economía — Inversión Extranjera Directa",
  url            = "https://www.gob.mx/se/acciones-y-programas/competitividad-y-normatividad-inversion-extranjera-directa",
  fecha_descarga = Sys.Date(),
  cobertura      = "1999–2025 (datos al 31 de diciembre de 2025)",
  archivos_fuente = c("IED_flujos.xlsx", "IED_PIB_6.xlsx", "IED_FBKF_7.xlsx"),
  rds_producidos = c(
    "ied_por_origen.rds",
    "ied_por_actividad.rds",
    "ied_pib.rds",
    "ied_fbkf.rds",
    "ied_flujos_tipo.rds"
  ),
  unidades       = "Miles de millones de dólares (MDD); IED/PIB en porcentaje",
  notas          = "Valores 'C' → NA_real_ (supresión por confidencialidad).
                    Frecuencia mixta: trimestral y anual según hoja de origen."
)

saveRDS(meta_ied, here("RDS", "meta_ied.rds"))
message("✓ Guardado: RDS/meta_ied.rds")
        