# ============================================================================
# ied_plots_fbcf.R
#
# Objetivo: figuras de formación bruta de capital fijo (FBCF) privada y
#   pública, y FBCF privada por tipo de bien (construcción vs maquinaria y
#   equipo), a precios constantes de 2018. Código recibido de un colega
#   (graficos_FBCF_INEGI.R) y adaptado: lee RDS/fbcf_inegi.rds en vez del xlsx.
#
# Entrada:  RDS/fbcf_inegi.rds  (tidy, todas las series del Tabulado de INEGI)
#           RDS/meta_fbcf_inegi.rds
#           (origen: Excel/FBCF_INEGI_OUT_13.xlsx, hoja Tabulado)
# Salida:   Plots/ied_fbcf_privada_publica[_2024].{pdf,png}
#           Plots/ied_fbcf_privada_por_tipo_bien[_2024].{pdf,png}
#           Sufijo "_2024" = ventana del Cap. 2 (ANIO_FIN); sin sufijo = Cap. 3.
#
# Nota: el dato anual (promedio de 4 trimestres) llega hasta 2025 (preliminar);
#   2026 solo tiene T1-T2 y "6 Meses", que no se mezclan con anuales.
# ============================================================================

pacman::p_load(tidyverse, here, systemfonts)
source(here("Scripts", "funciones.R"))   # ANIO_FIN

fbcf <- readRDS(here("RDS", "fbcf_inegi.rds"))

# — Series anuales a precios constantes de 2018 (miles de millones de pesos) —
series_def <- tribble(
  ~serie,                 ~concepto_cod, ~comprador,
  "privada",              "P.51b",       "Privada",
  "publica",              "P.51b",       "Pública",
  "privada_construccion", "CT",          "Privada",
  "privada_maquinaria",   "AN.113",      "Privada"
)

datos <- fbcf |>
  filter(bloque_cod == "VCts18",
         medida == "Millones de pesos a precios de 2018",
         periodo == "Anual",
         !is.na(valor)) |>
  inner_join(series_def, by = c("concepto_cod", "comprador")) |>
  transmute(serie, anio = año, mil_mdp = valor / 1000)

anio_max <- max(datos$anio[datos$serie == "privada"])

# — Tasas de crecimiento (promedios) vs. 2010-2017 -----------------------------
prom <- function(s, a, b)
  mean(datos$mil_mdp[datos$serie == s & datos$anio >= a & datos$anio <= b])

tasas <- tibble(serie = series_def$serie) |>
  mutate(
    prom_2010_17     = map_dbl(serie, prom, a = 2010, b = 2017),
    prom_2022_24     = map_dbl(serie, prom, a = 2022, b = 2024),
    crec_2022_24_pct = 100 * (prom_2022_24 / prom_2010_17 - 1),
    prom_2023_25     = map_dbl(serie, prom, a = 2023, b = 2025),
    crec_2023_25_pct = 100 * (prom_2023_25 / prom_2010_17 - 1)
  )
print(tasas |> mutate(across(where(is.numeric), ~ round(.x, 1))), n = Inf)

# — Diseño ----------------------------------------------------------------
# (el rojo #E63946 del original se cambió por un violeta apagado)
col <- c(privada = "#264653", publica = "#7B6D8D",
         privada_construccion = "#2A9D8F", privada_maquinaria = "#E9C46A")
etq <- c(privada = "FBCF privada", publica = "FBCF pública",
         privada_construccion = "FBCF privada en construcción",
         privada_maquinaria = "FBCF privada en maquinaria y equipo")

fam <- if ("IBM Plex Sans" %in% systemfonts::system_fonts()$family) "IBM Plex Sans" else ""

fig_fbcf <- function(series, anio_fin) {
  datos |>
    filter(serie %in% series, anio <= anio_fin) |>
    ggplot(aes(anio, mil_mdp, colour = serie)) +
    geom_line(linewidth = 1) +
    geom_point(size = 1.4) +
    scale_colour_manual(values = col, labels = etq) +
    scale_x_continuous(breaks = seq(1995, 2025, 5)) +
    scale_y_continuous(labels = scales::label_comma(),
                       limits = c(0, NA),
                       expand = expansion(mult = c(0, 0.06))) +
    labs(x = NULL,
         y = "Miles de millones de pesos (precios de 2018)",
         caption = "Elaboración propia con base en INEGI, Oferta y Utilización Trimestral (año base 2018).") +
    theme_bw(base_size = 12, base_family = fam) +
    theme(panel.border     = element_rect(colour = "grey35", fill = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "grey92"),
          legend.position  = "bottom",
          legend.title     = element_blank())
}

# — Figuras: ventana Cap. 2 (_2024) y Cap. 3 (completa) --------------------
figs <- expand_grid(
  tipo    = c("privada_publica", "privada_por_tipo_bien"),
  ventana = c("_2024", "")
) |>
  mutate(
    series    = map(tipo, \(t) switch(t,
                      privada_publica       = c("privada", "publica"),
                      privada_por_tipo_bien = c("privada_construccion", "privada_maquinaria"))),
    anio_fin  = if_else(ventana == "_2024", ANIO_FIN, anio_max),
    nombre    = paste0("ied_fbcf_", tipo, ventana)
  )

figs_lista <- pmap(list(figs$series, figs$anio_fin), fig_fbcf) |>
  set_names(figs$nombre)

# Guardar (PDF para diseño/Word, PNG 150 dpi para Quarto)
iwalk(figs_lista, \(p, nm) {
  ggsave(here("Plots", paste0(nm, ".pdf")), plot = p,
         width = 10, height = 5.5, device = cairo_pdf)
  ggsave(here("Plots", paste0(nm, ".png")), plot = p,
         width = 10, height = 5.5, dpi = 150)
})

message("✓ Figuras guardadas en Plots/: ", paste(names(figs_lista), collapse = ", "))
