# =============================================================================
# Query 9 — Menciones de nearshoring en medios (Media Cloud)
# Fuente: Media Cloud, búsqueda "nearshoring Mexico", datos diarios 2018-2026
# =============================================================================

pacman::p_load(tidyverse, here, lubridate, zoo, scales)

# -----------------------------------------------------------------------------
# 1. Lectura y limpieza
# -----------------------------------------------------------------------------

ruta_csv <- here::here("Excel", "mc-onlinenews-mediacloud-20260611141803-counts.csv")

media_cloud_raw <- read_csv(ruta_csv, col_types = cols(
  date        = col_date(format = "%Y-%m-%d"),
  count       = col_integer(),
  total_count = col_integer(),
  ratio       = col_double()
))

# Metadatos
meta_media_cloud <- tibble(
  objeto      = "media_cloud_raw",
  descripcion = "Menciones diarias de 'nearshoring Mexico' en medios online (Media Cloud)",
  fuente      = "Media Cloud Online News Archive",
  fecha_inicio = min(media_cloud_raw$date),
  fecha_fin    = max(media_cloud_raw$date),
  n_filas      = nrow(media_cloud_raw),
  descargado   = "2026-06-11"
)

# Guardar
tryCatch({
  saveRDS(media_cloud_raw,   here::here("RDS", "media_cloud_raw.rds"))
  saveRDS(meta_media_cloud,  here::here("RDS", "meta_media_cloud.rds"))
  message("✓ media_cloud_raw.rds y meta_media_cloud.rds guardados.")
}, error = function(e) message("✗ Error al guardar: ", e$message))

# -----------------------------------------------------------------------------
# 2. Agregación mensual (base para la gráfica principal)
# -----------------------------------------------------------------------------

media_cloud_mensual <- media_cloud_raw |>
  mutate(anio_mes = floor_date(date, "month")) |>
  group_by(anio_mes) |>
  summarise(
    menciones  = sum(count,       na.rm = TRUE),
    total_dias = sum(total_count, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  # Ratio mensual: menciones sobre total de artículos indexados ese mes
  mutate(ratio_mensual = menciones / total_dias)

tryCatch({
  saveRDS(media_cloud_mensual, here::here("RDS", "media_cloud_mensual.rds"))
  message("✓ media_cloud_mensual.rds guardado.")
}, error = function(e) message("✗ Error al guardar: ", e$message))

# -----------------------------------------------------------------------------
# 3. Figura: conteo mensual de menciones (barras) + media móvil 3 meses (línea)
# -----------------------------------------------------------------------------

# Media móvil de 3 meses sobre el conteo mensual
media_cloud_mensual <- media_cloud_mensual |>
  mutate(mm3 = rollmean(menciones, k = 3, fill = NA, align = "right"))

# Hitos editoriales relevantes
hitos <- tibble(
  fecha = as.Date(c("2018-07-06",   # Aranceles China Ronda 1 (Lista 1)
                    "2020-07-01",   # Entrada en vigor T-MEC
                    "2022-02-01",   # Inicio publicación masiva nearshoring MX
                    "2025-01-20")), # Regreso Trump / aranceles 2025
  etiqueta = c("Aranceles\nEE.UU.-China", "T-MEC", "Auge\nnearshoring", "Aranceles\nTrump 2025")
)

p <- media_cloud_mensual |>
  filter(anio_mes >= as.Date("2018-01-01")) |>
  ggplot(aes(x = anio_mes)) +
  # Barras de conteo mensual
  geom_col(aes(y = menciones), fill = "#457b9d", alpha = 0.7, width = 25) +
  # Media móvil
  geom_line(aes(y = mm3), color = "#e63946", linewidth = 0.8, na.rm = TRUE) +
  # Líneas verticales de hitos
  geom_vline(data = hitos, aes(xintercept = fecha),
             linetype = "dashed", color = "grey40", linewidth = 0.5) +
  # Etiquetas de hitos
  geom_text(data = hitos, aes(x = fecha, y = Inf, label = etiqueta),
            vjust = 1.3, hjust = -0.07, size = 2.8, color = "grey30", lineheight = 0.9) +
  scale_x_date(
    breaks = seq(as.Date("2018-01-01"), as.Date("2026-01-01"), by = "1 year"),
    date_labels = "%Y",
    expand = expansion(mult = c(0.01, 0.04))
  ) +
  scale_y_continuous(labels = comma_format(big.mark = ",")) +
  labs(
    x = NULL,
    y = "Menciones mensuales"
  ) +
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x      = element_text(angle = 0)
  )

# Guardar figura
ggsave(here::here("Plots", "fig_media_cloud_menciones.pdf"),
       plot = p, width = 10, height = 5, device = cairo_pdf)
ggsave(here::here("Plots", "fig_media_cloud_menciones.png"),
       plot = p, width = 10, height = 5, dpi = 150)

message("✓ Figura guardada en Figuras/")

