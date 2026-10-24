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
# Figuras (Plots/, PDF + PNG), una por país y ventana:
#   fig_media_cloud_menciones_mex_2024 / _usa_2024 : terminan en FECHA_FIN (Cap. 2)
#   fig_media_cloud_menciones_mex      / _usa      : hasta ULTIMO_MES (Cap. 3)
#   Cada panel con su propia escala en y. El título general de la figura
#   lo pone el fig-cap del qmd; el título del panel solo identifica el país.
# =============================================================================

pacman::p_load(tidyverse, here, lubridate, zoo, scales)
source(here::here("Scripts", "funciones.R"))   # FECHA_FIN (ventana del Capítulo 2)

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
# 3. Figuras: conteo mensual de menciones (barras) + media móvil 3 meses (línea)
#    Una figura por país y por ventana (cada una con su propia escala en y):
#      - *_2024 : termina en FECHA_FIN (Capítulo 2)
#      - sin sufijo de año : hasta ULTIMO_MES (Capítulo 3)
#    Esta función solo necesita media_cloud_mensual.rds: el chunk de gráfica
#    puede pasar tal cual a los qmds.
# -----------------------------------------------------------------------------

# Hitos editoriales relevantes (cada versión muestra solo los que caen en su ventana)
hitos <- tibble(
  fecha = as.Date(c("2018-07-06",   # Aranceles China Ronda 1 (Lista 1)
                    "2020-07-01",   # Entrada en vigor T-MEC
                    "2022-02-01",   # Inicio publicación masiva nearshoring MX
                    "2025-01-20")), # Segundo gobierno Trump
  etiqueta = c("Aranceles\nEE.UU.-China", "T-MEC", "Auge\nnearshoring",
               "Aranceles\nTrump 2025")
)

# datos = tabla mensual larga (pais, anio_mes, menciones, mm3); pais_sel = "México" / "EUA"
fig_menciones <- function(datos, pais_sel, fecha_fin) {
  hitos_v <- hitos |> filter(fecha <= fecha_fin)

  datos |>
    filter(pais == pais_sel,
           anio_mes >= as.Date("2018-01-01"), anio_mes <= fecha_fin) |>
    ggplot(aes(x = anio_mes)) +
    # Barras de conteo mensual
    geom_col(aes(y = menciones), fill = "#457b9d", alpha = 0.7, width = 25) +
    # Media móvil
    geom_line(aes(y = mm3), color = "#e63946", linewidth = 0.8, na.rm = TRUE) +
    # Líneas verticales de hitos
    geom_vline(data = hitos_v, aes(xintercept = fecha),
               linetype = "dashed", color = "grey40", linewidth = 0.5) +
    # Etiquetas de hitos
    geom_text(data = hitos_v, aes(x = fecha, y = Inf, label = etiqueta),
              vjust = 1.3, hjust = -0.07, size = 2.8, color = "grey30",
              lineheight = 0.9) +
    scale_x_date(
      breaks = seq(as.Date("2018-01-01"), floor_date(fecha_fin, "year"), by = "1 year"),
      date_labels = "%Y",
      expand = expansion(mult = c(0.01, 0.04))
    ) +
    scale_y_continuous(labels = comma_format(big.mark = ",")) +
    labs(
      title = pais_sel,   # solo identifica el país; el título general va en el fig-cap del qmd
      x     = NULL,
      y     = "Menciones mensuales"
    ) +
    theme_bw() +
    theme(
      plot.title       = element_text(size = 11, face = "bold"),
      panel.grid.minor = element_blank(),
      axis.text.x      = element_text(angle = 0)
    )
}

ventanas <- tibble(
  ventana   = c("_2024", ""),
  fecha_fin = c(FECHA_FIN, ceiling_date(ULTIMO_MES, "month") - days(1))
)

figs <- expand_grid(select(fuentes, pais, sufijo), ventanas) |>
  mutate(nombre = paste0("fig_media_cloud_menciones_", sufijo, ventana))

figs_lista <- pmap(list(figs$pais, figs$fecha_fin),
                   \(p, f) fig_menciones(media_cloud_mensual, p, f)) |>
  set_names(figs$nombre)

# Guardar figuras (PDF para diseño/Word, PNG 150 dpi para Quarto)
iwalk(figs_lista, \(p, nm) {
  ggsave(here::here("Plots", paste0(nm, ".pdf")),
         plot = p, width = 10, height = 5, device = cairo_pdf)
  ggsave(here::here("Plots", paste0(nm, ".png")),
         plot = p, width = 10, height = 5, dpi = 150)
})

message("✓ Figuras guardadas en Plots/: ", paste(names(figs_lista), collapse = ", "))
