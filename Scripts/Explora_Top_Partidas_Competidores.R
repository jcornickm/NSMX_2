# Explora_Top_Partidas_Competidores.R   ####
# ¿Cambian las "partidas en competencia" (México vs. Vietnam y Taiwán) según el
# periodo con que se identifican las partidas principales de cada país?
#
# Replica el método de Prep03 (Top 50 HS4 por valor, en TODOS los capítulos, y
# luego se descartan los capítulos sin interés para NS; partida "en competencia"
# = aparece en la lista de 2 o más países) bajo tres periodos:
#   p24 = 2024
#   p25 = 2025
#   p26 = enero–último mes disponible de 2026
#
# Script exploratorio: no modifica ningún RDS del pipeline. Lee
# RDS/imp_competidores_hs4.rds (Query02).
#
# Parámetros ---------------------------------------------------------------
# · TOP_N:             tamaño de la lista por país ANTES de depurar (50, como Prep03).
# · capitulos_excluir: igual que en Prep03.

pacman::p_load(tidyverse, here, scales, flextable)

source(here("Scripts", "funciones.R"))   # hs_etiquetas_partida()

set_flextable_defaults(fonts_ignore = TRUE)

TOP_N           <- 50
paises_analisis <- c("México", "Vietnam", "Taiwán")
meses_es        <- c("ene", "feb", "mar", "abr", "may", "jun",
                     "jul", "ago", "sep", "oct", "nov", "dic")

# Se excluye por NÚMERO de capítulo (idéntico a Prep03)
capitulos_excluir <- c(
  1:27,         # Secciones I–V: animales, vegetales, alimentos, minerales y combustibles
  39, 40,       # Plásticos y caucho
  42,           # Artículos de cuero
  50:67,        # Textiles, prendas, calzado y sombreros (Secciones XI y XII)
  70,           # Vidrio
  71,           # Joyería
  94, 95,       # Muebles y juguetes
  98, 99        # Provisiones especiales de clasificación de EUA
)

#  Sección 1. Datos                                                         ####

datos <- readRDS(here("RDS", "imp_competidores_hs4.rds")) |>
  filter(Pais %in% paises_analisis) |>
  select(Pais, fecha, Capítulo, Cap_corto, Cod_partida, Desc_api_partida, Val_mes)

fecha_max    <- max(datos$fecha)
mes_corte    <- month(fecha_max)
anio_act     <- year(fecha_max)
etiqueta_ytd <- paste0("ene–", meses_es[mes_corte], " ", anio_act)

cat("Último mes disponible:", format(fecha_max), "| periodo parcial:", etiqueta_ytd, "\n")
cat("Filas:", nrow(datos), "| países:", paste(unique(datos$Pais), collapse = ", "), "\n")

periodos <- list(
  p24 = list(etiqueta = "2024",                      anios = 2024L,       mes_hasta = 12L),
  p25 = list(etiqueta = "2025",                      anios = 2025L,       mes_hasta = 12L),
  p26 = list(etiqueta = etiqueta_ytd,                anios = anio_act,    mes_hasta = mes_corte)
)
ids_periodos <- names(periodos)

# Descripción más reciente de cada partida
desc_partida <- datos |>
  group_by(Cod_partida) |>
  slice_max(fecha, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

#  Sección 2. Lista de cada país en cada periodo (método de Prep03)         ####
# Top TOP_N por valor entre TODAS las partidas del país, y después se descartan
# los capítulos excluidos (la lista depurada puede tener menos de TOP_N).

lista_pais_periodo <- function(pais, id) {
  per <- periodos[[id]]
  datos |>
    filter(Pais == pais, year(fecha) %in% per$anios, month(fecha) <= per$mes_hasta) |>
    group_by(Cod_partida) |>
    summarise(Val = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    arrange(desc(Val)) |>
    slice_head(n = TOP_N) |>
    mutate(rank = row_number()) |>
    left_join(select(desc_partida, Cod_partida, Capítulo), by = "Cod_partida") |>
    filter(!Capítulo %in% capitulos_excluir) |>
    transmute(Pais = pais, per = id, Cod_partida, rank_pais = rank, Val)
}

miembros <- expand_grid(pais = paises_analisis, id = ids_periodos) |>
  pmap_dfr(\(pais, id) lista_pais_periodo(pais, id)) |>
  mutate(per = factor(per, levels = ids_periodos))

cat("\n=== Partidas en la lista depurada de cada país, por periodo ===\n")
miembros |>
  count(Pais, per) |>
  pivot_wider(names_from = per, values_from = n) |>
  rename_with(~ map_chr(.x, \(i) periodos[[i]]$etiqueta), all_of(ids_periodos)) |>
  print()

#  Sección 3. Partidas en competencia (2+ países) por periodo               ####

competencia <- miembros |>
  group_by(per, Cod_partida) |>
  summarise(n_paises = n_distinct(Pais), .groups = "drop") |>
  filter(n_paises >= 2)

cat("\n=== Partidas en competencia (2+ países) por periodo ===\n")
competencia |>
  group_by(per) |>
  summarise(`2+ países` = n(), `3 países` = sum(n_paises == 3), .groups = "drop") |>
  mutate(periodo = map_chr(as.character(per), \(i) periodos[[i]]$etiqueta), .before = 1) |>
  select(-per) |>
  print()

# Partidas que están en competencia en al menos un periodo
cod_comp <- sort(unique(competencia$Cod_partida))

#  Sección 4. Tabla comparativa                                             ####
# Para cada partida con competencia en algún periodo: en qué listas de país
# aparece (patrón de 3 puntos: 2024 · 2025 · ytd) y en qué periodos hay
# competencia.

grid <- expand_grid(Cod_partida = cod_comp, Pais = paises_analisis, per = factor(ids_periodos, levels = ids_periodos)) |>
  left_join(miembros |> mutate(en_lista = TRUE) |> select(Pais, per, Cod_partida, en_lista),
            by = c("Pais", "per", "Cod_partida")) |>
  mutate(en_lista = replace_na(en_lista, FALSE))

patron_pais <- grid |>
  group_by(Cod_partida, Pais) |>
  summarise(patron = paste0(if_else(en_lista, "●", "○"), collapse = ""), .groups = "drop") |>
  pivot_wider(names_from = Pais, values_from = patron, names_prefix = "lista_")

patron_comp <- grid |>
  group_by(Cod_partida, per) |>
  summarise(comp = sum(en_lista) >= 2, .groups = "drop") |>
  group_by(Cod_partida) |>
  summarise(
    comp_patron = paste0(if_else(comp, "●", "○"), collapse = ""),
    n_comp      = sum(comp),
    comp_24     = comp[per == "p24"],
    comp_25     = comp[per == "p25"],
    comp_26     = comp[per == "p26"],
    .groups = "drop"
  ) |>
  mutate(cambio = case_when(
    n_comp == 3                              ~ "En competencia en los 3",
    comp_24 & comp_25 & !comp_26             ~ "Sale en 2026",
    comp_24 & !comp_25 & !comp_26            ~ "Solo 2024",
    comp_24 & !comp_25 & comp_26             ~ "Sale en 2025, vuelve en 2026",
    !comp_24 & comp_25 & comp_26             ~ "Entra en 2025",
    !comp_24 & comp_25 & !comp_26            ~ "Solo 2025",
    !comp_24 & !comp_25 & comp_26            ~ "Solo 2026",
    .default                                 = "Mixto"
  ))

val_2025 <- datos |>
  filter(year(fecha) == 2025, Cod_partida %in% cod_comp) |>
  group_by(Pais, Cod_partida) |>
  summarise(Val = sum(Val_mes, na.rm = TRUE) / 1e9, .groups = "drop") |>
  pivot_wider(names_from = Pais, values_from = Val, names_prefix = "val25_")

tabla_comp <- tibble(Cod_partida = cod_comp) |>
  left_join(desc_partida, by = "Cod_partida") |>
  hs_etiquetas_partida(estricto = FALSE) |>
  left_join(patron_pais, by = "Cod_partida") |>
  left_join(patron_comp, by = "Cod_partida") |>
  left_join(val_2025, by = "Cod_partida") |>
  mutate(Nombre = coalesce(Part_tabla, str_trunc(Desc_api_partida, 45))) |>
  arrange(Capítulo, desc(n_comp), Cod_partida)

sin_nombre <- tabla_comp |> filter(is.na(Part_corto))
if (nrow(sin_nombre) > 0) {
  cat("\n⚠ Partidas SIN nombre_corto (en la tabla aparece la descripción del API):\n")
  cat(paste0(sin_nombre$Cod_partida, " — ", sin_nombre$Desc_api_partida), sep = "\n")
}

cat("\n=== Partidas cuya situación de competencia NO es estable ===\n")
cat("(patrón: 2024 · 2025 · ", etiqueta_ytd, ")\n", sep = "")
tabla_comp |>
  filter(cambio != "En competencia en los 3") |>
  transmute(Capítulo, Cod_partida, Nombre, comp_patron, cambio,
            México = lista_México, Vietnam = lista_Vietnam, Taiwán = lista_Taiwán) |>
  print(n = Inf)

cat("\n=== Partidas en competencia en los 3 periodos: ",
    sum(tabla_comp$cambio == "En competencia en los 3"), " de ", nrow(tabla_comp), " ===\n", sep = "")

# Partidas que entran o salen de la lista de cada país entre periodos
cat("\n=== Partidas que NO están en las 3 listas de su país (por país) ===\n")
miembros |>
  group_by(Pais, Cod_partida) |>
  summarise(n_listas = n(), patron = paste0(if_else(ids_periodos %in% as.character(per), "●", "○"), collapse = ""),
            .groups = "drop") |>
  filter(n_listas < length(ids_periodos)) |>
  left_join(desc_partida, by = "Cod_partida") |>
  hs_etiquetas_partida(estricto = FALSE) |>
  transmute(Pais, Capítulo, Cod_partida, Nombre = coalesce(Part_corto, str_trunc(Desc_api_partida, 40)), patron) |>
  arrange(Pais, Capítulo, Cod_partida) |>
  print(n = Inf)

#  Sección 5. Tabla flextable (revisión)                                    ####

tabla_flex <- tabla_comp |>
  transmute(
    Capítulo = paste0(Capítulo, " – ", Cap_corto),
    Partida  = Cod_partida,
    Nombre,
    v_mx = val25_México, v_vn = val25_Vietnam, v_tw = val25_Taiwán,
    l_mx = lista_México, l_vn = lista_Vietnam, l_tw = lista_Taiwán,
    comp_patron, cambio
  ) |>
  flextable() |>
  set_header_labels(
    v_mx = "México", v_vn = "Vietnam", v_tw = "Taiwán",
    l_mx = "México", l_vn = "Vietnam", l_tw = "Taiwán",
    comp_patron = "Competencia", cambio = "Situación"
  ) |>
  add_header_row(
    values = c("", "Valor 2025 (miles de millones USD)", "En la lista del país", "Periodos", ""),
    colwidths = c(3, 3, 3, 1, 1)
  ) |>
  colformat_double(j = c("v_mx", "v_vn", "v_tw"), digits = 2, na_str = "—") |>
  add_header_lines("Partidas (HS4) en que México compite con Vietnam y/o Taiwán según el periodo de identificación") |>
  add_footer_lines(paste0(
    "Puntos en orden: 2024 · 2025 · ", etiqueta_ytd,
    ". ● = presente; ○ = ausente. Top ", TOP_N,
    " por valor por país, depurado de capítulos sin interés para NS. ",
    "Elaboración propia con base en U.S. Census Bureau, International Trade API.")) |>
  theme_booktabs() |>
  autofit()

tabla_flex

#  Sección 6. Guardado                                                      ####
# · RDS/top_partidas_competidores_periodos.rds : lista con datos y parámetros.
# · Tablas/top_partidas_competidores_periodos.rds : flextable (ancho natural).
# · Tablas/top_partidas_competidores_periodos.docx: copia para revisión (hoja horizontal).

dir.create(here("Tablas"), showWarnings = FALSE)

tryCatch({
  saveRDS(list(
    tabla          = tabla_comp,
    listas         = miembros,
    periodos       = periodos,
    top_n          = TOP_N,
    excluidos      = capitulos_excluir,
    ultimo_mes     = fecha_max,
    fecha_creación = Sys.time()
  ), here("RDS", "top_partidas_competidores_periodos.rds"))
  message("✔  RDS/top_partidas_competidores_periodos.rds guardado (", nrow(tabla_comp), " partidas).")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

tryCatch({
  saveRDS(tabla_flex, here("Tablas", "top_partidas_competidores_periodos.rds"))
  message("✔  Tablas/top_partidas_competidores_periodos.rds guardado.")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

tryCatch({
  tabla_docx <- tabla_flex |>
    flextable::fontsize(size = 9, part = "all") |>
    flextable::autofit() |>
    flextable::fit_to_width(max_width = 9, unit = "in")
  
  flextable::save_as_docx(
    tabla_docx,
    path = here("Tablas", "top_partidas_competidores_periodos.docx"),
    pr_section = officer::prop_section(
      page_size    = officer::page_size(orient = "landscape", width = 8.5, height = 11),
      page_margins = officer::page_mar(left = 0.75, right = 0.75, top = 0.75, bottom = 0.75)
    )
  )
  message("✔  Tablas/top_partidas_competidores_periodos.docx guardado.")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

cat("\nListo.\n")
