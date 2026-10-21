# Query02_Imp_MEX_VNM_TWN_HS4.R   ####
# FUENTE MAESTRA de los datos de comercio de EUA por partida (Census):
# importaciones de EUA provenientes de México, Vietnam y Taiwán, todos los
# niveles del SA mezclados (total, HS2, HS4, HS6, HS10), mensual desde 2010.
# Fuente: US Census Bureau — International Trade API
#
# Los objetos de México que antes bajaba cada Query por separado (Query03: por
# Capítulo; Query04: por Partida/Subpartida) ahora se DERIVAN de aquí, para que
# todo salga de una sola descarga y una sola versión de los datos de Census.
# Orden de corrida: Query01 → Query02 → Query03 → Query04 → Query05 → Query06.
#
# ACTUALIZACIÓN INCREMENTAL: no se vuelve a bajar toda la historia. Se descarga
# desde ANIO_SOLAPE hasta el último mes disponible (Census revisa los años
# recientes) y se reemplaza ese tramo en RDS/raw_df_mex_vnm_twn.rds; lo anterior
# no se toca. Cada país-año descargado queda en RDS/raw/raw_hs_<CTY>_<año>.rds
# (si una descarga se cae, lo ya bajado no se pierde). Para regenerar solo los
# derivados sin llamar al API: DESCARGAR <- FALSE.
#
# Todos los capítulos (sin restringir a 84/85/87/90): el objetivo es identificar,
# de manera independiente para cada país, sus partidas más relevantes, y luego
# intersectar esas listas con las de México (partidas "en competencia").
#
# Entradas:  RDS/raw_df_mex_vnm_twn.rds (versión actual), API de Census
# Salidas:   RDS/raw_df_mex_vnm_twn.rds, RDS/imp_competidores_hs4.rds,
#            RDS/meta_query11.rds, RDS/revision_q11.rds (qué cambió)

#   NOTAS SOBRE EL API                                                      ####

# • COMM_LVL omitido intencionalmente: la combinación CTY_CODE + COMM_LVL genera
#   error del servidor para HS4/HS6. Sin COMM_LVL, el API devuelve todos los
#   niveles mezclados en I_COMMODITY:
#     cod == "-"      →  total nacional
#     nchar(cod) == 2 →  Capítulo (HS2)
#     nchar(cod) == 4 →  Partida  (HS4)
#     nchar(cod) == 6 →  Subpartida (HS6)
#     nchar(cod) == 10→  Schedule B (10 dígitos)
#   Se separan por nchar(I_COMMODITY) en la limpieza.
# • CTY_CODE: México = 2010, Vietnam = 5520, Taiwán = 5830.
# • Se descarga año por año y por país — el API falla con rangos largos.

pacman::p_load(tidyverse, here, lubridate, scales)
source(here("Scripts", "funciones.R"))        # hs_agregar_etiquetas(), hs_etiquetas_partida()
source(here("Scripts", "funciones_datos.R"))  # census_*(), actualizar_rds()

#  Sección 1. Parámetros                                                    ####

DESCARGAR      <- TRUE    # FALSE: no llama al API; solo regenera los derivados
ANIO_SOLAPE    <- 2023L   # primer año que se vuelve a descargar
VIGENCIA_HORAS <- 12      # un archivo raw más viejo que esto se vuelve a descargar

paises <- tribble(
  ~CTY_CODE, ~Pais,
  "2010",    "México",
  "5520",    "Vietnam",
  "5830",    "Taiwán"
)

# Etiquetas del SA: salen de RDS/hs_dictionary.rds (Scripts/build_hs_dictionary.R;
# nombres cortos editables en Excel/hs_nombres_cortos.csv). Sin tribbles ad hoc.
capitulos_es <- hs_tablas()$capitulos |> tibble::as_tibble()   # Capítulo, Sección, Cap_corto, Cap_tabla

#  Sección 2. Datos crudos: actualización con solape                       ####

ruta_raw <- here("RDS", "raw_df_mex_vnm_twn.rds")
raw_df   <- readRDS(ruta_raw)
if (!"fecha" %in% names(raw_df))
  raw_df <- raw_df |> mutate(fecha = as.Date(paste0(time, "-01")))
message("Datos crudos actuales: ", nrow(raw_df), " filas, hasta ", format(max(raw_df$fecha)))

revision_q11 <- NULL
ultimo_mes   <- NA_character_

if (DESCARGAR) {
  anio_actual <- year(Sys.Date())
  ultimo_mes  <- census_ultimo_mes(anio_actual)
  message("Último mes disponible en Census: ", ultimo_mes)

  años  <- if (is.na(ultimo_mes)) ANIO_SOLAPE:(anio_actual - 1L) else ANIO_SOLAPE:anio_actual
  desde <- as.Date(sprintf("%d-01-01", ANIO_SOLAPE))

  nuevo <- pmap(paises, function(CTY_CODE, Pais) {
    message("\n=== Descargando ", Pais, " ", min(años), "–", max(años), " ===")
    census_descargar_anios(
      prefijo = paste0("raw_hs_", CTY_CODE), anios = años,
      vars    = c("I_COMMODITY", "I_COMMODITY_LDESC", "GEN_VAL_MO", "GEN_VAL_YR"),
      filtros = list(CTY_CODE = CTY_CODE),
      mes_fin_actual = ultimo_mes, max_edad_horas = VIGENCIA_HORAS
    ) |>
      mutate(CTY_CODE_dl = .env$CTY_CODE, Pais = .env$Pais)
  }) |>
    bind_rows() |>
    mutate(
      GEN_VAL_MO = as.numeric(GEN_VAL_MO),
      GEN_VAL_YR = as.numeric(GEN_VAL_YR),
      fecha      = as.Date(paste0(time, "-01"))
    )

  act <- actualizar_rds(raw_df, nuevo, llaves = c("Pais", "I_COMMODITY"),
                        valor = "GEN_VAL_MO", desde = desde,
                        nombre = "importaciones MX/VN/TW (todos los niveles)")
  raw_df       <- act$datos
  revision_q11 <- act$revision
  rm(nuevo, act); invisible(gc())

  # Los tres países deben llegar al mismo mes
  ult_por_pais <- raw_df |> group_by(Pais) |> summarise(ultimo = max(fecha), .groups = "drop")
  print(ult_por_pais)
  stopifnot("Los países terminan en meses distintos" = n_distinct(ult_por_pais$ultimo) == 1)

  tryCatch({
    saveRDS(raw_df, ruta_raw)
    saveRDS(list(revision = revision_q11, fecha = Sys.time()), here("RDS", "revision_q11.rds"))
    message("✔  raw_df_mex_vnm_twn.rds y revision_q11.rds guardados.")
  }, error = function(e) message("✗  ERROR guardando los datos crudos: ", conditionMessage(e)))
} else {
  message("\n=== DESCARGAR = FALSE: se usan los datos crudos ya guardados (sin llamar al API) ===")
}

cat("Filas en raw_df:", nrow(raw_df), "\n")
cat("\nFilas por país:\n")
raw_df |> count(Pais) |> print()

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
  período             = paste(format(min(raw_df$fecha)), "a", format(max(raw_df$fecha))),
  solape_desde        = if (DESCARGAR) format(desde) else NA_character_,
  ultimo_mes          = ultimo_mes,
  capítulos           = "Todos (sin restringir) — el filtro a capítulos/partidas de interés se hace en un script posterior",
  nivel               = "Partida (HS4) — filtrado por nchar(I_COMMODITY) == 4",
  archivos            = list(
    raw_df_mex_vnm_twn   = "Descarga cruda, los tres países, todos los niveles HS mezclados",
    imp_competidores_hs4 = "Partidas (HS4), los tres países, todos los capítulos"
  ),
  notas               = paste(
    "COMM_LVL omitido intencionalmente: la combinación CTY_CODE + COMM_LVL devuelve",
    "error del servidor. El API devuelve todos los niveles mezclados; se extrae HS4",
    "filtrando por nchar(I_COMMODITY). Val_mes y Val_acum en dólares corrientes.",
    "Actualización incremental: los años anteriores a", ANIO_SOLAPE, "provienen de la",
    "descarga original (octubre de 2026, con 2026 hasta julio); desde", ANIO_SOLAPE,
    "se volvió a descargar (Census revisa años recientes; ver revision_q11.rds).",
    "El último año es parcial — no comparar contra años completos sin comparar los",
    "mismos meses.",
    "Query03 y Query04 derivan de raw_df_mex_vnm_twn.rds (México)."
  )
)

tryCatch({
  saveRDS(imp_competidores_hs4, here("RDS", "imp_competidores_hs4.rds"))
  message("✔  imp_competidores_hs4.rds guardado. Filas: ", nrow(imp_competidores_hs4))
}, error = function(e) message("✗  ERROR guardando imp_competidores_hs4.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(meta_query11, here("RDS", "meta_query11.rds"))
  message("✔  meta_query11.rds guardado.")
}, error = function(e) message("✗  ERROR guardando meta_query11.rds: ", conditionMessage(e)))
