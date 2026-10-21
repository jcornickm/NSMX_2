# Query08_IMMEX.R
# Empleo IMMEX segmento manufacturero por entidad federativa y Zona Libre
# de la Frontera Norte (ZLFN)
# Fuente: INEGI – Datos abiertos IMMEX
# https://www.inegi.org.mx/programas/immex/#datos_abiertos

pacman::p_load(tidyverse, here)

# ── 1. Municipios de la ZLFN presentes en el dataset ────────────────────────
# Fuente: Decreto ZLFN 2018 (DOF). Ensenada excluido: actividad IMMEX
# no es fronteriza en sentido estricto.
cvegeo_zlfn <- c(
  "02002",  # Mexicali,      BC
  "02003",  # Tecate,        BC
  "02004",  # Tijuana,       BC
  "05002",  # Acuña,         Coahuila
  "08037",  # Juárez,        Chihuahua
  "26043",  # Nogales,       Sonora
  "28022",  # Matamoros,     Tamaulipas
  "28027",  # Nuevo Laredo,  Tamaulipas
  "28032"   # Reynosa,       Tamaulipas
)

# ── 2. Leer todos los archivos anuales (2010–2026) ───────────────────────────
ruta_csv <- here::here("Excel", "IMMEX")

archivos <- list.files(
  path       = ruta_csv,
  pattern    = "\\.csv$",
  full.names = TRUE
)

immex_raw <- archivos |>
  map(\(f) read_csv(f, col_types = cols(
    CVEGEO  = col_character(),
    CVE_ENT = col_character(),
    CVE_MUN = col_character(),
    ESTATUS = col_character(),
    .default = col_integer()
  ))) |>
  bind_rows() |>
  filter(ANIO >= 2010)

# ── 3. Limpiar claves y calcular variables de empleo ────────────────────────
immex_emp <- immex_raw |>
  mutate(
    # Limpiar espacios en todas las claves de texto
    CVEGEO  = str_trim(CVEGEO),
    CVE_ENT = str_trim(CVE_ENT),
    CVE_MUN = str_trim(CVE_MUN),
    # Pad de dos dígitos solo para CVEGEO de estado (los municipales tienen 5)
    CVEGEO  = if_else(str_length(CVEGEO) < 5,
                      str_pad(CVEGEO, width = 2, side = "left", pad = "0"),
                      CVEGEO),
    # Variables de empleo
    emp_prod_directo = H114A,           # obreros propios
    emp_prod_externo = I400A,           # obreros subcontratados
    emp_prod_total   = H114A + I400A,
    emp_adm_directo  = H200A,           # admvos propios
    emp_adm_externo  = I500A,           # admvos subcontratados
    emp_adm_total    = H200A + I500A,
    emp_total        = H114A + I400A + H200A + I500A
  )

# ── 4. Catálogo de entidades (excluye BC — sin fila de total en fuente) ──────
cat_entidades <- tribble(
  ~CVE_ENT, ~nombre,               ~abrev,
  "01",     "Aguascalientes",       "AGS",
  "05",     "Coahuila",             "Coah.",
  "08",     "Chihuahua",            "Chih.",
  "09",     "Ciudad de México",     "CDMX",
  "10",     "Durango",              "Dgo.",
  "11",     "Guanajuato",           "Gto.",
  "14",     "Jalisco",              "Jal.",
  "15",     "Estado de México",     "Méx.",
  "19",     "Nuevo León",           "NL",
  "21",     "Puebla",               "Pue.",
  "22",     "Querétaro",            "Qro.",
  "24",     "San Luis Potosí",      "SLP",
  "26",     "Sonora",               "Son.",
  "28",     "Tamaulipas",           "Tamps.",
  "30",     "Veracruz",             "Ver.",
  "31",     "Yucatán",              "Yuc."
)

# ── 5. Agregado por entidad federativa (16 estados con fila propia en fuente) ─
immex_ef <- immex_emp |>
  filter(str_length(CVEGEO) == 2, CVE_ENT != "99") |>
  mutate(fecha = as.Date(paste(ANIO, ID_MES, "01", sep = "-"))) |>
  left_join(cat_entidades, by = "CVE_ENT") |>
  rename(año = ANIO) |>
  select(fecha, año, ID_MES, CVE_ENT, nombre, abrev,
         NUM_DE_ESTAB_ACT,
         emp_prod_directo, emp_prod_externo, emp_prod_total,
         emp_adm_directo,  emp_adm_externo,  emp_adm_total,
         emp_total, ESTATUS)

# Verificación: sin NAs en nombre tras el join
stopifnot("CVE_ENT sin nombre — revisar cat_entidades" =
            sum(is.na(immex_ef$nombre)) == 0)

# ── 6. BC: construir total estatal sumando sus cuatro municipios ─────────────
# INEGI no publica fila de total estatal para BC.
# Todos los municipios (incluido Ensenada 02001) se suman para el total estatal.
# Ensenada se excluye solo del agregado ZLFN (paso 7).
bc_ef <- immex_emp |>
  filter(CVE_ENT == "02", str_length(CVEGEO) == 5) |>
  group_by(ANIO, ID_MES) |>
  summarise(
    NUM_DE_ESTAB_ACT = sum(NUM_DE_ESTAB_ACT, na.rm = TRUE),
    emp_prod_directo = sum(emp_prod_directo, na.rm = TRUE),
    emp_prod_externo = sum(emp_prod_externo, na.rm = TRUE),
    emp_prod_total   = sum(emp_prod_total,   na.rm = TRUE),
    emp_adm_directo  = sum(emp_adm_directo,  na.rm = TRUE),
    emp_adm_externo  = sum(emp_adm_externo,  na.rm = TRUE),
    emp_adm_total    = sum(emp_adm_total,    na.rm = TRUE),
    emp_total        = sum(emp_total,        na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    fecha   = as.Date(paste(ANIO, ID_MES, "01", sep = "-")),
    CVE_ENT = "02",
    nombre  = "Baja California",
    abrev   = "BC",
    ESTATUS = NA_character_
  ) |>
  rename(año = ANIO) |>
  select(fecha, año, ID_MES, CVE_ENT, nombre, abrev,
         NUM_DE_ESTAB_ACT,
         emp_prod_directo, emp_prod_externo, emp_prod_total,
         emp_adm_directo,  emp_adm_externo,  emp_adm_total,
         emp_total, ESTATUS)

# ── 7. Agregado Zona Libre de la Frontera Norte ──────────────────────────────
# Ensenada (02001) excluida: su actividad IMMEX no es fronteriza en sentido estricto
immex_zlfn <- immex_emp |>
  filter(CVEGEO %in% cvegeo_zlfn) |>
  group_by(ANIO, ID_MES) |>
  summarise(
    NUM_DE_ESTAB_ACT = sum(NUM_DE_ESTAB_ACT, na.rm = TRUE),
    emp_prod_directo = sum(emp_prod_directo, na.rm = TRUE),
    emp_prod_externo = sum(emp_prod_externo, na.rm = TRUE),
    emp_prod_total   = sum(emp_prod_total,   na.rm = TRUE),
    emp_adm_directo  = sum(emp_adm_directo,  na.rm = TRUE),
    emp_adm_externo  = sum(emp_adm_externo,  na.rm = TRUE),
    emp_adm_total    = sum(emp_adm_total,    na.rm = TRUE),
    emp_total        = sum(emp_total,        na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    fecha   = as.Date(paste(ANIO, ID_MES, "01", sep = "-")),
    CVE_ENT = "ZLF",
    nombre  = "Zona Libre de la Frontera Norte",
    abrev   = "ZLFN",
    ESTATUS = NA_character_
  ) |>
  rename(año = ANIO) |>
  select(fecha, año, ID_MES, CVE_ENT, nombre, abrev,
         NUM_DE_ESTAB_ACT,
         emp_prod_directo, emp_prod_externo, emp_prod_total,
         emp_adm_directo,  emp_adm_externo,  emp_adm_total,
         emp_total, ESTATUS)

# ── 8. Total nacional (16 estados + BC; excluye ZLFN para evitar doble conteo) ─
immex_total_nacional <- bind_rows(immex_ef, bc_ef) |>
  group_by(fecha, año, ID_MES) |>
  summarise(
    CVE_ENT          = "TOT",
    nombre           = "Total nacional",
    abrev            = "Total",
    NUM_DE_ESTAB_ACT = sum(NUM_DE_ESTAB_ACT, na.rm = TRUE),
    emp_prod_directo = sum(emp_prod_directo, na.rm = TRUE),
    emp_prod_externo = sum(emp_prod_externo, na.rm = TRUE),
    emp_prod_total   = sum(emp_prod_total,   na.rm = TRUE),
    emp_adm_directo  = sum(emp_adm_directo,  na.rm = TRUE),
    emp_adm_externo  = sum(emp_adm_externo,  na.rm = TRUE),
    emp_adm_total    = sum(emp_adm_total,    na.rm = TRUE),
    emp_total        = sum(emp_total,        na.rm = TRUE),
    ESTATUS          = NA_character_,
    .groups          = "drop"
  )

# ── 9. Combinar todo en un solo objeto ───────────────────────────────────────
immex_empleo <- bind_rows(immex_ef, bc_ef, immex_zlfn, immex_total_nacional) |>
  arrange(fecha, CVE_ENT)

# ── 10. Guardar ──────────────────────────────────────────────────────────────
saveRDS(immex_empleo, here::here("RDS", "immex_empleo.rds"))

message("immex_empleo guardado: ", nrow(immex_empleo), " filas | ",
        n_distinct(immex_empleo$CVE_ENT), " entidades/agregados")

distinct(immex_empleo, CVE_ENT, nombre, abrev) |>
  arrange(CVE_ENT) |>
  print(n = 25)

# ── 10b. Metadatos ───────────────────────────────────────────────────────────
meta_immex_empleo <- list(
  fuente         = "INEGI — Estadística Mensual sobre Establecimientos con Programa IMMEX (Segmento Manufacturero)",
  url_fuente     = "https://www.inegi.org.mx/programas/immex/#datos_abiertos",
  fecha_descarga = Sys.time(),
  cobertura_geo  = "17 entidades federativas + Zona Libre de la Frontera Norte (ZLF) + Total nacional (TOT)",
  periodo        = paste(range(immex_empleo$fecha), collapse = " – "),
  frecuencia     = "Mensual",
  unidad         = "Personas",
  variables      = "
    emp_prod_directo  : obreros y técnicos en producción, nómina propia (H114A)
    emp_prod_externo  : obreros y técnicos en producción, subcontratados (I400A)
    emp_prod_total    : emp_prod_directo + emp_prod_externo
    emp_adm_directo   : personal administrativo, nómina propia (H200A)
    emp_adm_externo   : personal administrativo, subcontratado (I500A)
    emp_adm_total     : emp_adm_directo + emp_adm_externo
    emp_total         : suma de las seis componentes anteriores
  ",
  agregados_especiales = "
    CVE_ENT = '02' (BC): total estatal construido sumando los cuatro municipios
      (02001 Ensenada, 02002 Mexicali, 02003 Tecate, 02004 Tijuana).
      INEGI no publica fila de total estatal para BC. ESTATUS = NA.
    CVE_ENT = 'ZLF' (ZLFN): suma de municipios fronterizos con salario mínimo
      diferenciado (Decreto DOF 2018). Excluye Ensenada. ESTATUS = NA.
    CVE_ENT = 'TOT' (Total nacional): suma de 17 estados. Excluye ZLF
      para evitar doble conteo. ESTATUS = NA.
  ",
  notas          = "
    Segmento manufacturero únicamente; excluye segmento no manufacturero.
    ESTATUS = 'Cifras Definitivas' o 'Cifras Preliminares' según INEGI;
    NA en filas construidas (BC, ZLF, TOT).
    Serie iniciada en 2010; datos anteriores disponibles en fuente pero
    excluidos de este objeto.
  "
)

saveRDS(meta_immex_empleo, here::here("RDS", "meta_immex_empleo.rds"))
message("meta_immex_empleo guardado")

# ── 11. Limpieza de memoria ──────────────────────────────────────────────────
rm(immex_raw, immex_emp, immex_ef, bc_ef, immex_zlfn,
   immex_total_nacional, immex_empleo, cat_entidades, cvegeo_zlfn,
   archivos, ruta_csv)
