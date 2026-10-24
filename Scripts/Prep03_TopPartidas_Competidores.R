# Prep03_TopPartidas_Competidores.R   ####
# Identificación de las Partidas (HS4) más importantes para México, Vietnam
# y Taiwán en sus exportaciones a EUA, y de las Partidas en que México
# compite con uno o ambos de los otros dos países.
# Fuente: imp_competidores_hs4.rds (Query02 — US Census Bureau,
#         todos los capítulos, 2010 – último mes disponible)
#
# Método (revisado 22-oct-2026; coherente con Prep02):
# a. Para cada país y cada periodo (ANIOS_TOP completos + enero–último mes
#    del año en curso), Top TOP_N Partidas por valor entre TODAS las
#    partidas del país; luego se descartan los capítulos sin interés para
#    nearshoring (commodities, alimentos, combustibles, muebles, joyería,
#    textiles/calzado, cuero, juguetes, vidrio, partidas especiales de EUA).
# b. "En competencia" en un periodo = la partida aparece en la lista
#    depurada de México y de al menos uno de los otros dos países EN ESE
#    MISMO periodo. Las partidas en que solo compiten Vietnam y Taiwán
#    (sin México) no interesan y se descartan.
# c. Se conserva toda partida en competencia en al menos un periodo
#    (unión de periodos). Las diferencias entre periodos son de borde
#    (partidas marginales), de modo que no se descarta ninguna.
#
# Se eliminó el ranking por crecimiento (2018 vs. 2025) y la suma 2024+2025:
# el primero nunca aportó partidas y la segunda ataba el criterio a años fijos.
# El script anterior se conserva en _backup_2026-10-19/Scripts/ si existe.

pacman::p_load(tidyverse, here, scales, flextable)
source(here("Scripts", "funciones.R"))   # hs_etiquetas_partida() — nombres del SA desde RDS/hs_dictionary.rds

set_flextable_defaults(fonts_ignore = TRUE)

# Parámetros   ####

ANIOS_TOP <- 2024:2025     # años completos que definen listas (más el ytd del año en curso)
TOP_N     <- 50            # tamaño de la lista por país ANTES de depurar
ANIO_VALOR <- max(ANIOS_TOP)   # año completo cuyo valor se muestra en la tabla

meses_es <- c("ene", "feb", "mar", "abr", "may", "jun",
              "jul", "ago", "sep", "oct", "nov", "dic")

# Sección 1. Carga de datos   ####

paises_análisis <- c("México", "Vietnam", "Taiwán")

imp_competidores_hs4 <- readRDS(here("RDS", "imp_competidores_hs4.rds")) |>
  filter(Pais %in% paises_análisis)

fecha_max    <- max(imp_competidores_hs4$fecha)
mes_corte    <- month(fecha_max)
anio_act     <- year(fecha_max)
etiqueta_ytd <- paste0("ene–", meses_es[mes_corte], " ", anio_act)
etiqueta_valor <- paste0("ene–", meses_es[mes_corte], " ", ANIO_VALOR)   # mismo acumulado, año de comparación

stopifnot("El año en curso ya está en ANIOS_TOP; ajustar parámetros" = !anio_act %in% ANIOS_TOP)

cat("Último mes disponible:", format(fecha_max), "| periodo parcial:", etiqueta_ytd, "\n")

# Periodos que definen las listas: un elemento por año completo + el ytd
periodos <- c(
  map(ANIOS_TOP, \(a) list(etiqueta = as.character(a), anio = a, mes_hasta = 12L)) |>
    set_names(paste0("p", ANIOS_TOP)),
  list(ytd = list(etiqueta = etiqueta_ytd, anio = anio_act, mes_hasta = mes_corte))
)
ids_periodos <- names(periodos)

# Descripción más reciente disponible por país + partida
desc_partida_pais <- imp_competidores_hs4 |>
  filter(!is.na(Desc_api_partida)) |>
  group_by(Pais, Cod_partida) |>
  slice_max(fecha, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(Pais, Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

# Sección 2. Categorías excluidas (commodities / sin interés para NS)   ####
# Aplicadas de forma uniforme a los tres países para mantener comparabilidad.
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
  72,           # Hierro y acero: montos insignificantes (7210)
  98, 99        # Provisiones especiales de clasificación de EUA
)

# Sección 3. Lista depurada de cada país en cada periodo   ####

lista_pais_periodo <- function(pais_sel, id) {
  per <- periodos[[id]]
  imp_competidores_hs4 |>
    filter(Pais == pais_sel, year(fecha) == per$anio, month(fecha) <= per$mes_hasta) |>
    group_by(Cod_partida) |>
    summarise(Capítulo = first(Capítulo), Val = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    arrange(desc(Val)) |>
    slice_head(n = TOP_N) |>
    filter(!Capítulo %in% capitulos_excluir) |>
    transmute(Pais = pais_sel, per = id, Cod_partida, Val)
}

miembros <- expand_grid(pais_sel = paises_análisis, id = ids_periodos) |>
  pmap_dfr(lista_pais_periodo) |>
  mutate(per = factor(per, levels = ids_periodos))

cat("\n=== Partidas en la lista depurada de cada país, por periodo ===\n")
miembros |>
  count(Pais, per) |>
  pivot_wider(names_from = per, values_from = n) |>
  rename_with(~ map_chr(.x, \(i) periodos[[i]]$etiqueta), all_of(ids_periodos)) |>
  print()

# Sección 4. Partidas en competencia (México + 1 o más países, mismo periodo)   ####

competencia <- miembros |>
  group_by(per, Cod_partida) |>
  summarise(n_paises = n_distinct(Pais), con_mex = any(Pais == "México"), .groups = "drop") |>
  filter(n_paises >= 2, con_mex)

cat("\n=== Partidas en competencia (México + 1 o más países) por periodo ===\n")
competencia |>
  group_by(per) |>
  summarise(`2+ países` = n(), `3 países` = sum(n_paises == 3), .groups = "drop") |>
  mutate(periodo = map_chr(as.character(per), \(i) periodos[[i]]$etiqueta), .before = 1) |>
  select(-per) |>
  print()

cod_comp <- sort(unique(competencia$Cod_partida))
n_periodos_comp <- competencia |> count(Cod_partida, name = "n_periodos_comp")

cat("\nPartidas en competencia en al menos un periodo:", length(cod_comp), "\n")
cat("Distribución por número de periodos en competencia (de ", length(ids_periodos), "):\n", sep = "")
n_periodos_comp |> count(n_periodos_comp) |> print()

# Sección 5. Listas finales por país (unión de periodos)   ####
# Una partida figura en la lista de un país si estuvo en su Top depurado en
# cualquier periodo. Val_anio = acumulado enero–último mes de ANIO_VALOR y
# Val_ytd = acumulado enero–último mes del año en curso: mismo corte de meses,
# por lo que son comparables. (Se muestran solo donde la partida figura en la
# lista del país en algún periodo; NA en otro caso.)
valor_anio <- imp_competidores_hs4 |>
  group_by(Pais, Cod_partida) |>
  summarise(
    Val_anio = sum(Val_mes[year(fecha) == ANIO_VALOR & month(fecha) <= mes_corte], na.rm = TRUE),
    Val_ytd  = sum(Val_mes[year(fecha) == anio_act & month(fecha) <= mes_corte], na.rm = TRUE),
    .groups = "drop"
  )

listas_finales <- miembros |>
  group_by(Pais, Cod_partida) |>
  summarise(n_listas = n(), periodos_en_lista = paste(per, collapse = ","), .groups = "drop") |>
  left_join(desc_partida_pais, by = c("Pais", "Cod_partida")) |>
  left_join(valor_anio, by = c("Pais", "Cod_partida"))

cat("\nPartidas en la lista final NS-relevante (unión de periodos), por país:\n")
listas_finales |> count(Pais) |> print()

# Sección 6. Tabla de competencia   ####

# Descripción canónica por partida (una sola etiqueta por fila): prioridad
# México > Taiwán > Vietnam, solo para elegir la fuente de la descripción.
desc_canonica <- listas_finales |>
  mutate(prioridad = case_when(Pais == "México" ~ 1, Pais == "Taiwán" ~ 2, .default = 3)) |>
  arrange(Cod_partida, prioridad) |>
  distinct(Cod_partida, .keep_all = TRUE) |>
  select(Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

tabla_valores_pais <- listas_finales |>
  select(Cod_partida, Pais, Val_anio) |>
  pivot_wider(names_from = Pais, values_from = Val_anio) |>
  left_join(
    listas_finales |>
      select(Cod_partida, Pais, Val_ytd) |>
      pivot_wider(names_from = Pais, values_from = Val_ytd, names_glue = "{Pais}_ytd"),
    by = "Cod_partida"
  )

cols_ytd <- paste0(paises_análisis, "_ytd")   # México_ytd, Vietnam_ytd, Taiwán_ytd

tabla_competencia <- desc_canonica |>
  left_join(tabla_valores_pais, by = "Cod_partida") |>
  left_join(n_periodos_comp, by = "Cod_partida") |>
  mutate(
    n_paises        = rowSums(!is.na(across(all_of(paises_análisis)))),
    n_periodos_comp = replace_na(n_periodos_comp, 0L)
  ) |>
  relocate(n_paises, n_periodos_comp, .after = Cod_partida) |>
  arrange(Capítulo, desc(n_periodos_comp), desc(n_paises), desc(México))

cat("\nPartidas en tabla_competencia (unión de las listas NS-relevantes):", nrow(tabla_competencia), "\n")

# Subconjunto de interés: partidas en competencia en al menos un periodo
tabla_overlap <- tabla_competencia |> filter(Cod_partida %in% cod_comp)

cat("\n=== Partidas en competencia (México + 1 o más países, al menos un periodo) ===\n")
tabla_overlap |>
  select(Capítulo, Cap_corto, Cod_partida, n_periodos_comp, n_paises, México, Vietnam, Taiwán) |>
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
  periodos_listas   = map_chr(periodos, "etiqueta"),
  top_n             = TOP_N,
  año_valor         = ANIO_VALOR,
  último_mes        = fecha_max,
  capítulos_excluidos  = capitulos_excluir,
  notas             = "Lista de cada país = Top TOP_N por valor (todos los capítulos) en cada periodo,
                        depurada de capitulos_excluidos. En competencia en un periodo = partida en la
                        lista de México y de 1+ de los otros países en ese mismo periodo. tabla_overlap / tabla_overlap_es:
                        partidas en competencia en al menos un periodo. Val_anio / columnas de país:
                        acumulado enero–último mes de año_valor, solo donde la partida figura en la lista del
                        país en algún periodo. Valores en dólares corrientes, sin dividir. La conversión
                        a miles de millones y el formato final se hacen en la Sección 9."
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
    across(all_of(c(paises_análisis, cols_ytd)), ~ .x / 1e9),
    Capítulo_lbl = paste0(Capítulo, " - ", as.character(Cap_corto))
  ) |>
  arrange(Capítulo, desc(n_periodos_comp), desc(n_paises), desc(México)) |>
  select(
    Capítulo = Capítulo_lbl,
    Partida  = Cod_partida,
    Descripción = Nombre_tabla_partida,
    México, Vietnam, Taiwán,
    all_of(cols_ytd)
  )

tabla_flex_agrupada <- tabla_flex_datos |>
  as_grouped_data(groups = "Capítulo") |>
  identity()
# (as_grouped_data() deja NA en Capítulo para las filas de datos; un
# arrange() posterior por esa columna mandaría todos los encabezados de
# grupo al principio y las filas de datos al final sin intercalar.
# tabla_flex_datos ya viene ordenada por Capítulo desde antes de agrupar.)

# Filas de encabezado de capítulo (Capítulo no-NA, Partida NA): se marcan en negrita.
filas_grupo    <- which(!is.na(tabla_flex_agrupada$Capítulo) & is.na(tabla_flex_agrupada$Partida))

tabla_partidas_competencia <- tabla_flex_agrupada |>
  as_flextable(groups_to = "titles", hide_grouplabel = TRUE) |>
  set_header_labels(
    Partida      = "Partida",
    Descripción  = "Descripción",
    México       = "México",
    Vietnam      = "Vietnam",
    Taiwán       = "Taiwán",
    México_ytd   = "México",
    Vietnam_ytd  = "Vietnam",
    Taiwán_ytd   = "Taiwán"
  ) |>
  add_header_row(
    top       = TRUE,
    values    = c("", "", paste0("Miles de millones de USD (", etiqueta_valor, ")"),
                  paste0("Miles de millones de USD (", etiqueta_ytd, ")")),
    colwidths = c(1, 1, 3, 3)
  ) |>
  colformat_double(j = c(paises_análisis, cols_ytd), digits = 1, na_str = "—") |>
  bold(i = filas_grupo) |>
  bg(i = ~ !is.na(México),  j = "México",  bg = "#CDE4F7") |>
  bg(i = ~ !is.na(Vietnam), j = "Vietnam", bg = "#D6EFD6") |>
  bg(i = ~ !is.na(Taiwán),  j = "Taiwán",  bg = "#FBE0D0") |>
  bg(i = ~ !is.na(México_ytd),  j = "México_ytd",  bg = "#CDE4F7") |>
  bg(i = ~ !is.na(Vietnam_ytd), j = "Vietnam_ytd", bg = "#D6EFD6") |>
  bg(i = ~ !is.na(Taiwán_ytd),  j = "Taiwán_ytd",  bg = "#FBE0D0") |>
  flextable::align(j = c(paises_análisis, cols_ytd), align = "center", part = "all") |>
  flextable::align(i = 1, align = "center", part = "header") |>
  theme_booktabs() |>
  bold(part = "header") |>
  autofit() |>
  fit_to_width(max_width = 6, unit = "in") |>
  add_footer_lines(paste0(
    "Elaboración propia con base en U.S. Census Bureau, API de Comercio Internacional. ",
    "Partidas (HS4) entre las 50 más importantes por valor de cada país en ",
    paste(map_chr(periodos, "etiqueta"), collapse = ", "),
    ", depuradas de categorías sin interés para nearshoring, presentes simultáneamente ",
    "en México y en al menos uno de los otros dos países en al menos uno de esos periodos. ",
    "El sombreado indica que la partida figura en la lista del país en algún periodo. ",
    "Los valores corresponden a los mismos meses (", etiqueta_valor, " y ", etiqueta_ytd, "). ",
    "Encabezados de capítulo en negrita."
  )) |>
  fontsize(size = 8, part = "footer")

tabla_partidas_competencia

cat("\n✔  Tabla flextable 'tabla_partidas_competencia' construida (", nrow(tabla_overlap_es),
    " partidas, agrupadas por capítulo).\n", sep = "")

tryCatch({
  saveRDS(tabla_partidas_competencia, here("RDS", "tabla_partidas_competencia.rds"))
  message("Guardado: tabla_partidas_competencia.rds")
}, error = function(e) message("ERROR guardando tabla_partidas_competencia.rds: ", conditionMessage(e)))

# Copia para revisión en Word (hoja horizontal). Tablas/ es la contraparte de Plots/.
dir.create(here("Tablas"), showWarnings = FALSE)

tryCatch({
  tabla_docx <- tabla_partidas_competencia |>
    flextable::fontsize(size = 9, part = "all") |>
    flextable::autofit() |>
    flextable::fit_to_width(max_width = 9, unit = "in")

  flextable::save_as_docx(
    tabla_docx,
    path = here("Tablas", "tabla_partidas_competencia.docx"),
    pr_section = officer::prop_section(
      page_size    = officer::page_size(orient = "landscape", width = 8.5, height = 11),
      page_margins = officer::page_mar(left = 0.75, right = 0.75, top = 0.75, bottom = 0.75)
    )
  )
  message("✔  Tablas/tabla_partidas_competencia.docx guardado.")
}, error = function(e) message("✗  ERROR guardando el .docx: ", conditionMessage(e)))
