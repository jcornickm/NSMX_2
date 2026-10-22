# Query08_IMMEX.R
# Empleo IMMEX segmento manufacturero por entidad federativa y Zona Libre
# de la Frontera Norte (ZLFN)
# Fuente: INEGI – Datos abiertos IMMEX
# https://www.inegi.org.mx/programas/immex/#datos_abiertos
#
# Estructura de la fuente (descarga "Por municipio", un CSV por año):
#   - Estados SIN desglose municipal (01, 09, 10, 30): una fila estatal
#     (CVE_MUN vacío o "000").
#   - Estados CON desglose municipal: una fila por municipio con datos más una
#     fila "otros municipios" (CVE_MUN = "999"). NO existe fila de total
#     estatal; el total se construye sumando todas las filas de la entidad.
#   - CVE_ENT = "99": "Otras entidades" (no se incluye en los estados).
# Nota: en los archivos anteriores a oct-2026 la fila "otros municipios" venía
# con CVEGEO de 2 dígitos ("08"), lo que se confundía con un total estatal.
# Revisión 22-oct-2026: los totales estatales se construyen siempre por suma.

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

# ── 2. Leer todos los archivos anuales (2010 en adelante) ───────────────────
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
    # Limpiar espacios y tabulaciones en las claves de texto
    CVEGEO  = str_trim(CVEGEO),
    CVE_ENT = str_trim(CVE_ENT),
    CVE_MUN = str_trim(CVE_MUN),
    # Fila estatal única (estados sin desglose municipal): CVE_MUN vacío o "000"
    es_fila_estatal = is.na(CVE_MUN) | CVE_MUN %in% c("", "000"),
    # Variables de empleo
    emp_prod_directo = H114A,           # obreros propios
    emp_prod_externo = I400A,           # obreros subcontratados
    emp_prod_total   = H114A + I400A,
    emp_adm_directo  = H200A,           # admvos propios
    emp_adm_externo  = I500A,           # admvos subcontratados
    emp_adm_total    = H200A + I500A,
    emp_total        = H114A + I400A + H200A + I500A
  )

vars_suma <- c("NUM_DE_ESTAB_ACT",
               "emp_prod_directo", "emp_prod_externo", "emp_prod_total",
               "emp_adm_directo",  "emp_adm_externo",  "emp_adm_total",
               "emp_total")

# Verificación de la estructura: un estado-mes tiene o bien UNA fila estatal,
# o bien filas municipales; nunca ambas (sumar todo duplicaría el conteo).
chk_estructura <- immex_emp |>
  filter(CVE_ENT != "99") |>
  group_by(ANIO, ID_MES, CVE_ENT) |>
  summarise(n_estatal = sum(es_fila_estatal),
            n_munic   = sum(!es_fila_estatal),
            .groups   = "drop")

stopifnot(
  "Hay estados con fila estatal Y municipal en el mismo mes: sumar duplicaría" =
    !any(chk_estructura$n_estatal > 0 & chk_estructura$n_munic > 0),
  "Hay estados con más de una fila estatal en un mes" =
    !any(chk_estructura$n_estatal > 1)
)

# ── 4. Catálogo de entidades (17 estados con IMMEX manufacturero) ───────────
cat_entidades <- tribble(
  ~CVE_ENT, ~nombre,               ~abrev,
  "01",     "Aguascalientes",       "AGS",
  "02",     "Baja California",      "BC",
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

# ── 5. Agregado por entidad federativa (suma de todas las filas del estado) ──
immex_ef <- immex_emp |>
  filter(CVE_ENT != "99") |>
  group_by(ANIO, ID_MES, CVE_ENT) |>
  summarise(
    across(all_of(vars_suma), \(x) sum(x, na.rm = TRUE)),
    ESTATUS = {u <- unique(ESTATUS[!is.na(ESTATUS)]); if (length(u) == 1L) u else "Mixto"},
    .groups = "drop"
  ) |>
  mutate(fecha = as.Date(paste(ANIO, ID_MES, "01", sep = "-"))) |>
  left_join(cat_entidades, by = "CVE_ENT") |>
  rename(año = ANIO) |>
  select(fecha, año, ID_MES, CVE_ENT, nombre, abrev,
         all_of(vars_suma), ESTATUS)

# Verificación: sin NAs en nombre tras el join
stopifnot("CVE_ENT sin nombre — revisar cat_entidades" =
            sum(is.na(immex_ef$nombre)) == 0)

# ── 6. Agregado Zona Libre de la Frontera Norte ─────────────────────────────
# Ensenada (02001) excluida: su actividad IMMEX no es fronteriza en sentido estricto
immex_zlfn <- immex_emp |>
  filter(CVEGEO %in% cvegeo_zlfn) |>
  group_by(ANIO, ID_MES) |>
  summarise(
    across(all_of(vars_suma), \(x) sum(x, na.rm = TRUE)),
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
         all_of(vars_suma), ESTATUS)

# ── 7. Total nacional (17 estados; excluye ZLFN para evitar doble conteo) ────
# No incluye CVE_ENT = "99" (Otras entidades).
immex_total_nacional <- immex_ef |>
  group_by(fecha, año, ID_MES) |>
  summarise(
    CVE_ENT = "TOT",
    nombre  = "Total nacional",
    abrev   = "Total",
    across(all_of(vars_suma), \(x) sum(x, na.rm = TRUE)),
    ESTATUS = NA_character_,
    .groups = "drop"
  )

# ── 8. Combinar todo en un solo objeto ──────────────────────────────────────
immex_empleo <- bind_rows(immex_ef, immex_zlfn, immex_total_nacional) |>
  arrange(fecha, CVE_ENT)

# ── 9. Guardar ──────────────────────────────────────────────────────────────
saveRDS(immex_empleo, here::here("RDS", "immex_empleo.rds"))

message("immex_empleo guardado: ", nrow(immex_empleo), " filas | ",
        n_distinct(immex_empleo$CVE_ENT), " entidades/agregados")

distinct(immex_empleo, CVE_ENT, nombre, abrev) |>
  arrange(CVE_ENT) |>
  print(n = 25)

cat("\nÚltimo mes en immex_empleo:", as.character(max(immex_empleo$fecha)), "\n")
cat("\nFilas por ESTATUS (excluye filas construidas):\n")
immex_empleo |> filter(!is.na(ESTATUS)) |> count(ESTATUS) |> print()
cat("\nMeses por entidad/agregado en el último mes (debe ser 1 por clave):\n")
immex_empleo |> filter(fecha == max(fecha)) |> count(CVE_ENT) |> print(n = 25)

# Verificación de cordura: empleo total de los estados en el último mes
cat("\nEmpleo total (personas) por entidad en el último mes, de mayor a menor:\n")
immex_empleo |>
  filter(fecha == max(fecha)) |>
  select(CVE_ENT, nombre, emp_total) |>
  arrange(desc(emp_total)) |>
  mutate(emp_total = scales::comma(emp_total)) |>
  print(n = 25)

# ── 9b. Metadatos ───────────────────────────────────────────────────────────
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
    Totales estatales: se construyen SIEMPRE sumando todas las filas de la entidad
      (municipios con datos + 'otros municipios', CVE_MUN = 999; o la fila estatal
      única en los estados sin desglose municipal: 01, 09, 10, 30). INEGI no
      publica fila de total estatal para los estados con desglose municipal.
      La versión anterior de este script tomaba las filas 'otros municipios' como
      si fueran el total estatal, por lo que subestimaba 12 estados y el total nacional.
    CVE_ENT = 'ZLF' (ZLFN): suma de municipios fronterizos con salario mínimo
      diferenciado (Decreto DOF 2018). Excluye Ensenada. ESTATUS = NA.
    CVE_ENT = 'TOT' (Total nacional): suma de los 17 estados. Excluye ZLF
      para evitar doble conteo y excluye CVE_ENT = '99' (Otras entidades).
      ESTATUS = NA.
  ",
  notas          = "
    Segmento manufacturero únicamente; excluye segmento no manufacturero.
    ESTATUS = 'Cifras Definitivas', 'Cifras Preliminares' o 'Cifras Oportunas' según INEGI;
    'Mixto' si el estado-mes combina más de un estatus; NA en filas construidas (ZLF, TOT).
    Serie iniciada en 2010; datos anteriores disponibles en fuente pero
    excluidos de este objeto.
  "
)

saveRDS(meta_immex_empleo, here::here("RDS", "meta_immex_empleo.rds"))
message("meta_immex_empleo guardado")

# ── 10. Limpieza de memoria ─────────────────────────────────────────────────
rm(immex_raw, immex_emp, immex_ef, immex_zlfn, immex_total_nacional,
   immex_empleo, cat_entidades, cvegeo_zlfn, archivos, ruta_csv,
   chk_estructura, vars_suma)
