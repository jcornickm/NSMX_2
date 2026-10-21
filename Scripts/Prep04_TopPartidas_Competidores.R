# Prep04_TopPartidas_Competidores.R   ####
# Identificación de las Partidas (HS4) más importantes para México, Vietnam
# y Taiwán en sus exportaciones a EUA, y de las Partidas en que México
# compite con uno o ambos de los otros dos países.
# Fuente: imp_competidores_hs4.rds (Query02 — US Census Bureau,
#         todos los capítulos, 2010 – jul. 2026)
#
# Método (igual al usado para México en Prep03, aplicado ahora a los tres
# países):
# a. Top 50 Partidas por valor — suma 2024 + 2025 — depurado de categorías
#    sin interés para nearshoring (commodities, alimentos, combustibles,
#    muebles, joyería, textiles/calzado, cuero, juguetes, vidrio, partidas
#    especiales de EUA). En caso de duda, la partida se deja dentro.
# b. Top 50 Partidas por crecimiento — año completo 2018 vs. 2025 — mismo
#    criterio de depuración. Se revisa si alguna partida de esta lista
#    alcanzó, para 2025, un volumen comparable al de la Partida #50 de la
#    lista (a) de ese mismo país; si no, se descarta (igual que para México
#    en Prep03, donde ninguna calificó).
# c. Unión de las listas finales (a) de los tres países → universo para
#    identificar partidas en que 2 o más países aparecen simultáneamente
#    ("partidas en competencia").

pacman::p_load(tidyverse, here, scales, flextable)
source(here("Scripts", "funciones.R"))   # hs_etiquetas_partida() — nombres del SA desde RDS/hs_dictionary.rds

set_flextable_defaults(fonts_ignore = TRUE)

# Sección 1. Carga de datos   ####

imp_competidores_hs4 <- readRDS(here("RDS", "imp_competidores_hs4.rds"))

paises_análisis <- c("México", "Vietnam", "Taiwán")

# Descripción más reciente disponible por país + partida
desc_partida_pais <- imp_competidores_hs4 |>
  filter(!is.na(Desc_api_partida)) |>
  group_by(Pais, Cod_partida) |>
  slice_max(fecha, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(Pais, Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

# Sección 2. Categorías excluidas (commodities / sin interés para NS)   ####
# Aplicadas de forma uniforme a los tres países para mantener comparabilidad.
# Incluye: alimentos/agro/animal (Secciones I–IV), minerales/combustibles
# (Sección V), plásticos/caucho y joyería/muebles (precedente de México en
# Prep03), partidas especiales de clasificación de EUA, y — por instrucción
# explícita para este ejercicio — textiles y calzado (Secciones XI y XII),
# cuero, juguetes y vidrio.

# Se excluye por NÚMERO de capítulo (no por nombre corto), así los nombres
# pueden editarse sin romper la depuración.
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

# Sección 3. Top 50 por valor (2024–2025), por país, depurado   ####

top_valor_pais <- function(pais_sel) {
  imp_competidores_hs4 |>
    filter(Pais == pais_sel, year(fecha) %in% c(2024, 2025)) |>
    group_by(Cod_partida) |>
    summarise(Val_2024_2025 = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    left_join(desc_partida_pais |> filter(Pais == pais_sel) |> select(-Pais),
              by = "Cod_partida") |>
    arrange(desc(Val_2024_2025)) |>
    slice_head(n = 50) |>
    mutate(ranking = row_number(), Pais = pais_sel) |>
    select(ranking, Pais, Capítulo, Cap_corto, Cod_partida, Desc_api_partida, Val_2024_2025)
}

top50_valor_todos <- map_dfr(paises_análisis, top_valor_pais)

top50_valor_dep <- top50_valor_todos |>
  filter(!Capítulo %in% capitulos_excluir) |>
  group_by(Pais) |>
  mutate(ranking = row_number()) |>
  ungroup()

cat("\n=== Top 50 por valor (2024–2025): retenidas vs. excluidas, por país ===\n")
top50_valor_todos |>
  mutate(excluida = Capítulo %in% capitulos_excluir) |>
  count(Pais, excluida) |>
  pivot_wider(names_from = excluida, values_from = n, names_prefix = "excluida_") |>
  print()

# Sección 4. Top 50 por crecimiento (2018 vs. 2025), por país, depurado   ####

crecimiento_pais <- function(pais_sel) {
  imp_competidores_hs4 |>
    filter(Pais == pais_sel, year(fecha) %in% c(2018, 2025)) |>
    mutate(año = year(fecha)) |>
    group_by(Cod_partida, año) |>
    summarise(Val_año = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    pivot_wider(names_from = año, values_from = Val_año, names_prefix = "val_") |>
    filter(!is.na(val_2018), !is.na(val_2025), val_2018 > 0) |>
    mutate(
      crecimiento_pct = (val_2025 / val_2018 - 1) * 100,
      tcac            = ((val_2025 / val_2018)^(1 / 7) - 1) * 100
    ) |>
    left_join(desc_partida_pais |> filter(Pais == pais_sel) |> select(-Pais), by = "Cod_partida") |>
    arrange(desc(crecimiento_pct)) |>
    slice_head(n = 50) |>
    mutate(ranking = row_number(), Pais = pais_sel) |>
    select(ranking, Pais, Capítulo, Cap_corto, Cod_partida, Desc_api_partida,
           val_2018, val_2025, crecimiento_pct, tcac)
}

top50_crecimiento_todos <- map_dfr(paises_análisis, crecimiento_pais)

top50_crecimiento_dep <- top50_crecimiento_todos |>
  filter(!Capítulo %in% capitulos_excluir) |>
  group_by(Pais) |>
  mutate(ranking = row_number()) |>
  ungroup()

# Umbral de volumen de referencia: valor mínimo (2024-2025) del Top 50 por
# valor depurado, por país — mismo criterio usado para México en Prep03.
umbral_valor <- top50_valor_dep |>
  group_by(Pais) |>
  summarise(umbral_val_24_25 = min(Val_2024_2025), .groups = "drop")

crecimiento_candidatos <- top50_crecimiento_dep |>
  left_join(umbral_valor, by = "Pais") |>
  anti_join(top50_valor_dep |> select(Pais, Cod_partida), by = c("Pais", "Cod_partida")) |>
  mutate(supera_umbral = val_2025 >= umbral_val_24_25)

cat("\n=== Partidas de alto crecimiento (2018→2025) que alcanzan el umbral de volumen ===\n")
n_supera <- sum(crecimiento_candidatos$supera_umbral)
if (n_supera == 0) {
  cat("(ninguna, en ninguno de los tres países — igual que para México en Prep03)\n")
} else {
  print(crecimiento_candidatos |> filter(supera_umbral))
}

# Sección 5. Listas finales NS-relevantes por país   ####
# = Top valor depurado + (crecimiento depurado que supera el umbral, si lo hay)

listas_finales <- bind_rows(
  top50_valor_dep |> select(Pais, Capítulo, Cap_corto, Cod_partida, Desc_api_partida, Val_2024_2025),
  crecimiento_candidatos |> filter(supera_umbral) |>
    select(Pais, Capítulo, Cap_corto, Cod_partida, Desc_api_partida, Val_2024_2025 = val_2025)
) |>
  distinct(Pais, Cod_partida, .keep_all = TRUE)

cat("\nPartidas en la lista final NS-relevante, por país:\n")
listas_finales |> count(Pais) |> print()

# Sección 6. Tabla de competencia — unión de las listas finales   ####

# Descripción canónica por partida (una sola etiqueta por fila): prioridad
# México > Taiwán > Vietnam, solo para elegir la fuente de la descripción.
desc_canonica <- listas_finales |>
  mutate(prioridad = case_when(Pais == "México" ~ 1, Pais == "Taiwán" ~ 2, TRUE ~ 3)) |>
  arrange(Cod_partida, prioridad) |>
  distinct(Cod_partida, .keep_all = TRUE) |>
  select(Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

tabla_valores_pais <- listas_finales |>
  select(Cod_partida, Pais, Val_2024_2025) |>
  pivot_wider(names_from = Pais, values_from = Val_2024_2025)

tabla_competencia <- desc_canonica |>
  left_join(tabla_valores_pais, by = "Cod_partida") |>
  mutate(n_paises = rowSums(!is.na(across(all_of(paises_análisis))))) |>
  relocate(n_paises, .after = Cod_partida) |>
  arrange(Capítulo, desc(n_paises), desc(México))

cat("\nPartidas en tabla_competencia (unión de las 3 listas NS-relevantes):", nrow(tabla_competencia), "\n")
cat("Distribución por número de países en que aparece la partida:\n")
tabla_competencia |> count(n_paises) |> print()

# Subconjunto de interés: partidas en que participan 2 o más países —
# estas son las partidas "en competencia".
tabla_overlap <- tabla_competencia |> filter(n_paises >= 2)

cat("\n=== Partidas en competencia (2+ países) ===\n")
tabla_overlap |>
  select(Capítulo, Cap_corto, Cod_partida, n_paises, México, Vietnam, Taiwán) |>
  print(n = nrow(tabla_overlap))

# Sección 7. Traducción al español   ####
# Nombres cortos de partida: del diccionario del SA (RDS/hs_dictionary.rds;
# se editan en Excel/hs_nombres_cortos.csv). Se detiene si falta alguno.

tabla_overlap_es <- tabla_overlap |>
  hs_etiquetas_partida() |>
  rename(Nombre_corto_partida = Part_corto,
         Nombre_tabla_partida = Part_tabla)

# Sección 8. Guardado de los datos de la tabla (antes de dar formato)   ####
# Se guardan en dólares corrientes (sin dividir ni redondear) para no atar
# el .rds a una unidad de presentación específica.

meta_query12 <- list(
  fuente            = "US Census Bureau — International Trade API (vía Query02)",
  países            = "México, Vietnam, Taiwán",
  período_valor     = "Suma de valor mensual 2024–2025",
  período_crec      = "Comparación años completos 2018 vs. 2025",
  umbral_volumen    = "Valor mínimo del Top-50-por-valor depurado de cada país (criterio igual al de México en Prep03)",
  capítulos_excluidos  = capitulos_excluir,
  notas             = "tabla_competencia: unión de las listas finales NS-relevantes de los 3 países
                        (todas las partidas, independientemente de cuántos países la comparten).
                        tabla_overlap / tabla_overlap_es: subconjunto con n_paises >= 2 — partidas
                        en que al menos dos de los tres países aparecen simultáneamente entre sus
                        propias partidas NS-relevantes ('partidas en competencia').
                        Valores en dólares corrientes, sin dividir. La conversión a miles de millones
                        y el formato final se hacen en el bloque de la tabla flextable (Sección 9)."
)

tryCatch({
  saveRDS(listas_finales,      here("RDS", "listas_finales_NS_mex_vnm_twn.rds"))
  saveRDS(tabla_competencia,   here("RDS", "tabla_competencia_mex_vnm_twn.rds"))
  saveRDS(tabla_overlap_es,    here("RDS", "tabla_overlap_mex_vnm_twn.rds"))
  saveRDS(meta_query12,        here("RDS", "meta_query12.rds"))
  message("✔  RDS guardados: listas_finales_NS_mex_vnm_twn.rds, tabla_competencia_mex_vnm_twn.rds, ",
          "tabla_overlap_mex_vnm_twn.rds, meta_query12.rds")
}, error = function(e) message("✗  ERROR guardando RDS: ", conditionMessage(e)))

# Sección 9. Tabla flextable — Partidas en que México compite con Vietnam y/o Taiwán   ####
# Montos en miles de millones de USD (se suprimen 9 ceros): 1 USD = 1e-9 "miles de millones".
# Estilo flextable consistente con el resto del documento (ver prep-tablas-cap en el .qmd):
# theme_booktabs() + autofit() + fit_to_width(), agrupado por Capítulo mediante as_grouped_data().

tabla_flex_datos <- tabla_overlap_es |>
  mutate(
    across(all_of(paises_análisis), ~ .x / 1e9),
    Capítulo_lbl = paste0(Capítulo, " - ", as.character(Cap_corto))
  ) |>
  arrange(Capítulo, desc(n_paises), desc(México)) |>
  select(
    Capítulo = Capítulo_lbl,
    Partida  = Cod_partida,
    Descripción = Nombre_tabla_partida,

    México, Vietnam, Taiwán
  )

tabla_flex_agrupada <- tabla_flex_datos |>
  as_grouped_data(groups = "Capítulo") |>
  identity()
# (as_grouped_data() deja NA en Capítulo para las filas de datos; un
# arrange() posterior por esa columna mandaría todos los encabezados de
# grupo al principio y las filas de datos al final sin intercalar -- el
# error visto en la tabla renderizada. tabla_flex_datos ya viene ordenada
# por Capítulo desde antes de agrupar, así que no hace falta reordenar.)

# Filas de encabezado de capítulo (Capítulo no-NA, Partida NA): se marcan en
# negrita. Las filas de partida individuales ya no llevan negrita -- el
# color de fondo por país basta para distinguirlas.
filas_grupo    <- which(!is.na(tabla_flex_agrupada$Capítulo) & is.na(tabla_flex_agrupada$Partida))

tabla_partidas_competencia <- tabla_flex_agrupada |>
  as_flextable(groups_to = "titles", hide_grouplabel = TRUE) |>
  set_header_labels(
    Partida      = "Partida",
    Descripción  = "Descripción",

    México       = "México",
    Vietnam      = "Vietnam",
    Taiwán       = "Taiwán"
  ) |>
  add_header_row(
    top       = TRUE,
    values    = c("", "", "Miles de millones de USD (2024–2025)"),
    colwidths = c(1, 1, 3)
  ) |>
  colformat_double(j = c("México", "Vietnam", "Taiwán"), digits = 1, na_str = "—") |>
  bold(i = filas_grupo) |>
  bg(i = ~ !is.na(México),  j = "México",  bg = "#CDE4F7") |>
  bg(i = ~ !is.na(Vietnam), j = "Vietnam", bg = "#D6EFD6") |>
  bg(i = ~ !is.na(Taiwán),  j = "Taiwán",  bg = "#FBE0D0") |>
  flextable::align(j = c("México", "Vietnam", "Taiwán"), align = "center", part = "all") |>
  flextable::align(i = 1, align = "center", part = "header") |>
  theme_booktabs() |>
  bold(part = "header") |>
  autofit() |>
  fit_to_width(max_width = 6, unit = "in") |>
  add_footer_lines(paste(
    "Elaboración propia con base en U.S. Census Bureau, API de Comercio Internacional.",
    "Partidas (HS4) entre las 50 más importantes por valor (2024\u20132025), depuradas de",
    "categorías sin interés para nearshoring, presentes simultáneamente en al menos dos",
    "de los tres países. Encabezados de capítulo en negrita."
  )) |>
  fontsize(size = 8, part = "footer")

tabla_partidas_competencia

cat("\n✔  Tabla flextable 'tabla_partidas_competencia' construida (", nrow(tabla_overlap_es),
    " partidas, agrupadas por capítulo).\n", sep = "")
cat("    Este bloque (Sección 9) está listo para copiarse al .qmd (p. ej. junto al bloque\n",
    "    'prep-tablas-cap') una vez validado.\n", sep = "")

tryCatch({
  saveRDS(tabla_partidas_competencia, here("RDS", "tabla_partidas_competencia.rds"))
  message("Guardado: tabla_partidas_competencia.rds")
}, error = function(e) message("ERROR guardando tabla_partidas_competencia.rds: ", conditionMessage(e)))
