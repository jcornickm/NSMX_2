# Explora_Top_Partidas_Periodos.R   ####
# Comparación de las partidas principales (HS4) de los Caps. 84, 85, 87 y 90
# según el periodo usado para identificarlas: 2024, 2025 y enero–último mes de 2026.
#
# Regla (la misma de Prep02): dentro de cada capítulo, partidas ordenadas por
# valor en el periodo; se incluyen hasta cruzar el 80% acumulado.
#
# Script exploratorio. Guarda RDS/top_partidas_periodos.rds y, en Tablas/, la tabla
# con formato (.rds y .docx). Lee la fuente maestra (Query02), así que no depende
# de que Prep02 se haya corrido.
#
# Parámetros ---------------------------------------------------------------
# · UMBRAL:            acumulado del capítulo que define "partida principal".
# · PARTIDAS_FORZADAS: se muestran siempre en la tabla, aunque no sean top en
#                      ningún periodo (8703 = automóviles, por importancia histórica).

pacman::p_load(tidyverse, here, scales, flextable)

source(here("Scripts", "funciones.R"))   # hs_agregar_etiquetas(), hs_etiquetas_partida()

caps_seleccionados <- c(84, 85, 87, 90)
UMBRAL             <- 0.80
PARTIDAS_FORZADAS  <- "8703"
meses_es           <- c("ene", "feb", "mar", "abr", "may", "jun",
                        "jul", "ago", "sep", "oct", "nov", "dic")

#  Sección 1. Partidas HS4 de México (fuente maestra)                       ####

message("\n=== Leyendo raw_df_mex_vnm_twn.rds (México, HS4, caps. 84/85/87/90) ===")

datos_hs4 <- readRDS(here("RDS", "raw_df_mex_vnm_twn.rds")) |>
  filter(Pais == "México", nchar(as.character(I_COMMODITY)) == 4) |>
  transmute(
    fecha            = as.Date(paste0(time, "-01")),
    cod              = as.character(I_COMMODITY),
    I_COMMODITY_LDESC,
    Capítulo         = as.integer(substr(cod, 1, 2)),
    Val_mes          = as.numeric(GEN_VAL_MO)
  ) |>
  filter(Capítulo %in% caps_seleccionados) |>
  hs_agregar_etiquetas() |>
  transmute(
    fecha, Capítulo, Cap_corto,
    Cod_partida      = cod,
    Desc_api_partida = as.character(I_COMMODITY_LDESC),
    Val_mes
  )

fecha_max <- max(datos_hs4$fecha)
mes_corte <- month(fecha_max)
anio_act  <- year(fecha_max)
etiqueta_ytd <- paste0("ene–", meses_es[mes_corte], " ", anio_act)

cat("Último mes disponible:", format(fecha_max), "| periodo parcial:", etiqueta_ytd, "\n")

periodos <- tribble(
  ~id,    ~etiqueta,    ~anio,     ~mes_hasta,
  "p24",  "2024",       2024L,     12L,
  "p25",  "2025",       2025L,     12L,
  "p26",  etiqueta_ytd, anio_act,  mes_corte
)

#  Sección 2. Ranking por capítulo y periodo                                ####

ranking_periodo <- function(df, anio, mes_hasta, id) {
  df |>
    filter(year(fecha) == anio, month(fecha) <= mes_hasta) |>
    group_by(Capítulo, Cod_partida) |>
    summarise(Val = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    group_by(Capítulo) |>
    arrange(desc(Val), .by_group = TRUE) |>
    mutate(
      share_cap  = Val / sum(Val),
      share_acum = cumsum(share_cap),
      rank_cap   = row_number(),
      top        = lag(share_acum, default = 0) < UMBRAL
    ) |>
    ungroup() |>
    select(Cod_partida, Val, share_cap, rank_cap, top) |>
    rename_with(~ paste0(.x, "_", id), -Cod_partida)
}

rankings <- pmap(periodos, \(id, etiqueta, anio, mes_hasta)
                 ranking_periodo(datos_hs4, anio, mes_hasta, id))

# Descripción más reciente de cada partida
desc_partida <- datos_hs4 |>
  group_by(Cod_partida) |>
  slice_max(fecha, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

#  Sección 3. Tabla comparativa (unión de las tres listas + forzadas)       ####

tabla_comp <- reduce(rankings, full_join, by = "Cod_partida") |>
  mutate(across(starts_with("top_"), ~ replace_na(.x, FALSE))) |>
  filter(top_p24 | top_p25 | top_p26 | Cod_partida %in% PARTIDAS_FORZADAS) |>
  left_join(desc_partida, by = "Cod_partida") |>
  hs_etiquetas_partida(estricto = FALSE) |>
  mutate(
    n_listas = top_p24 + top_p25 + top_p26,
    patron   = paste0(if_else(top_p24, "●", "○"),
                      if_else(top_p25, "●", "○"),
                      if_else(top_p26, "●", "○")),
    cambio   = case_when(
      n_listas == 3                    ~ "En las tres",
      n_listas == 0                    ~ "En ninguna (forzada)",
      top_p24 & top_p25 & !top_p26     ~ "Sale en 2026",
      !top_p24 & !top_p25 & top_p26    ~ "Entra en 2026",
      !top_p24 & top_p25 & top_p26     ~ "Entra en 2025",
      top_p24 & !top_p25 & top_p26     ~ "Sale en 2025, vuelve en 2026",
      top_p24 & !top_p25 & !top_p26    ~ "Solo 2024",
      !top_p24 & top_p25 & !top_p26    ~ "Solo 2025",
      .default                         = "Otro"
    ),
    forzada  = Cod_partida %in% PARTIDAS_FORZADAS
  ) |>
  arrange(Capítulo, desc(n_listas), desc(Val_p25))

#  Sección 4. Resultados en consola                                         ####

cat("\n=== Número de partidas principales por capítulo y periodo ===\n")
tabla_comp |>
  group_by(Capítulo, Cap_corto) |>
  summarise(
    `2024`        = sum(top_p24),
    `2025`        = sum(top_p25),
    !!etiqueta_ytd := sum(top_p26),
    `en las tres` = sum(n_listas == 3),
    `unión`       = sum(n_listas > 0),
    .groups = "drop"
  ) |>
  bind_rows(
    tibble(Capítulo = NA_integer_, Cap_corto = "TOTAL",
           `2024` = sum(tabla_comp$top_p24), `2025` = sum(tabla_comp$top_p25),
           !!etiqueta_ytd := sum(tabla_comp$top_p26),
           `en las tres` = sum(tabla_comp$n_listas == 3),
           `unión` = sum(tabla_comp$n_listas > 0))
  ) |>
  print(n = Inf)

cat("\n=== Partidas que NO están en las tres listas (patrón: 2024 · 2025 · ", etiqueta_ytd, ") ===\n", sep = "")
tabla_comp |>
  filter(n_listas < 3) |>
  transmute(Capítulo, Cod_partida, Part_corto, patron, cambio,
            rank_24 = rank_cap_p24, rank_25 = rank_cap_p25, rank_26 = rank_cap_p26,
            `%cap_24` = round(100 * share_cap_p24, 1),
            `%cap_25` = round(100 * share_cap_p25, 1),
            `%cap_26` = round(100 * share_cap_p26, 1)) |>
  print(n = Inf)

cat("\n=== Partidas forzadas: ", paste(PARTIDAS_FORZADAS, collapse = ", "), " ===\n", sep = "")
tabla_comp |>
  filter(forzada) |>
  transmute(Capítulo, Cod_partida, Part_corto, patron,
            rank_24 = rank_cap_p24, rank_25 = rank_cap_p25, rank_26 = rank_cap_p26,
            `%cap_24` = round(100 * share_cap_p24, 1),
            `%cap_25` = round(100 * share_cap_p25, 1),
            `%cap_26` = round(100 * share_cap_p26, 1)) |>
  print(n = Inf)

#  Sección 5. Tabla flextable (revisión; no se guarda)                      ####

tabla_flex <- tabla_comp |>
  transmute(
    Capítulo   = paste0(Capítulo, " – ", Cap_corto),
    Partida    = Cod_partida,
    Nombre     = Part_tabla,
    v24        = Val_p24 / 1e6, v25 = Val_p25 / 1e6, v26 = Val_p26 / 1e6,
    s24        = 100 * share_cap_p24, s25 = 100 * share_cap_p25, s26 = 100 * share_cap_p26,
    patron,
    cambio
  ) |>
  flextable() |>
  set_header_labels(
    Nombre = "Nombre",
    v24 = "2024", v25 = "2025", v26 = etiqueta_ytd,
    s24 = "2024", s25 = "2025", s26 = etiqueta_ytd,
    patron = "Top (24·25·26)", cambio = "Cambio"
  ) |>
  add_header_row(values = c("", "Valor (millones USD)", "Participación en el capítulo (%)", "", ""),
                 colwidths = c(3, 3, 3, 1, 1)) |>
  colformat_double(j = c("v24", "v25", "v26"), big.mark = ",", digits = 0) |>
  colformat_double(j = c("s24", "s25", "s26"), digits = 1) |>
  add_header_lines("Partidas (HS4) principales de EUA desde México según periodo de identificación (80% acumulado por capítulo)") |>
  add_footer_lines("● = en la lista del periodo; ○ = fuera. Elaboración propia con base en U.S. Census Bureau, International Trade API.") |>
  theme_booktabs() |>
  autofit()

tabla_flex

#  Sección 6. Guardado                                                      ####
# · RDS/top_partidas_periodos.rds    : lista con los datos (tabla, periodos, parámetros).
#                                      Robusto a cambios de versión de paquetes.
# · Tablas/top_partidas_periodos.rds : objeto flextable; el qmd lo lee y lo imprime.
# · Tablas/top_partidas_periodos.docx: copia para revisión (hoja horizontal, 9" de ancho).
#   Nota: el .rds del flextable queda a ancho natural; para un qmd en hoja vertical
#   (6" útiles) habrá que aplicar fit_to_width(max_width = 6, unit = "in") al cargarlo.

dir.create(here("Tablas"), showWarnings = FALSE)

tryCatch({
  saveRDS(list(
    tabla          = tabla_comp,
    periodos       = periodos,
    umbral         = UMBRAL,
    forzadas       = PARTIDAS_FORZADAS,
    ultimo_mes     = fecha_max,
    fecha_creación = Sys.time()
  ), here("RDS", "top_partidas_periodos.rds"))
  message("✔  RDS/top_partidas_periodos.rds guardado (", nrow(tabla_comp), " partidas).")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

tryCatch({
  saveRDS(tabla_flex, here("Tablas", "top_partidas_periodos.rds"))
  message("✔  Tablas/top_partidas_periodos.rds guardado.")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

tryCatch({
  # Hoja horizontal carta (márgenes de 0.75"; ancho útil 9.5") y tabla ajustada
  # a 9" de ancho: con 11 columnas no cabe en hoja vertical.
  tabla_docx <- tabla_flex |>
    flextable::fontsize(size = 9, part = "all") |>
    flextable::autofit() |>
    flextable::fit_to_width(max_width = 9, unit = "in")
  
  flextable::save_as_docx(
    tabla_docx,
    path = here("Tablas", "top_partidas_periodos.docx"),
    pr_section = officer::prop_section(
      page_size    = officer::page_size(orient = "landscape", width = 8.5, height = 11),
      page_margins = officer::page_mar(left = 0.75, right = 0.75, top = 0.75, bottom = 0.75)
    )
  )
  message("✔  Tablas/top_partidas_periodos.docx guardado.")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

cat("\nListo.\n")
