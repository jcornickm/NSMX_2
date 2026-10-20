# Query11_Imp_MEX_VNM_TWN_HS4.R   ####
# Importaciones de EUA provenientes de México, Vietnam y Taiwán — Partidas (HS4)
# Fuente: US Census Bureau — International Trade API
# Período: 2010–2025 (años completos) + enero–julio 2026
# Todos los capítulos (sin restringir a 84/85/87/90): el objetivo es identificar,
# de manera independiente para cada país, sus partidas más relevantes, y luego
# intersectar esas listas con las de México (partidas "en competencia").
#
# Este script cubre únicamente LA DESCARGA Y LIMPIEZA (paso 1 del ejercicio).
# La identificación de top-partidas por país y la intersección México vs.
# Vietnam/Taiwán se abordan en un script posterior.

#   NOTAS SOBRE EL API                                                      ####

# • COMM_LVL omitido intencionalmente (igual que en Query3): la combinación
#   CTY_CODE + COMM_LVL genera error del servidor para HS4/HS6. Sin COMM_LVL,
#   el API devuelve todos los niveles mezclados en I_COMMODITY:
#     cod == "-"      →  total nacional
#     nchar(cod) == 2 →  Capítulo (HS2)
#     nchar(cod) == 4 →  Partida  (HS4)      <- nivel usado en este ejercicio
#     nchar(cod) == 6 →  Subpartida (HS6)
#     nchar(cod) == 10→  Schedule B (10 dígitos)
#   Se separan por nchar(I_COMMODITY) en la limpieza, igual que en Query3.
# • CTY_CODE: México = 2010, Vietnam = 5520, Taiwán = 5830
#   (códigos tomados de Query1_USA_imports_by_country.R, ya verificados).
# • Se itera año por año (y por país) — el API falla con rangos temporales
#   largos. 2026 se descarga aparte, como período parcial (enero–julio).
# • Cada combinación país-año se guarda inmediatamente como RDS individual
#   para proteger el progreso ante fallos de conexión.

pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse,
               here, janitor, censusapi, scales)

# — Interruptor de descarga ----------------------------------------------------
# repull = FALSE (default): NO se llama al API; se reconstruye todo (etiquetas,
# derivados, guardado) desde los datos crudos ya guardados en RDS/.
# repull = TRUE: vuelve a descargar (requiere CENSUS_API_KEY).
repull <- FALSE

#  Sección 1. Tareas preparatorias                                          ####

api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("CENSUS_API_KEY no encontrado — definir en .Renviron" =
            !repull || nchar(api_key) > 0)
dir.create(here("RDS", "raw"), recursive = TRUE, showWarnings = FALSE)

## Países incluidos                                                         ####
paises <- tribble(
  ~CTY_CODE, ~Pais,
  "2010",    "México",
  "5520",    "Vietnam",
  "5830",    "Taiwán"
)

source(here("Scripts", "funciones.R"))   # hs_agregar_etiquetas(), hs_etiquetas_partida(), sa_adj()

# Etiquetas del SA: salen de RDS/hs_dictionary.rds (Scripts/build_hs_dictionary.R;
# nombres cortos editables en Excel/hs_nombres_cortos.csv). Sin tribbles ad hoc.
capitulos_es <- hs_tablas()$capitulos |> tibble::as_tibble()   # Capítulo, Sección, Cap_corto, Cap_tabla


if (!repull && file.exists(here("RDS", "raw_df_mex_vnm_twn.rds"))) {
  message("\n=== repull = FALSE: se usa RDS/raw_df_mex_vnm_twn.rds (sin llamar al API) ===")
  raw_df <- readRDS(here("RDS", "raw_df_mex_vnm_twn.rds"))
} else {
  # Sección 2. Descarga de datos — por país y año   ####

  descargar_periodo <- function(cty_code, pais, etiqueta_periodo, time_str) {
    archivo <- here("RDS", "raw", paste0("raw_hs_", cty_code, "_", etiqueta_periodo, ".rds"))
    if (file.exists(archivo)) {
      message("  [", pais, " ", etiqueta_periodo, "] ya existe — se omite descarga.")
      return(readRDS(archivo))
    }
    message("  [", pais, " ", etiqueta_periodo, "] descargando...")
    tryCatch({
      resultado <- getCensus(
        name     = "timeseries/intltrade/imports/hs",
        vars     = c("I_COMMODITY", "I_COMMODITY_LDESC", "GEN_VAL_MO", "GEN_VAL_YR"),
        time     = time_str,
        key      = api_key,
        CTY_CODE = cty_code
      ) |>
        mutate(CTY_CODE_dl = cty_code, Pais = pais)
      saveRDS(resultado, archivo)
      message("  [", pais, " ", etiqueta_periodo, "] guardado: ", basename(archivo))
      resultado
    }, error = function(e) {
      message("  ERROR [", pais, " ", etiqueta_periodo, "]: ", conditionMessage(e))
      NULL
    })
  }

  años_completos <- 2010:2025

  # — Años completos 2010–2025, por país ----------------------------------------
  message("\n=== Descargando años completos 2010–2025 — México, Vietnam, Taiwán ===")

  plan_años <- expand_grid(paises, año = años_completos)

  raw_list_años <- pmap(
    plan_años,
    function(CTY_CODE, Pais, año) {
      descargar_periodo(
        cty_code         = CTY_CODE,
        pais             = Pais,
        etiqueta_periodo = as.character(año),
        time_str         = paste0("from ", año, " to ", año)
      )
    }
  )

  # — Período parcial 2026 (enero–julio), por país -------------------------------
  message("\n=== Descargando enero–julio 2026 — México, Vietnam, Taiwán ===")

  raw_list_2026 <- pmap(
    paises,
    function(CTY_CODE, Pais) {
      descargar_periodo(
        cty_code         = CTY_CODE,
        pais             = Pais,
        etiqueta_periodo = "2026_ene_jul",
        time_str         = "from 2026-01 to 2026-07"
      )
    }
  )

  raw_list <- c(raw_list_años, raw_list_2026)

  fallos <- sum(map_lgl(raw_list, is.null))
  if (fallos > 0) message(fallos, " descargas fallaron — revisar mensajes anteriores y volver a correr el script (se omiten las que ya tienen RDS).")

  # Sección 3. Ensamblaje   ####

  message("\n=== Ensamblando archivos raw (México, Vietnam, Taiwán — 2010 a jul-2026) ===")

  raw_df <- raw_list |>
    compact() |>
    bind_rows() |>
    as_tibble()

  cat("Filas en raw_df:", nrow(raw_df), "\n")
  cat("\nFilas por país:\n")
  raw_df |> count(Pais) |> print()
  saveRDS(raw_df, here("RDS", "raw_df_mex_vnm_twn.rds"))
}

# Sección 4. Limpieza — variables derivadas, nivel de agregación   ####

message("\n=== Limpieza y clasificación de niveles ===")

imp_competidores_all <- raw_df |>
  mutate(
    fecha    = as.Date(paste0(time, "-01")),
    cod      = as.character(I_COMMODITY),
    nivel    = case_when(
      cod == "-"         ~ "total",
      nchar(cod) == 2    ~ "HS2",
      nchar(cod) == 4    ~ "HS4",
      nchar(cod) == 6    ~ "HS6",
      nchar(cod) == 10   ~ "HS10",
      .default           = "otro"
    ),
    Capítulo = case_when(
      nivel == "HS2"  ~ as.integer(cod),
      nivel == "HS4"  ~ as.integer(substr(cod, 1, 2)),
      nivel == "HS6"  ~ as.integer(substr(cod, 1, 2)),
      nivel == "HS10" ~ as.integer(substr(cod, 1, 2)),
      .default        = NA_integer_
    ),
    Val_mes  = as.numeric(GEN_VAL_MO),
    Val_acum = as.numeric(GEN_VAL_YR)
  )

cat("\nDistribución de niveles en imp_competidores_all:\n")
imp_competidores_all |> count(Pais, nivel) |> print(n = 30)

# Sección 5. Partidas (HS4) — los tres países, todos los capítulos   ####


message("\n=== Construyendo imp_competidores_hs4 (México, Vietnam, Taiwán — todos los capítulos) ===")

imp_competidores_hs4 <- imp_competidores_all |>
  filter(nivel == "HS4") |>
  hs_agregar_etiquetas() |>
  mutate(
    Desc_api_partida = as.character(I_COMMODITY_LDESC)
  ) |>
  select(
    Pais,
    fecha,
    Sección,
    Sección_corto,
    Capítulo,
    Cap_corto,
    Cod_partida      = cod,
    Desc_api_partida,
    Val_mes,
    Val_acum
  ) |>
  arrange(Pais, fecha, Capítulo, Cod_partida)

cat("Filas en imp_competidores_hs4:", nrow(imp_competidores_hs4), "\n")
cat("\nCobertura temporal por país:\n")
imp_competidores_hs4 |>
  group_by(Pais) |>
  summarise(desde = min(fecha), hasta = max(fecha), n_meses = n_distinct(fecha), .groups = "drop") |>
  print()

cat("\nPartidas distintas por país:\n")
imp_competidores_hs4 |>
  distinct(Pais, Cod_partida) |>
  count(Pais, name = "n_partidas") |>
  print()

# Sección 6. Metadatos y guardado   ####

meta_query11 <- list(
  fuente              = "US Census Bureau — International Trade API",
  endpoint            = "timeseries/intltrade/imports/hs",
  url                 = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga      = Sys.time(),
  países              = "México (CTY_CODE = 2010), Vietnam (CTY_CODE = 5520), Taiwán (CTY_CODE = 5830)",
  período             = "2010-01 a 2025-12 (años completos) + 2026-01 a 2026-07 (parcial)",
  capítulos           = "Todos (sin restringir) — el filtro a capítulos/partidas de interés se hace en un script posterior",
  nivel               = "Partida (HS4) — filtrado por nchar(I_COMMODITY) == 4",
  archivos            = list(
    raw_df_mex_vnm_twn   = "Descarga cruda, los tres países, todos los niveles HS mezclados",
    imp_competidores_hs4 = "Partidas (HS4), los tres países, todos los capítulos, 2010 – jul 2026"
  ),
  notas               = "COMM_LVL omitido intencionalmente (igual que Query3): la combinación
                         CTY_CODE + COMM_LVL devuelve error del servidor. El API devuelve todos
                         los niveles mezclados cuando COMM_LVL se omite; se extrae HS4 filtrando
                         por nchar(I_COMMODITY). Val_mes y Val_acum en dólares corrientes.
                         2026 es año parcial (solo enero–julio) — no comparar directamente
                         contra años completos sin anualizar.
                         Paso siguiente: identificar top-partidas por país (valor 2024–2025 o
                         2024–jul2026) e intersectar con la lista de México para hallar partidas
                         en que México compite con Vietnam y/o Taiwán."
)

tryCatch({
  saveRDS(imp_competidores_hs4, here("RDS", "imp_competidores_hs4.rds"))
  message("✔  imp_competidores_hs4.rds guardado. Filas: ", nrow(imp_competidores_hs4))
}, error = function(e) message("✗  ERROR guardando imp_competidores_hs4.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(meta_query11, here("RDS", "meta_query11.rds"))
  message("✔  meta_query11.rds guardado.")
}, error = function(e) message("✗  ERROR guardando meta_query11.rds: ", conditionMessage(e)))
