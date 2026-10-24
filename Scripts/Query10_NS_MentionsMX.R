# =============================================================================
# Query10_NS_MentionsMX.R — Menciones de nearshoring en medios (Media Cloud)
# Fuente: Media Cloud (search.mediacloud.org), datos diarios desde 2018-01-01
# Búsqueda (igual para ambos países): "nearshoring OR reshoring" (nombre de la
#   búsqueda en la UI; en la URL, q = nearshoring,reshoring), plataforma
#   onlinenews-mediacloud, desde 2018-01-01. Solo cambia la colección:
#
#   México (cs = 34412427, Mexico - National), descarga 22-oct-2026, a 2026-10-21:
#   search.mediacloud.org/search?q=nearshoring%252Creshoring&nq=&start=01-01-2018&end=10-21-2026&p=onlinenews-mediacloud&ss=&cs=34412427&any=any&name=nearshoring%20OR%20reshoring&edit=false
#
#   EUA (cs = 34412234), descarga 24-oct-2026, a 2026-10-23:
#   search.mediacloud.org/search?q=nearshoring%252Creshoring&nq=&start=01-01-2018&end=10-23-2026&p=onlinenews-mediacloud&ss=&cs=34412234&any=any&name=nearshoring%20OR%20reshoring&edit=false
#
# CSV manuales (el CSV no guarda la consulta; queda documentada aquí).
#   Misma colección de México que el bloque Media Cloud-API de Query05, pero la
#   consulta de Query05 es solo "nearshoring" (aquí se suma "reshoring").
#
# Salidas (RDS en formato largo, una columna `pais` = "México" / "EUA"):
#   RDS/media_cloud_diario.rds  : pais, date, count, total_count, ratio
#   RDS/media_cloud_mensual.rds : pais, anio_mes, menciones, total_dias,
#                                 ratio_mensual, mm3 (media móvil 3 meses)
#   RDS/meta_media_cloud.rds    : una fila por país
# Figuras: ya no se generan aquí; ver el chunk `save-fig-media-cloud` al inicio
#   de la Introducción de Quarto/C2_Revised_October_2026_v2.qmd (PNG/PDF en Plots/).
# =============================================================================

pacman::p_load(tidyverse, here, lubridate, zoo, scales)

# Último mes COMPLETO que se usa en series mensuales y figuras.
# (oct-2026 es parcial; sept-2026 es el último mes completo a las descargas de oct-2026.)
ULTIMO_MES <- as.Date("2026-09-01")

# -----------------------------------------------------------------------------
# 1. Lectura y limpieza (ambos países, mismo procesamiento)
# -----------------------------------------------------------------------------

cols_mc <- cols(
  date        = col_date(format = "%Y-%m-%d"),
  count       = col_integer(),
  total_count = col_integer(),
  ratio       = col_double()
)

fuentes <- tribble(
  ~pais,    ~sufijo, ~archivo,                                     ~coleccion, ~descargado,
  "México", "mex",   "mc-onlinenews-mediacloud-october2026.csv",   34412427,   "2026-10-22",
  "EUA",    "usa",   "mc-onlinenews-mediacloud_USA.csv",           34412234,   "2026-10-24"
)

media_cloud_diario <- map2(fuentes$pais, fuentes$archivo,
                           \(p, f) read_csv(here::here("Excel", f), col_types = cols_mc) |>
                             mutate(pais = p, .before = 1)) |>
  list_rbind()

# Verificaciones básicas por país
verif <- media_cloud_diario |>
  group_by(pais) |>
  summarise(
    n_dias     = n(),
    desde      = min(date),
    hasta      = max(date),
    duplicadas = sum(duplicated(date)),
    faltantes  = length(setdiff(seq(min(date), max(date), by = "day"), date)),
    n_na       = sum(is.na(count) | is.na(total_count)),
    .groups = "drop"
  )
message("Verificación de los CSV:")
print(verif)

# Control de revisiones (solo México): traslape fecha por fecha contra la
# descarga previa (junio-2026, búsqueda "nearshoring Mexico"; se conserva solo para esto)
ruta_csv_prev    <- here::here("Excel", "mc-onlinenews-mediacloud-20260611141803-counts.csv")
media_cloud_prev <- read_csv(ruta_csv_prev, col_types = cols_mc)

rev <- inner_join(media_cloud_prev,
                  filter(media_cloud_diario, pais == "México") |> select(-pais),
                  by = "date", suffix = c("_prev", "_new")) |>
  mutate(d_count = count_new - count_prev,
         d_total = total_count_new - total_count_prev)

message("Traslape con descarga previa (México): ", nrow(rev), " días (",
        min(rev$date), " a ", max(rev$date), ")")
message("Días con 'count' revisado: ", sum(rev$d_count != 0, na.rm = TRUE),
        " | con 'total_count' revisado: ", sum(rev$d_total != 0, na.rm = TRUE))

rev_mes <- rev |>
  mutate(anio_mes = floor_date(date, "month")) |>
  group_by(anio_mes) |>
  summarise(menc_prev = sum(count_prev), menc_new = sum(count_new),
            d_menc = menc_new - menc_prev,
            tot_prev = sum(total_count_prev), tot_new = sum(total_count_new),
            d_tot = tot_new - tot_prev, .groups = "drop") |>
  filter(d_menc != 0 | d_tot != 0)

if (nrow(rev_mes) > 0) {
  message("Meses con revisiones (traslape con la descarga previa):")
  print(rev_mes, n = 30)
} else message("Sin revisiones en el traslape.")

# Metadatos (una fila por país)
meta_media_cloud <- fuentes |>
  left_join(verif, by = "pais") |>
  transmute(
    pais,
    descripcion = "Menciones diarias de 'nearshoring OR reshoring' en medios online (Media Cloud)",
    fuente      = paste0("Media Cloud Online News Archive (colección ", coleccion, ")"),
    archivo     = paste0("Excel/", archivo),
    fecha_inicio = desde,
    fecha_fin    = hasta,
    n_filas      = n_dias,
    descargado,
    ultimo_mes_completo = ULTIMO_MES,
    nota = "diario completo (incluye oct-2026 parcial); mensual y figuras cortan en ultimo_mes_completo"
  )

# -----------------------------------------------------------------------------
# 2. Agregación mensual (base para las gráficas)
# -----------------------------------------------------------------------------

media_cloud_mensual <- media_cloud_diario |>
  mutate(anio_mes = floor_date(date, "month")) |>
  filter(anio_mes <= ULTIMO_MES) |>          # excluye meses parciales
  group_by(pais, anio_mes) |>
  summarise(
    menciones  = sum(count,       na.rm = TRUE),
    total_dias = sum(total_count, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  arrange(pais, anio_mes) |>
  # Ratio mensual: menciones sobre total de artículos indexados ese mes
  mutate(ratio_mensual = menciones / total_dias) |>
  # Media móvil de 3 meses sobre el conteo mensual, por país
  group_by(pais) |>
  mutate(mm3 = rollmean(menciones, k = 3, fill = NA, align = "right")) |>
  ungroup()

# Guardar
tryCatch({
  saveRDS(media_cloud_diario,  here::here("RDS", "media_cloud_diario.rds"))
  saveRDS(media_cloud_mensual, here::here("RDS", "media_cloud_mensual.rds"))
  saveRDS(meta_media_cloud,    here::here("RDS", "meta_media_cloud.rds"))
  message("✓ media_cloud_diario.rds, media_cloud_mensual.rds y meta_media_cloud.rds guardados.")
}, error = function(e) message("✗ Error al guardar: ", e$message))

# -----------------------------------------------------------------------------
# Las figuras (conteo mensual + media móvil de 3 meses, ventanas _2024 y completa)
# ya no se generan aquí: el código está en el chunk `save-fig-media-cloud`, al
# inicio de la Introducción de Quarto/C2_Revised_October_2026_v2.qmd, y lee
# RDS/media_cloud_mensual.rds.
# -----------------------------------------------------------------------------

message("✓ Query10 completado: RDS de Media Cloud guardados en RDS/.")
