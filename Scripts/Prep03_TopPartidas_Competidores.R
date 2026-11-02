# Prep03_TopPartidas_Competidores.R   ####
# Partidas (HS4) relevantes para México en sus exportaciones a EUA, y valor que
# Vietnam y Taiwán exportan a EUA en esas mismas partidas.
# Fuente: imp_competidores_hs4.rds (Query02 — US Census Bureau,
#         todos los capítulos, 2010 – último mes disponible)
#
# Método (revisado 1-nov-2026): México es el ancla.
# a. Periodo único: enero de FECHA_INI hasta el último mes disponible.
# b. Se ordenan las partidas de México por valor acumulado en el periodo,
#    después de descartar los capítulos sin interés para nearshoring
#    (commodities, alimentos, combustibles, muebles, joyería, textiles/calzado,
#    cuero, juguetes, vidrio, partidas especiales de EUA).
# c. Se conservan las partidas, de mayor a menor, hasta cubrir UMBRAL_ACUM del
#    valor NS-relevante de México (se incluye la partida que cruza el umbral).
# d. Para esas partidas se registra el valor de Vietnam y Taiwán. No se
#    identifican partidas top de estos países: solo importan donde compiten
#    con México.
# e. Porcentajes: sobre el total de exportaciones del país a EUA (todos los
#    capítulos, mismo periodo). El % acumulado de Vietnam y Taiwán sigue el
#    orden de México (medida de cobertura, no un ranking propio).
#
# El script anterior (top 50 por país y periodo) está en git y en
# _backup_2026-10-19/Scripts/.

pacman::p_load(tidyverse, here, scales, flextable)
source(here("Scripts", "funciones.R"))   # hs_etiquetas_partida() — nombres del SA desde RDS/hs_dictionary.rds

set_flextable_defaults(fonts_ignore = TRUE)

# Parámetros   ####

FECHA_INI   <- as.Date("2025-01-01")   # inicio del periodo único
UMBRAL_ACUM <- 0.80                    # cobertura del valor NS-relevante de México
GUARDAR     <- TRUE                    # FALSE: solo construye e imprime la tabla, sin escribir RDS ni .docx

meses_es <- c("ene", "feb", "mar", "abr", "may", "jun",
              "jul", "ago", "sep", "oct", "nov", "dic")

# Sección 1. Carga de datos   ####

paises_análisis <- c("México", "Vietnam", "Taiwán")

fecha_max <- readRDS(here("RDS", "imp_competidores_hs4.rds")) |> pull(fecha) |> max()

etiqueta_periodo_tabla <- paste0(
  meses_es[month(FECHA_INI)], " ", year(FECHA_INI), "–",
  meses_es[month(fecha_max)], " ", year(fecha_max)
)

imp_periodo <- readRDS(here("RDS", "imp_competidores_hs4.rds")) |>
  filter(Pais %in% paises_análisis, fecha >= FECHA_INI, fecha <= fecha_max)

cat("Periodo:", etiqueta_periodo_tabla, "| meses por país:\n")
imp_periodo |> distinct(Pais, fecha) |> count(Pais) |> print()

# Sección 2. Categorías excluidas (commodities / sin interés para NS)   ####
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

# Sección 3. Valores por país y partida en el periodo   ####

total_pais <- imp_periodo |>
  group_by(Pais) |>
  summarise(Total = sum(Val_mes, na.rm = TRUE), .groups = "drop")

valor_pais_partida <- imp_periodo |>
  group_by(Pais, Cod_partida) |>
  summarise(Capítulo = first(Capítulo), Val = sum(Val_mes, na.rm = TRUE), .groups = "drop")

# Sección 4. Lista de México (ancla): NS-relevante hasta UMBRAL_ACUM   ####

mex_ns <- valor_pais_partida |>
  filter(Pais == "México", !Capítulo %in% capitulos_excluir) |>
  arrange(desc(Val)) |>
  mutate(cum_ns = cumsum(Val) / sum(Val))

lista_mex <- mex_ns |>
  # Incluye la partida que cruza el umbral
  filter(lag(cum_ns, default = 0) < UMBRAL_ACUM) |>
  pull(Cod_partida)

cat("\nValor NS-relevante de México:", round(sum(mex_ns$Val) / 1e9, 1), "mil millones USD (",
    percent(sum(mex_ns$Val) / total_pais$Total[total_pais$Pais == "México"], accuracy = 0.1),
    "del total de México)\n")
cat("Partidas NS-relevantes de México:", nrow(mex_ns), "| en la lista (", percent(UMBRAL_ACUM), "):", length(lista_mex), "\n")

# Sección 5. Tabla de datos: México + Vietnam + Taiwán en esas partidas   ####

tabla_datos <- valor_pais_partida |>
  filter(Cod_partida %in% lista_mex) |>
  left_join(total_pais, by = "Pais") |>
  mutate(pct = 100 * Val / Total) |>
  select(Pais, Cod_partida, Val, pct) |>
  # Una fila por partida de México; NA donde Vietnam/Taiwán no exportan
  complete(Pais = paises_análisis, Cod_partida = lista_mex) |>
  mutate(Pais = factor(Pais, levels = paises_análisis))

orden_mex <- tabla_datos |>
  filter(Pais == "México") |>
  arrange(desc(Val)) |>
  pull(Cod_partida)

tabla_datos <- tabla_datos |>
  mutate(Cod_partida = factor(Cod_partida, levels = orden_mex)) |>
  arrange(Pais, Cod_partida) |>
  group_by(Pais) |>
  # Acumulado en el orden de México
  mutate(acum = cumsum(replace_na(pct, 0))) |>
  ungroup() |>
  mutate(Val = Val / 1e9) |>   # miles de millones de USD
  pivot_wider(names_from = Pais, values_from = c(Val, pct, acum),
              names_glue = "{Pais}_{.value}") |>
  mutate(Cod_partida = as.character(Cod_partida)) |>
  hs_etiquetas_partida() |>
  select(Partida = Cod_partida, Descripción = Part_tabla,
         ends_with("_Val"), ends_with("_pct"), ends_with("_acum")) |>
  # Orden de columnas: por país (valor, % del total, % acumulado)
  select(Partida, Descripción,
         all_of(as.vector(t(outer(paises_análisis, c("Val", "pct", "acum"), paste, sep = "_")))))

cat("\nCobertura de la lista (% del total de cada país):\n")
tabla_datos |>
  summarise(across(ends_with("_acum"), \(x) round(max(x), 1))) |>
  print()

# Sección 6. Tabla flextable   ####
# Montos en miles de millones de USD. Estilo: theme_booktabs() + autofit() + fit_to_width().

cols_val  <- paste0(paises_análisis, "_Val")
cols_pct  <- paste0(paises_análisis, "_pct")
cols_acum <- paste0(paises_análisis, "_acum")
colores_pais <- c(México = "#CDE4F7", Vietnam = "#D6EFD6", Taiwán = "#FBE0D0")

etiquetas_cols <- c(
  Partida = "Partida", Descripción = "Descripción",
  set_names(rep(c("USD mmd", "% total", "% acum."), 3),
            as.vector(t(outer(paises_análisis, c("Val", "pct", "acum"), paste, sep = "_"))))
)

tabla_partidas_competencia <- flextable(tabla_datos) |>
  set_header_labels(values = as.list(etiquetas_cols)) |>
  add_header_row(
    top       = TRUE,
    values    = c("", "", paises_análisis),
    colwidths = c(1, 1, 3, 3, 3)
  ) |>
  colformat_double(j = cols_val, digits = 2, na_str = "—") |>
  colformat_double(j = c(cols_pct, cols_acum), digits = 1, na_str = "—") |>
  flextable::align(j = c(cols_val, cols_pct, cols_acum), align = "right", part = "body") |>
  flextable::align(j = c(cols_val, cols_pct, cols_acum), align = "right", part = "header") |>
  flextable::align(i = 1, align = "center", part = "header") |>
  theme_booktabs() |>
  bold(part = "header") |>
  autofit() |>
  fit_to_width(max_width = 6, unit = "in")

for (p in paises_análisis) {
  tabla_partidas_competencia <- tabla_partidas_competencia |>
    bg(i = as.formula(paste0("~ !is.na(`", p, "_Val`)")),
       j = paste0(p, c("_Val", "_pct", "_acum")), bg = colores_pais[[p]])
}

tabla_partidas_competencia <- tabla_partidas_competencia |>
  add_footer_lines(paste0(
    "Elaboración propia con base en U.S. Census Bureau, API de Comercio Internacional. ",
    "Partidas (HS4) ordenadas por valor de exportaciones de México a EUA en ", etiqueta_periodo_tabla,
    ", sin capítulos de poco interés para nearshoring, hasta cubrir ", percent(UMBRAL_ACUM),
    " del valor restante. USD mmd = miles de millones de USD. ",
    "% total = participación en las exportaciones totales a EUA del país (todos los capítulos). ",
    "% acum. = suma de esa participación en el orden de México. ",
    "Vietnam y Taiwán: valor en las partidas de México; \"—\" = sin exportaciones."
  )) |>
  fontsize(size = 8, part = "footer")

tabla_partidas_competencia

cat("\n✔  Tabla flextable 'tabla_partidas_competencia' construida (", nrow(tabla_datos), " partidas).\n", sep = "")

# Sección 7. Guardado (solo con GUARDAR = TRUE)   ####
# Datos en miles de millones de USD (tabla_datos) y metadatos del método.

if (GUARDAR) {
  meta_query12 <- list(
    fuente             = "US Census Bureau — International Trade API (vía Query02)",
    países             = paises_análisis,
    periodo            = etiqueta_periodo_tabla,
    fecha_ini          = FECHA_INI,
    último_mes         = fecha_max,
    umbral_acum        = UMBRAL_ACUM,
    capítulos_excluidos = capitulos_excluir,
    notas              = "Ancla = México. Partidas NS-relevantes de México ordenadas por valor en el periodo,
                          hasta cubrir umbral_acum del valor NS-relevante. Vietnam y Taiwán: valor en esas
                          partidas. % total sobre exportaciones totales del país a EUA (todos los capítulos).
                          Valores en miles de millones de USD."
  )

  saveRDS(tabla_datos,                 here("RDS", "tabla_competencia_mex_vnm_twn.rds"))
  saveRDS(meta_query12,                here("RDS", "meta_query12.rds"))
  saveRDS(tabla_partidas_competencia,  here("RDS", "tabla_partidas_competencia.rds"))

  dir.create(here("Tablas"), showWarnings = FALSE)
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
  message("✔  Guardados: RDS (tabla_competencia_mex_vnm_twn, meta_query12, tabla_partidas_competencia) y Tablas/tabla_partidas_competencia.docx")
} else {
  message("GUARDAR = FALSE: no se escribió ningún archivo.")
}
