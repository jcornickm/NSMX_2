#======
# Query google trends
#======

pacman::p_load(gtrendsR)
res <- gtrends("nearshoring", geo = "MX", time = "2018-01-01 2026-01-01")
plot(res)


# ============================================================================
# Query9_GDELT.R
#
# Objetivo: Contar menciones mensuales del término "nearshoring" en noticias
#   indexadas por GDELT con geocódigo México, desde enero 2018.
#
# Fuente:
#   GDELT Project — Global Knowledge Graph v2
#   Tabla pública BigQuery: gdelt-bq.gdeltv2.gkg
#   Documentación: https://blog.gdeltproject.org/gdelt-2-0-our-every-growing-global-world/
#
# Prerequisitos:
#   1. Cuenta Google Cloud con BigQuery API habilitada
#   2. ID de proyecto GCP en .Renviron como GCP_PROJECT_ID
#   3. Autenticación: bq_auth() interactivo la primera vez (guarda token en cache)
#
# RDS producido (carpeta RDS/):
#   gdelt_nearshoring_mx.rds
#   meta_gdelt_nearshoring_mx.rds
#
# ============================================================================

pacman::p_load(tidyverse, bigrquery, here, lubridate)


# ----------------------------------------------------------------------------
# Credenciales
# ----------------------------------------------------------------------------
gcp_project <- Sys.getenv("GCP_PROJECT_ID")
stopifnot("GCP_PROJECT_ID no encontrado en .Renviron" = nchar(gcp_project) > 0)

# Autenticación interactiva (solo necesaria la primera vez por sesión)
bq_auth()

# ----------------------------------------------------------------------------
# Query BigQuery
# ----------------------------------------------------------------------------
# Notas sobre la tabla gdelt-bq.gdeltv2.gkg:
#   - DATE: string YYYYMMDDHHMMSS
#   - SOURCECOUNTRY: código ISO2 del país de la fuente (no siempre disponible)
#   - LOCATIONS: campo de texto con menciones geográficas; incluye "#Mexico#"
#   - V2Themes: temas; GDELT no tiene tema nativo para "nearshoring"
#   - Estrategia: buscar "nearshoring" en el campo DocumentIdentifier (URL)
#     O en V2Themes/AllNames, pero lo más robusto es buscar en las URLs
#     que GDELT indexa junto con su geocódigo de México.
#
# Limitación: GKG no contiene el texto completo; la aproximación más confiable
# es contar artículos donde (a) LOCATIONS contiene México Y (b) la URL
# contiene "nearshoring" — lo que captura principalmente medios especializados.
# Una alternativa es usar el campo Tone + V2Themes pero requiere validación.
#
# Mejor aproximación disponible sin texto completo:
# Buscar "nearshoring" en el campo DocumentIdentifier (URL del artículo)
# restringiendo a fuentes con código de país México.
# Esto subestima menciones (no todos los artículos tienen "nearshoring" en URL)
# pero es metodológicamente limpio.
sql_query <- "
SELECT
  CAST(SUBSTR(CAST(DATE AS STRING), 1, 6) AS INT64)  AS ano_mes,
  COUNT(*)                                             AS n_articulos
FROM
  `gdelt-bq.gdeltv2.gkg`
WHERE
  DATE >= 20180101000000
  AND LOCATIONS LIKE '%#Mexico#%'
  AND LOWER(DocumentIdentifier) LIKE '%nearshoring%'
GROUP BY
  ano_mes
ORDER BY
  ano_mes
"

# ----------------------------------------------------------------------------
# Ejecutar query
# ----------------------------------------------------------------------------
message("Ejecutando query en BigQuery (tabla gdelt-bq.gdeltv2.gkg)...")
message("Nota: la tabla tiene ~500 GB; esta query puede tardar 1-3 minutos.")

gdelt_raw <- tryCatch(
  bq_project_query(gcp_project, sql_query) |>
    bq_table_download(),
  error = function(e) {
    message("Error en BigQuery: ", conditionMessage(e))
    NULL
  }
)

if (is.null(gdelt_raw)) stop("La descarga falló. Revisa credenciales y proyecto GCP.")

# ----------------------------------------------------------------------------
# Limpieza y formato
# ----------------------------------------------------------------------------
gdelt_mx <- gdelt_raw |>
  mutate(
    fecha = ym(ano_mes),
    año   = year(fecha),
    mes   = month(fecha)
  ) |>
  select(fecha, año, mes, n_articulos) |>
  arrange(fecha)

message("Registros descargados: ", nrow(gdelt_mx))
message("Período: ", min(gdelt_mx$fecha), " — ", max(gdelt_mx$fecha))

# ----------------------------------------------------------------------------
# Guardar RDS
# ----------------------------------------------------------------------------
meta_gdelt <- list(
  objeto      = "gdelt_mx",
  descripcion = "Menciones mensuales de 'nearshoring' en noticias indexadas por GDELT con geocódigo México",
  fuente      = "GDELT Project — Global Knowledge Graph v2 (gdelt-bq.gdeltv2.gkg)",
  fecha_descarga = Sys.Date(),
  periodo     = paste(min(gdelt_mx$fecha), "—", max(gdelt_mx$fecha)),
  n_obs       = nrow(gdelt_mx),
  nota_metodologica = paste(
    "Conteo de artículos donde (1) el campo LOCATIONS contiene '#Mexico#'",
    "y (2) la URL (DocumentIdentifier) contiene 'nearshoring'.",
    "Subestima el total de menciones porque no todos los artículos",
    "incluyen el término en la URL. Aproximación metodológicamente conservadora."
  )
)

tryCatch({
  saveRDS(gdelt_mx,    here::here("RDS", "gdelt_nearshoring_mx.rds"))
  saveRDS(meta_gdelt,  here::here("RDS", "meta_gdelt_nearshoring_mx.rds"))
  message("RDS guardados exitosamente.")
}, error = function(e) message("Error al guardar RDS: ", conditionMessage(e)))


gdelt_mx |>
  ggplot(aes(x = fecha, y = n_articulos)) +
  geom_line(color = "#457b9d") +
  geom_point(size = 1.5, color = "#457b9d") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = scales::comma) +
  labs(x = NULL, y = "Artículos por mes",
       caption = "Fuente: GDELT Project — GKG v2") +
  theme_bw() +
  theme(panel.grid.minor = element_blank())





#=======
# query Media cloud
# ==============
mc_dir <- mc_api$DirectoryApi(mc_key)
resultados <- mc_dir$collection_list(name = "Mexico")
print(resultados)

resultado <- mc_search$story_count(
  query          = "nearshoring",
  start_date     = as.Date("2024-01-01"),
  end_date       = as.Date("2024-12-31"),
  collection_ids = list(34412427L)
)

print(resultado)


# ============================================================================
# Query10_MediaCloud.R
#
# Objetivo: Contar menciones mensuales de "nearshoring" en medios nacionales
#   de México indexados por Media Cloud, desde enero 2018.
#
# Fuente:
#   Media Cloud Online News Archive
#   Coleccion: Mexico - National (id: 34412427)
#   https://search.mediacloud.org
#
# Prerequisitos:
#   MEDIACLOUD_API_KEY en .Renviron
#   reticulate::py_require("mediacloud") ejecutado en la sesion
#
# RDS producidos (carpeta RDS/):
#   mediacloud_nearshoring_mx.rds
#   meta_mediacloud_nearshoring_mx.rds
#
# ============================================================================

library(reticulate)
reticulate::py_require("mediacloud")
pacman::p_load(tidyverse, lubridate, here)

# ----------------------------------------------------------------------------
# Credenciales y conexion
# ----------------------------------------------------------------------------
mc_key <- Sys.getenv("MEDIACLOUD_API_KEY")
stopifnot("MEDIACLOUD_API_KEY no encontrado" = nchar(mc_key) > 0)

mc_api    <- import("mediacloud.api")
mc_search <- mc_api$SearchApi(mc_key)

COLECCION_MX <- 34412427L   # Mexico - National

# ----------------------------------------------------------------------------
# Iterar por mes desde enero 2018
# ----------------------------------------------------------------------------
# Generamos una secuencia de fechas de inicio de cada mes
fechas_inicio <- seq(as.Date("2018-01-01"), as.Date("2026-05-01"), by = "month")
fechas_fin    <- ceiling_date(fechas_inicio, "month") - days(1)

message("Descargando conteos mensuales (", length(fechas_inicio), " meses)...")

resultados <- map2(fechas_inicio, fechas_fin, function(f_ini, f_fin) {
  
  res <- tryCatch(
    mc_search$story_count(
      query          = "nearshoring",
      start_date     = f_ini,
      end_date       = f_fin,
      collection_ids = list(COLECCION_MX)
    ),
    error = function(e) {
      message("Error en ", f_ini, ": ", conditionMessage(e))
      list(relevant = NA_integer_, total = NA_integer_)
    }
  )
  
  Sys.sleep(0.5)   # respetar rate limit
  
  tibble(
    fecha      = f_ini,
    n_articulos = res$relevant,
    n_total     = res$total
  )
})

mc_mx <- bind_rows(resultados) |>
  mutate(
    año = year(fecha),
    mes = month(fecha),
    pct = n_articulos / n_total * 100
  ) |>
  arrange(fecha)

message("Registros: ", nrow(mc_mx))
message("Periodo: ", min(mc_mx$fecha), " - ", max(mc_mx$fecha))
message("Total articulos con nearshoring: ", sum(mc_mx$n_articulos, na.rm = TRUE))

# ----------------------------------------------------------------------------
# Guardar RDS
# ----------------------------------------------------------------------------
meta_mc <- list(
  objeto      = "mc_mx",
  descripcion = "Menciones mensuales de 'nearshoring' en medios nacionales de Mexico (Media Cloud)",
  fuente      = "Media Cloud Online News Archive — Mexico National (id: 34412427)",
  fecha_descarga = Sys.Date(),
  periodo     = paste(min(mc_mx$fecha), "-", max(mc_mx$fecha)),
  n_obs       = nrow(mc_mx),
  coleccion   = "Mexico - National",
  coleccion_id = 34412427L,
  n_fuentes   = 647L,
  nota        = "n_articulos = conteo de historias con 'nearshoring' en titulo o texto; pct = porcentaje sobre total indexado ese mes"
)

tryCatch({
  saveRDS(mc_mx,   here::here("RDS", "mediacloud_nearshoring_mx.rds"))
  saveRDS(meta_mc, here::here("RDS", "meta_mediacloud_nearshoring_mx.rds"))
  message("RDS guardados exitosamente.")
}, error = function(e) message("Error al guardar: ", conditionMessage(e)))
