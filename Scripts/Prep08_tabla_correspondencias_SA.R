# Prep08_tabla_correspondencias_SA.R   ####
# Tabla de correspondencias entre nombres cortos y nomenclatura oficial del SA
# (Anexo 7.3 del Capítulo 2).
#
# Contenido de la tabla (una sola tabla jerárquica):
#   - TODAS las Secciones (I-XXI) y TODOS los Capítulos del SA (sin 98 ni 99,
#     que son provisiones de EUA y no forman parte del SA).
#   - Solo las Partidas que el Capítulo 2 identifica de manera individual, es
#     decir, las de las tablas por capítulo (84, 85, 87, 90) y los paneles del
#     Anexo 7.1: todas las de TCAC_y_shares_84858790.rds salvo "Resto".
#   - Cada Partida cuelga de su Capítulo, y cada Capítulo de su Sección.
#   - En las filas de Sección, el nombre ultracorto de los gráficos
#     (nombre_grafico) va entre paréntesis junto al nombre corto.
#
# Cuando C3 defina sus partidas (y posibles subpartidas), basta con ampliar
# `partidas_c2` (sección 1) y volver a correr el script.
#
# Entradas: RDS/hs_dictionary.rds       (build_hs_dictionary.R)
#           RDS/TCAC_y_shares_84858790.rds (Prep02)
# Salidas:  RDS/tabla_correspondencias_sa_datos.rds  (data frame que alimenta la tabla)
#           Tablas/tabla_correspondencias_sa.rds     (flextable; la carga el qmd)
#           Tablas/tabla_correspondencias_sa.docx    (copia para revisión)
#
# Correr después de Prep02 y de build_hs_dictionary.R, en una sesión limpia.

pacman::p_load(tidyverse, here, flextable)

source(here("Scripts", "funciones.R"))
set_flextable_defaults(fonts_ignore = TRUE)

# Sección 1. Partidas identificadas individualmente en C2                    ####

dic <- hs_cargar()

partidas_c2 <- readRDS(here("RDS", "TCAC_y_shares_84858790.rds")) |>
  filter(Cod_partida != "Resto") |>
  mutate(codigo = sprintf("%04d", as.integer(Cod_partida))) |>
  distinct(codigo) |>
  pull(codigo)

message("Partidas identificadas individualmente en C2: ", length(partidas_c2))

# Sección 2. Armado de la tabla jerárquica                                   ####

secciones <- dic |> filter(nivel == "Sección")
niveles_seccion <- secciones$codigo          # I ... XXI, en orden

capitulos <- dic |>
  filter(nivel == "Capítulo", !codigo %in% c("98", "99"))

partidas <- dic |>
  filter(nivel == "Partida", codigo %in% partidas_c2)

# Validaciones
sin_dic <- setdiff(partidas_c2, partidas$codigo)
sin_corto <- partidas |> filter(is.na(coalesce(nombre_tabla, nombre_corto)))
cap_huerfanos <- setdiff(partidas$codigo_padre, capitulos$codigo)

stopifnot(
  "Hay partidas de C2 que no están en hs_dictionary.rds" = length(sin_dic) == 0,
  "Hay partidas de C2 sin nombre_corto/nombre_tabla en hs_nombres_cortos.csv" =
    nrow(sin_corto) == 0,
  "Hay partidas cuyo Capítulo no está en la tabla" = length(cap_huerfanos) == 0,
  "Deben ser 21 Secciones" = nrow(secciones) == 21,
  "Los Capítulos deben tener Sección" = !anyNA(capitulos$codigo_padre)
)

# Sección del Capítulo de cada Partida
seccion_de_cap <- capitulos |> select(cap = codigo, seccion = codigo_padre)

filas_seccion <- secciones |>
  transmute(
    nivel,
    seccion    = codigo,
    cap        = "00",
    codigo_ord = codigo,
    Código     = codigo,
    Nombre     = if_else(
      !is.na(nombre_grafico) & nombre_grafico != coalesce(nombre_tabla, nombre_corto),
      paste0(coalesce(nombre_tabla, nombre_corto), " (", nombre_grafico, ")"),
      coalesce(nombre_tabla, nombre_corto)
    ),
    Oficial    = nombre_oficial
  )

filas_capitulo <- capitulos |>
  transmute(
    nivel,
    seccion    = codigo_padre,
    cap        = codigo,
    codigo_ord = codigo,
    Código     = paste("Cap.", codigo),
    Nombre     = coalesce(nombre_tabla, nombre_corto),
    Oficial    = nombre_oficial
  )

filas_partida <- partidas |>
  left_join(seccion_de_cap, by = c("codigo_padre" = "cap")) |>
  transmute(
    nivel,
    seccion    = seccion,
    cap        = codigo_padre,
    codigo_ord = codigo,
    Código     = codigo,
    Nombre     = coalesce(nombre_tabla, nombre_corto),
    Oficial    = nombre_oficial
  )

tabla_datos <- bind_rows(filas_seccion, filas_capitulo, filas_partida) |>
  mutate(
    seccion   = factor(seccion, levels = niveles_seccion),
    nivel_ord = match(nivel, c("Sección", "Capítulo", "Partida"))
  ) |>
  arrange(seccion, cap, nivel_ord, codigo_ord) |>
  select(nivel, seccion, cap, Código, Nombre, Oficial)

# Verificación: 21 Secciones + capítulos del SA + partidas de C2
stopifnot(
  "Número de filas inesperado" =
    nrow(tabla_datos) == nrow(secciones) + nrow(capitulos) + nrow(partidas)
)

cat("\n=== tabla de correspondencias ===\n")
count(tabla_datos, nivel) |> print()

# Sección 3. flextable                                                       ####
# flextable (no gt) porque el documento final es Word; ver nota en
# prep-tablas-cap de C2. Ancho útil de reference-doc.docx: 6 pulgadas.

i_seccion <- which(tabla_datos$nivel == "Sección")
i_capitulo <- which(tabla_datos$nivel == "Capítulo")
i_partida  <- which(tabla_datos$nivel == "Partida")

ft <- tabla_datos |>
  select(Código, Nombre, Oficial) |>
  flextable() |>
  set_header_labels(
    Código  = "Código",
    Nombre  = "Nombre corto",
    Oficial = "Nombre oficial (SA 2022)"
  ) |>
  fontsize(size = 8, part = "all") |>
  bold(part = "header") |>
  bg(i = i_seccion, bg = "#e3e6e9") |>
  bold(i = i_seccion) |>
  padding(i = i_capitulo, j = 1, padding.left = 10) |>
  padding(i = i_partida,  j = 1, padding.left = 20) |>
  padding(padding.top = 1, padding.bottom = 1, part = "body") |>
  flextable::align(j = 1, align = "left", part = "all") |>
  theme_booktabs() |>
  set_table_properties(layout = "fixed") |>
  width(j = 1, width = 0.8, unit = "in") |>
  width(j = 2, width = 1.7, unit = "in") |>
  width(j = 3, width = 3.5, unit = "in") |>
  add_footer_lines(paste(
    "Elaboración propia con base en la Organización Mundial de Aduanas (Secciones, SA 2022)",
    "y NALADISA 2022 (Capítulos y Partidas). Se incluyen todas las Secciones y Capítulos del SA",
    "y solo las Partidas que se identifican individualmente en este capítulo.",
    "Entre paréntesis, junto al nombre corto de cada Sección, el nombre ultracorto usado en las figuras."
  )) |>
  fontsize(size = 8, part = "footer")

# Sección 4. Guardado                                                        ####

dir.create(here("Tablas"), showWarnings = FALSE)

tryCatch({
  saveRDS(tabla_datos, here("RDS", "tabla_correspondencias_sa_datos.rds"))
  saveRDS(ft, here("Tablas", "tabla_correspondencias_sa.rds"))
  message("✔  tabla_correspondencias_sa_datos.rds y Tablas/tabla_correspondencias_sa.rds guardados (",
          nrow(tabla_datos), " filas).")
}, error = function(e) message("✘  Falló el guardado RDS: ", conditionMessage(e)))

tryCatch({
  flextable::save_as_docx(ft, path = here("Tablas", "tabla_correspondencias_sa.docx"))
  message("✔  Tablas/tabla_correspondencias_sa.docx guardado.")
}, error = function(e) message("✘  Falló el guardado .docx: ", conditionMessage(e)))
