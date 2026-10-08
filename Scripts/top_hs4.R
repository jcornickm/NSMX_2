# ── 1. Cargar datos ──────────────────────────────────────────
imp_mex_top_hs4 <- readRDS(here::here("RDS", "imp_mex_top_hs4.rds"))
impMex     <- readRDS(here::here("RDS", "imp_mex_sec_cap.rds"))

# ── 2. Construir base de partidas por capítulo ───────────────
# Años de referencia: 2018, 2024, 2025
# (2018 = pre-pandemia; 2024 = base reciente; 2025 = año de análisis)

base_partidas <- imp_mex_top_hs4 |>
  filter(year(fecha) %in% c(2018, 2024, 2025)) |>
  group_by(Capítulo, Cap_corto, Cod_partida, Part_corto, Año = year(fecha)) |>
  summarise(Val_total = sum(Val_mes, na.rm = TRUE), .groups = "drop")

# Totales por capítulo × año (denominadores)
totales_cap <- impMex |>
  filter(year(fecha) == 2025, Capítulo %in% c(84, 85, 87, 90)) |>
  group_by(Capítulo) |>
  summarise(total_cap_2025 = sum(Val_mes, na.rm = TRUE), .groups = "drop")

# Totales generales × año (para porcentaje sobre exportaciones totales)
total_gral_2025 <- impMex |>
  filter(year(fecha) == 2025) |>
  summarise(total = sum(Val_mes, na.rm = TRUE)) |>
  pull(total)

# Tabla ancha: una columna por año
tabla_ancha <- base_partidas |>
  pivot_wider(names_from = Año, values_from = Val_total,
              names_prefix = "val_", values_fill = 0) |>
  left_join(totales_cap, by = "Capítulo") |>
  mutate(
    tcr_1824   = (val_2024 / val_2018)^(1/6) - 1,
    tcr_2425   = (val_2025 - val_2024) / val_2024,
    cambio_tcr = tcr_2425 - tcr_1824,
    pct_cap    = val_2025 / total_cap_2025,
    pct_total  = total_cap_2025 / total_gral_2025 * pct_cap
  ) |>
  arrange(Capítulo, desc(tcr_2425))

# Porcentajes acumulados dentro de cada capítulo
tabla_ancha <- tabla_ancha |>
  group_by(Capítulo) |>
  mutate(
    pct_cap_acum  = cumsum(pct_cap),
    pct_total_acum = cumsum(pct_total)
  ) |>
  ungroup()

# ── 3. Función para armar gt por capítulo ────────────────────

tabla_cap <- function(cap_num, datos = tabla_ancha) {
  
  cap_label <- datos |>
    filter(Capítulo == cap_num) |>
    pull(Cap_corto) |>
    first()
  
  total_2025 <- datos |>
    filter(Capítulo == cap_num) |>
    pull(total_cap_2025) |>
    first()
  
  df <- datos |>
    filter(Capítulo == cap_num) |>
    select(
      Partida       = Cod_partida,
      Descripción   = Part_corto,
      tcr_1824,
      tcr_2425,
      cambio_tcr,
      pct_cap,
      pct_cap_acum,
      pct_total,
      pct_total_acum
    )
  
  resto <- tibble(
    Partida        = "Resto",
    Descripción    = "Resto del capítulo",
    tcr_1824       = NA_real_,
    tcr_2425       = NA_real_,
    cambio_tcr     = NA_real_,
    pct_cap        = 1 - sum(df$pct_cap),
    pct_cap_acum   = 1,
    pct_total      = (total_2025 / total_gral_2025) - sum(df$pct_total),
    pct_total_acum = total_2025 / total_gral_2025
  )
  
  df <- bind_rows(df, resto)
  
  df |>
    gt() |>
    tab_header(
      title    = paste0("Capítulo ", cap_num, " — ", cap_label),
      subtitle = paste0("Importaciones EUA desde México por partida, 2025 | ",
                        "Total capítulo: USD ",
                        format(round(total_2025 / 1e9, 1), nsmall = 1), " mil millones")
    ) |>
    tab_spanner(
      label   = "Tasa de crecimiento",
      columns = c(tcr_1824, tcr_2425, cambio_tcr)
    ) |>
    tab_spanner(
      label   = "% dentro del capítulo",
      columns = c(pct_cap, pct_cap_acum)
    ) |>
    tab_spanner(
      label   = "% sobre exportaciones totales",
      columns = c(pct_total, pct_total_acum)
    ) |>
    cols_label(
      Partida        = "Partida",
      Descripción    = "Descripción",
      tcr_1824       = "CAGR 2018–2024",
      tcr_2425       = "Crec. 2024–2025",
      cambio_tcr     = "Cambio en tasa",
      pct_cap        = "% del capítulo",
      pct_cap_acum   = "% acum.",
      pct_total      = "% del total",
      pct_total_acum = "% acum."
    ) |>
    fmt_percent(
      columns  = c(tcr_1824, tcr_2425, cambio_tcr,
                   pct_cap, pct_cap_acum, pct_total, pct_total_acum),
      decimals = 1
    ) |>
    # Destacar filas donde la aceleración 2024-2025 > CAGR 2018-2024
    tab_style(
      style     = cell_fill(color = "#fff3cd"),   # amarillo suave
      locations = cells_body(rows = cambio_tcr > 0)
    ) |>
    # Destacar partidas que concentran > 5% del capítulo
    tab_style(
      style     = cell_text(weight = "bold"),
      locations = cells_body(rows = pct_cap >= 0.05)
    ) |>
    tab_source_note(
      "Elaboración propia con base en US Census Bureau, API de Comercio Internacional."
    ) |>
    tab_options(
      table.font.size     = 13,
      heading.align       = "left",
      column_labels.font.weight = "bold"
    )
}

# ── 4. Generar las cuatro tablas ─────────────────────────────

tab84 <- tabla_cap(84)
tab85 <- tabla_cap(85)
tab87 <- tabla_cap(87)
tab90 <- tabla_cap(90)

# Visualizar en el Viewer
tab84
tab85
tab87
tab90