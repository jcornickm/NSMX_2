# Query11_Autos_Autopartes_Socios.R   ####
# Importaciones de EUA de autos (HS 8703) y autopartes (HS 8708) provenientes de
# México, Japón, Corea del Sur y Alemania (proxy de la UE: el agregado de la UE
# cambia de composición con el Brexit), mensual desde 2010, todos los niveles del
# SA bajo cada partida (HS4, HS6, HS10).
# Fuente: US Census Bureau — International Trade API
#
# MÉXICO no se descarga aquí: se deriva de RDS/raw_df_mex_vnm_twn.rds (fuente
# maestra, Query02), para tener una sola versión de los datos de México.
# Orden de corrida: Query02 antes que Query11 (para que México llegue al mismo
# mes que los demás).
#
# ACTUALIZACIÓN INCREMENTAL (mismo esquema que Query02): la primera vez baja desde
# ANIO_INI; después, solo desde ANIO_SOLAPE y reemplaza ese tramo en
# RDS/raw_df_autos_socios.rds. Cada país-partida-año queda en
# RDS/raw/raw_autos_<CTY>_<partida>_<año>.rds. DESCARGAR <- FALSE regenera los
# derivados sin llamar al API.
#
# Entradas:  RDS/raw_df_mex_vnm_twn.rds, API de Census
# Salidas:   RDS/raw_df_autos_socios.rds (crudo, solo los países descargados),
#            RDS/imp_autos_socios.rds (4 países, limpio),
#            RDS/imp_autos_mundo.rds (total mundial HS4, para calcular Resto),
#            RDS/meta_query11.rds, RDS/revision_q11.rds, RDS/revision_q11_mundo.rds

#   NOTAS SOBRE EL API                                                      ####

# • El filtro I_COMMODITY acepta comodín ("8703*"): devuelve la partida (4
#   dígitos) y todas sus subpartidas (6 y 10 dígitos) en una sola llamada.
# • COMM_LVL omitido intencionalmente (ver Query02).
# • CTY_CODE: Japón = 5880, Corea del Sur = 5800, Alemania = 4280, México = 2010.
# • Se descarga por país, partida y año — el API falla con rangos largos.

pacman::p_load(tidyverse, here, lubridate)
source(here("Scripts", "funciones.R"))
source(here("Scripts", "funciones_datos.R"))  # census_*(), actualizar_rds()

#  Sección 1. Parámetros                                                    ####

DESCARGAR      <- TRUE    # FALSE: no llama al API; solo regenera los derivados
ANIO_INI       <- 2010L   # primer año (descarga inicial)
ANIO_SOLAPE    <- 2023L   # primer año que se vuelve a descargar en actualizaciones
VIGENCIA_HORAS <- 12      # un archivo raw más viejo que esto se vuelve a descargar

paises <- tribble(
  ~CTY_CODE, ~Pais,
  "5880",    "Japón",
  "5800",    "Corea del Sur",
  "4280",    "Alemania"
)
partidas <- c("8703", "8708")   # autos, autopartes

stopifnot("Países sin color en paleta_pais" =
            all(c(paises$Pais, "México") %in% names(paleta_pais)))

#  Sección 2. Datos crudos                                                 ####

ruta_raw     <- here("RDS", "raw_df_autos_socios.rds")
raw_df       <- if (file.exists(ruta_raw)) readRDS(ruta_raw) else NULL
revision_q11 <- NULL
ultimo_mes   <- NA_character_
desde        <- NULL

if (DESCARGAR) {
  anio_actual <- year(Sys.Date())
  ultimo_mes  <- census_ultimo_mes(anio_actual)
  message("Último mes disponible en Census: ", ultimo_mes)

  incremental <- !is.null(raw_df)
  anio_desde  <- if (incremental) ANIO_SOLAPE else ANIO_INI
  años  <- if (is.na(ultimo_mes)) anio_desde:(anio_actual - 1L) else anio_desde:anio_actual
  desde <- as.Date(sprintf("%d-01-01", anio_desde))

  nuevo <- crossing(paises, partida = partidas) |>
    pmap(function(CTY_CODE, Pais, partida) {
      message("\n=== ", Pais, " — ", partida, " ", min(años), "–", max(años), " ===")
      census_descargar_anios(
        prefijo = sprintf("raw_autos_%s_%s", CTY_CODE, partida), anios = años,
        vars    = c("I_COMMODITY", "I_COMMODITY_LDESC", "GEN_VAL_MO", "GEN_VAL_YR"),
        filtros = list(CTY_CODE = CTY_CODE, I_COMMODITY = paste0(partida, "*")),
        mes_fin_actual = ultimo_mes, max_edad_horas = VIGENCIA_HORAS
      ) |>
        mutate(CTY_CODE_dl = .env$CTY_CODE, Pais = .env$Pais)
    }) |>
    bind_rows() |>
    transmute(
      time, I_COMMODITY = as.character(I_COMMODITY),
      I_COMMODITY_LDESC = as.character(I_COMMODITY_LDESC),
      GEN_VAL_MO = as.numeric(GEN_VAL_MO), GEN_VAL_YR = as.numeric(GEN_VAL_YR),
      CTY_CODE = as.character(CTY_CODE), CTY_CODE_dl, Pais,
      fecha = as.Date(paste0(time, "-01"))
    )

  if (incremental) {
    act <- actualizar_rds(raw_df, nuevo, llaves = c("Pais", "I_COMMODITY"),
                          valor = "GEN_VAL_MO", desde = desde,
                          nombre = "importaciones autos/autopartes JP/KR/DE")
    raw_df       <- act$datos
    revision_q11 <- act$revision
    rm(act)
  } else {
    raw_df <- nuevo
  }
  rm(nuevo); invisible(gc())

  # Cada país debe llegar al mismo mes
  ult_por_pais <- raw_df |> group_by(Pais) |> summarise(ultimo = max(fecha), .groups = "drop")
  print(ult_por_pais)
  stopifnot("Los países terminan en meses distintos" = n_distinct(ult_por_pais$ultimo) == 1)

  tryCatch({
    saveRDS(raw_df, ruta_raw)
    saveRDS(list(revision = revision_q11, fecha = Sys.time()), here("RDS", "revision_q11.rds"))
    message("✔  raw_df_autos_socios.rds y revision_q11.rds guardados.")
  }, error = function(e) message("✗  ERROR guardando los datos crudos: ", conditionMessage(e)))
} else {
  message("\n=== DESCARGAR = FALSE: se usan los datos crudos ya guardados (sin llamar al API) ===")
  stopifnot("No existe raw_df_autos_socios.rds: corre con DESCARGAR <- TRUE" = !is.null(raw_df))
}

#  Sección 2b. Total mundial (HS4)                                          ####

# Importaciones totales de EUA (todos los países) de 8703 y 8708, para calcular
# "Resto" = Mundo − México − Japón − Corea del Sur − Alemania. Sin filtro de
# CTY_CODE el API devuelve todos los países y agregados; el total mundial es la
# fila CTY_CODE == "-". I_COMMODITY exacto (sin comodín): solo HS4.

ruta_mundo     <- here("RDS", "imp_autos_mundo.rds")
mundo_previo   <- if (file.exists(ruta_mundo)) readRDS(ruta_mundo) else NULL
revision_mundo <- NULL

if (DESCARGAR) {
  incr_mundo  <- !is.null(mundo_previo)
  anio_d_mundo <- if (incr_mundo) ANIO_SOLAPE else ANIO_INI
  años_mundo  <- if (is.na(ultimo_mes)) anio_d_mundo:(anio_actual - 1L) else anio_d_mundo:anio_actual
  desde_mundo <- as.Date(sprintf("%d-01-01", anio_d_mundo))

  nuevo_mundo <- map(partidas, function(partida) {
    message("\n=== Mundo — ", partida, " ", min(años_mundo), "–", max(años_mundo), " ===")
    census_descargar_anios(
      prefijo = sprintf("raw_autos_mundo_%s", partida), anios = años_mundo,
      vars    = c("I_COMMODITY", "CTY_CODE", "GEN_VAL_MO", "GEN_VAL_YR"),
      filtros = list(I_COMMODITY = partida),
      mes_fin_actual = ultimo_mes, max_edad_horas = VIGENCIA_HORAS
    )
  }) |>
    bind_rows() |>
    filter(CTY_CODE == "-") |>
    transmute(
      fecha    = as.Date(paste0(time, "-01")),
      partida  = as.character(I_COMMODITY),
      Val_mes  = as.numeric(GEN_VAL_MO),
      Val_acum = as.numeric(GEN_VAL_YR)
    )

  if (incr_mundo) {
    act <- actualizar_rds(mundo_previo, nuevo_mundo, llaves = "partida",
                          valor = "Val_mes", desde = desde_mundo,
                          nombre = "importaciones mundo autos/autopartes")
    mundo_previo   <- act$datos
    revision_mundo <- act$revision
    rm(act)
  } else {
    mundo_previo <- nuevo_mundo
  }
  rm(nuevo_mundo)
}
stopifnot("No existe imp_autos_mundo.rds: corre con DESCARGAR <- TRUE" = !is.null(mundo_previo))

imp_autos_mundo <- mundo_previo |> arrange(partida, fecha)
rm(mundo_previo)

stopifnot(
  "Filas duplicadas en el total mundial" = anyDuplicated(imp_autos_mundo[c("partida", "fecha")]) == 0,
  "El total mundial no llega al mismo mes que los países" =
    max(imp_autos_mundo$fecha) == max(raw_df$fecha)
)

#  Sección 3. Limpieza y México desde Query02                              ####

raw_mex <- readRDS(here("RDS", "raw_df_mex_vnm_twn.rds")) |>
  filter(Pais == "México", str_starts(I_COMMODITY, paste(partidas, collapse = "|")))

stopifnot(
  "México (Query02) y los demás países terminan en meses distintos: corre Query02 primero" =
    max(raw_mex$fecha) == max(raw_df$fecha)
)

imp_autos_socios <- bind_rows(
  raw_mex |> mutate(I_COMMODITY = as.character(I_COMMODITY)) |>
    select(any_of(names(raw_df))),
  raw_df
) |>
  mutate(
    cod     = I_COMMODITY,
    nivel   = case_when(
      nchar(cod) == 4  ~ "HS4",
      nchar(cod) == 6  ~ "HS6",
      nchar(cod) == 10 ~ "HS10",
      .default         = "otro"
    ),
    partida = substr(cod, 1, 4),
    Val_mes  = GEN_VAL_MO,
    Val_acum = GEN_VAL_YR
  ) |>
  select(Pais, fecha, partida, nivel, cod, Desc_api = I_COMMODITY_LDESC, Val_mes, Val_acum) |>
  arrange(Pais, partida, nivel, cod, fecha)

stopifnot("Hay niveles inesperados" = !any(imp_autos_socios$nivel == "otro"))
stopifnot("Filas duplicadas" = anyDuplicated(imp_autos_socios[c("Pais", "cod", "fecha")]) == 0)

# Los cuatro países (HS4) no pueden exceder el total mundial
chequeo_mundo <- imp_autos_socios |>
  filter(nivel == "HS4") |>
  group_by(partida, fecha) |>
  summarise(cuatro = sum(Val_mes), .groups = "drop") |>
  inner_join(imp_autos_mundo, by = c("partida", "fecha"))
stopifnot("Los cuatro países exceden el total mundial" = all(chequeo_mundo$cuatro <= chequeo_mundo$Val_mes))
rm(chequeo_mundo)

cat("\nCobertura por país y nivel:\n")
imp_autos_socios |>
  group_by(Pais, nivel) |>
  summarise(desde = min(fecha), hasta = max(fecha), n_cod = n_distinct(cod), .groups = "drop") |>
  print(n = 30)

#  Sección 4. Metadatos y guardado                                         ####

meta_query11 <- list(
  fuente         = "US Census Bureau — International Trade API",
  endpoint       = "timeseries/intltrade/imports/hs",
  url            = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga = Sys.time(),
  países         = "Japón (5880), Corea del Sur (5800), Alemania (4280); México derivado de raw_df_mex_vnm_twn.rds (Query02)",
  partidas       = "8703 (autos) y 8708 (autopartes), con todas sus subpartidas (HS6, HS10)",
  período        = paste(format(min(imp_autos_socios$fecha)), "a", format(max(imp_autos_socios$fecha))),
  solape_desde   = if (!is.null(desde)) format(desde) else NA_character_,
  ultimo_mes     = ultimo_mes,
  archivos       = list(
    raw_df_autos_socios = "Descarga cruda: Japón, Corea del Sur y Alemania (sin México)",
    imp_autos_socios    = "Los cuatro países, limpio: Pais, fecha, partida, nivel, cod, Val_mes, Val_acum",
    imp_autos_mundo     = "Total mundial (CTY_CODE '-') de 8703 y 8708, HS4: fecha, partida, Val_mes, Val_acum"
  ),
  notas          = paste(
    "Val_mes y Val_acum: importaciones generales (GEN_VAL_MO / GEN_VAL_YR), dólares corrientes.",
    "Alemania como proxy de la UE: el agregado de Census cambia de composición tras el Brexit.",
    "Sin cantidades (QTY) por ahora, para mantener simetría con los datos de México.",
    "El último año es parcial — no comparar contra años completos sin comparar los mismos meses."
  )
)

tryCatch({
  saveRDS(imp_autos_socios, here("RDS", "imp_autos_socios.rds"))
  message("✔  imp_autos_socios.rds guardado. Filas: ", nrow(imp_autos_socios))
  saveRDS(meta_query11, here("RDS", "meta_query11.rds"))
  message("✔  meta_query11.rds guardado.")
  saveRDS(imp_autos_mundo, ruta_mundo)
  message("✔  imp_autos_mundo.rds guardado. Filas: ", nrow(imp_autos_mundo))
  if (DESCARGAR)
    saveRDS(list(revision = revision_mundo, fecha = Sys.time()), here("RDS", "revision_q11_mundo.rds"))
}, error = function(e) message("✗  ERROR guardando: ", conditionMessage(e)))
