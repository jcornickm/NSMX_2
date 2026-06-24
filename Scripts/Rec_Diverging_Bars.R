
# — Períodos de comparación ---------------------------------------------------
periodos <- list(
  c(2010, 2025),
  c(2010, 2018),
  c(2018, 2024),
  c(2024, 2025)
)

# — Función: un gráfico por período -------------------------------------------
make_bar <- function(año_ini, año_fin) {
  
  cambios <- impPais_Perc |>
    filter(año %in% c(año_ini, año_fin)) |>
    select(País, año, share) |>
    pivot_wider(names_from = año, values_from = share,
                names_prefix = "y") |>
    mutate(
      cambio_pp   = (get(paste0("y", año_fin)) - get(paste0("y", año_ini))) * 100,
      País        = fct_reorder(País, cambio_pp),
      color_grupo = case_when(
        País == "China"  ~ "china",
        País == "México" ~ "mexico",
        cambio_pp > 0    ~ "positivo",
        TRUE             ~ "negativo"
      )
    )
  
  ggplot(cambios, aes(x = País, y = cambio_pp, fill = color_grupo)) +
    geom_col() +
    geom_text(
      aes(
        label = sprintf("%.1f", cambio_pp),
        vjust = if_else(cambio_pp > 0, -0.4, 1.4)
      ),
      size     = 2.8,
      fontface = "bold"
    ) +
    geom_hline(yintercept = 0, linewidth = 0.4, color = "grey30") +
    scale_y_continuous(
      labels = \(x) paste0(x, " pp"),
      expand = expansion(mult = c(0.18, 0.18))
    ) +
    scale_fill_manual(
      values = c(
        "china"    = "#8B0000",
        "mexico"   = "#B5651D",
        "positivo" = "#1F78B4",
        "negativo" = "#41ab5d"
      )
    ) +
    theme_bw() +
    labs(
      x     = NULL,
      y     = NULL,
      title = glue::glue("{año_ini} – {año_fin}")
    ) +
    theme(
      legend.position    = "none",
      panel.grid.major.x = element_blank(),
      axis.text.x        = element_text(angle = 90, vjust = 0.5, hjust = 1),
      axis.text.y        = element_text(size = 9)
    )
}

# — Generar y componer --------------------------------------------------------
plots <- map(periodos, \(p) make_bar(p[1], p[2]))

(plots[[1]] + plots[[2]]) / (plots[[3]] + plots[[4]])