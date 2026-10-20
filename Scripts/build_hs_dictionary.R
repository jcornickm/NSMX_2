# build_hs_dictionary.R   ####
# Diccionario del Sistema Armonizado (SA/HS) — Secciones, Capítulos y Partidas
#
# Fuentes:
#   - Secciones (I–XXI): WCO Trade Tools, Sistema Armonizado 2022, español
#     (https://www.wcotradetools.org/es/harmonized-system/2022) — texto oficial
#     (traducción VUESA/COMALEP), transcrito manualmente.
#   - Capítulos y Partidas: Excel/naladisa_2022.xlsx (NALADISA 2022), que
#     reproduce la nomenclatura oficial del SA en español para Centroamérica.
#
# Alcance (versión 2):
#   - Secciones:  las 21, completas.
#   - Capítulos:  los 96 activos del SA (NALADISA) + 98 y 99 (provisiones
#                 especiales de EUA, texto manual: no están en el SA).
#   - Partidas:   TODAS las de NALADISA (nchar == 4), con nombre oficial.
#   - Subpartidas: no incluidas.
#   - Nombres cortos y de tabla: se leen de Excel/hs_nombres_cortos.csv
#     (editable a mano; es la ÚNICA fuente de nombres cortos). Columnas:
#     nivel, codigo, nombre_corto, nombre_tabla. Si nombre_tabla está vacío
#     se usa nombre_corto; así el editor puede pedir nombres largos solo
#     donde haga falta, editando el CSV y volviendo a correr este script.
#
# Estructura de salida (formato largo, una fila por código):
#   nivel          — "Sección", "Capítulo" o "Partida"
#   codigo         — "I".."XXI" (Sección); "01".."97" (Capítulo); "8401" etc. (Partida)
#   codigo_padre   — Sección a la que pertenece el Capítulo; Capítulo (2 dígitos)
#                    al que pertenece la Partida; NA para Secciones.
#   nombre_corto   — Etiqueta corta legible (con espacios) para gráficas y
#                    tablas; la misma en todo el proyecto. NA si aún no se define
#                    (el script lo reporta).
#   nombre_tabla   — Nombre para tablas; = nombre_corto si no se especifica otro.
#   fuente         — "WCO 2022" (Secciones), "NALADISA 2022" o "manual".
#   nombre_oficial — Texto oficial del SA en español, en "Sentence case"
#                    (primera letra en mayúscula, resto en minúsculas), tal
#                    como aparece en la fuente, sin abreviar.
#
# Salida: RDS/hs_dictionary.rds

pacman::p_load(tidyverse, readxl, here)

# Sección 1. Secciones del SA (texto oficial, WCO Trade Tools 2022)          ####

secciones_oficial <- tribble(
  ~Sección, ~cap_desde, ~cap_hasta, ~nombre_oficial_caps,
  "I",    1,  5,  "ANIMALES VIVOS Y PRODUCTOS DEL REINO ANIMAL",
  "II",   6,  14, "PRODUCTOS DEL REINO VEGETAL",
  "III",  15, 15, "GRASAS Y ACEITES, ANIMALES, VEGETALES O DE ORIGEN MICROBIANO, Y PRODUCTOS DE SU DESDOBLAMIENTO; GRASAS ALIMENTICIAS ELABORADAS; CERAS DE ORIGEN ANIMAL O VEGETAL",
  "IV",   16, 24, "PRODUCTOS DE LAS INDUSTRIAS ALIMENTARIAS; BEBIDAS, LÍQUIDOS ALCOHÓLICOS Y VINAGRE; TABACO Y SUCEDÁNEOS DEL TABACO ELABORADOS; PRODUCTOS, INCLUSO CON NICOTINA, DESTINADOS PARA LA INHALACIÓN SIN COMBUSTIÓN; OTROS PRODUCTOS QUE CONTENGAN NICOTINA DESTINADOS PARA LA ABSORCIÓN DE NICOTINA EN EL CUERPO HUMANO",
  "V",    25, 27, "PRODUCTOS MINERALES",
  "VI",   28, 38, "PRODUCTOS DE LAS INDUSTRIAS QUÍMICAS O DE LAS INDUSTRIAS CONEXAS",
  "VII",  39, 40, "PLÁSTICO Y SUS MANUFACTURAS; CAUCHO Y SUS MANUFACTURAS",
  "VIII", 41, 43, "PIELES, CUEROS, PELETERÍA Y MANUFACTURAS DE ESTAS MATERIAS; ARTÍCULOS DE TALABARTERÍA O GUARNICIONERÍA; ARTÍCULOS DE VIAJE, BOLSOS DE MANO (CARTERAS) Y CONTINENTES SIMILARES; MANUFACTURAS DE TRIPA",
  "IX",   44, 46, "MADERA, CARBÓN VEGETAL Y MANUFACTURAS DE MADERA; CORCHO Y SUS MANUFACTURAS; MANUFACTURAS DE ESPARTERÍA O CESTERÍA",
  "X",    47, 49, "PASTA DE MADERA O DE LAS DEMÁS MATERIAS FIBROSAS CELULÓSICAS; PAPEL O CARTÓN PARA RECICLAR (DESPERDICIOS Y DESECHOS); PAPEL O CARTÓN Y SUS APLICACIONES",
  "XI",   50, 63, "MATERIAS TEXTILES Y SUS MANUFACTURAS",
  "XII",  64, 67, "CALZADO, SOMBREROS Y DEMÁS TOCADOS, PARAGUAS, QUITASOLES, BASTONES, LÁTIGOS, FUSTAS, Y SUS PARTES; PLUMAS PREPARADAS Y ARTÍCULOS DE PLUMAS; FLORES ARTIFICIALES; MANUFACTURAS DE CABELLO",
  "XIII", 68, 70, "MANUFACTURAS DE PIEDRA, YESO FRAGUABLE, CEMENTO, AMIANTO (ASBESTO), MICA O MATERIAS ANÁLOGAS; PRODUCTOS CERÁMICOS; VIDRIO Y SUS MANUFACTURAS",
  "XIV",  71, 71, "PERLAS FINAS (NATURALES) O CULTIVADAS, PIEDRAS PRECIOSAS O SEMIPRECIOSAS, METALES PRECIOSOS, CHAPADOS DE METAL PRECIOSO (PLAQUÉ) Y MANUFACTURAS DE ESTAS MATERIAS; BISUTERÍA; MONEDAS",
  "XV",   72, 83, "METALES COMUNES Y MANUFACTURAS DE ESTOS METALES",
  "XVI",  84, 85, "MÁQUINAS Y APARATOS, MATERIAL ELÉCTRICO Y SUS PARTES; APARATOS DE GRABACIÓN O REPRODUCCIÓN DE SONIDO, APARATOS DE GRABACIÓN O REPRODUCCIÓN DE IMAGEN Y SONIDO EN TELEVISIÓN, Y LAS PARTES Y ACCESORIOS DE ESTOS APARATOS",
  "XVII", 86, 89, "MATERIAL DE TRANSPORTE",
  "XVIII",90, 92, "INSTRUMENTOS Y APARATOS DE ÓPTICA, FOTOGRAFÍA O CINEMATOGRAFÍA, DE MEDIDA, CONTROL O PRECISIÓN; INSTRUMENTOS Y APARATOS MEDICOQUIRÚRGICOS; APARATOS DE RELOJERÍA; INSTRUMENTOS MUSICALES; PARTES Y ACCESORIOS DE ESTOS INSTRUMENTOS O APARATOS",
  "XIX",  93, 93, "ARMAS, MUNICIONES, Y SUS PARTES Y ACCESORIOS",
  "XX",   94, 96, "MERCANCÍAS Y PRODUCTOS DIVERSOS",
  "XXI",  97, 99, "OBJETOS DE ARTE O COLECCIÓN Y ANTIGÜEDADES"
)

# Sección 2. Capítulos y Partidas — fuente: NALADISA 2022                    ####

ruta_naladisa <- here("Excel", "naladisa_2022.xlsx")

naladisa <- read_excel(
  ruta_naladisa,
  sheet = "NALADISA 2022",
  col_names = c("codigo", "descripcion"),
  skip = 2
) |>
  mutate(codigo = trimws(codigo), descripcion = trimws(descripcion))

capitulos <- naladisa |> filter(nchar(codigo) == 2)
partidas  <- naladisa |> filter(nchar(codigo) == 4)

# Capítulos 98 y 99: provisiones especiales de clasificación de EUA (manual)
capitulos_especiales <- tibble(
  codigo      = c("98", "99"),
  descripcion = c("Provisiones especiales de clasificación (EUA)",
                  "Otras provisiones especiales de clasificación (EUA)")
)

# Sección 3. Nombres cortos (CSV editable a mano)                            ####

nombres <- read_csv(here("Excel", "hs_nombres_cortos.csv"),
                    col_types = cols(.default = col_character()),
                    na = c("", "NA")) |>
  mutate(codigo = trimws(codigo))

stopifnot("hs_nombres_cortos.csv: duplicados en nivel+codigo" =
            !anyDuplicated(nombres[, c("nivel", "codigo")]))

# Sección 4. Ensamblaje del diccionario en formato largo                     ####

to_sentence <- function(x) {
  x <- str_to_lower(x)
  str_c(str_to_upper(str_sub(x, 1, 1)), str_sub(x, 2))
}

secciones_tbl <- secciones_oficial |>
  transmute(
    nivel          = "Sección",
    codigo         = Sección,
    codigo_padre   = NA_character_,
    nombre_oficial = to_sentence(nombre_oficial_caps),
    fuente         = "WCO 2022"
  )

seccion_de_capitulo <- secciones_oficial |>
  rowwise() |>
  mutate(cap = list(cap_desde:cap_hasta)) |>
  unnest(cap) |>
  ungroup() |>
  transmute(cap = sprintf("%02d", cap), Sección)

capitulos_tbl <- bind_rows(
  capitulos |> mutate(fuente = "NALADISA 2022"),
  capitulos_especiales |> mutate(fuente = "manual")
) |>
  left_join(seccion_de_capitulo, by = c("codigo" = "cap")) |>
  transmute(
    nivel          = "Capítulo",
    codigo,
    codigo_padre   = Sección,
    nombre_oficial = str_replace(to_sentence(descripcion), "\\(eua\\)", "(EUA)"),
    fuente
  )

partidas_tbl <- partidas |>
  transmute(
    nivel          = "Partida",
    codigo,
    codigo_padre   = substr(codigo, 1, 2),
    nombre_oficial = to_sentence(descripcion),
    fuente         = "NALADISA 2022"
  )

hs_dictionary <- bind_rows(secciones_tbl, capitulos_tbl, partidas_tbl) |>
  left_join(nombres, by = c("nivel", "codigo")) |>
  mutate(nombre_tabla = coalesce(nombre_tabla, nombre_corto)) |>
  select(nivel, codigo, codigo_padre, nombre_corto, nombre_tabla,
         nombre_oficial, fuente)

# Sección 5. Validaciones                                                    ####

huerfanos <- anti_join(nombres, hs_dictionary, by = c("nivel", "codigo"))

stopifnot(
  "No debe haber códigos duplicados dentro de un mismo nivel" =
    hs_dictionary |> count(nivel, codigo) |> pull(n) |> max() == 1,
  "Deben existir 98 Capítulos (96 SA + 98 y 99)" =
    sum(hs_dictionary$nivel == "Capítulo") == 98,
  "Deben existir 21 Secciones" =
    sum(hs_dictionary$nivel == "Sección") == 21,
  "No debe haber nombre_oficial faltante" =
    sum(is.na(hs_dictionary$nombre_oficial)) == 0,
  "Todas las Secciones y Capítulos deben tener nombre_corto" =
    !anyNA(hs_dictionary$nombre_corto[hs_dictionary$nivel != "Partida"]),
  "Hay códigos en hs_nombres_cortos.csv que no existen en el diccionario" =
    nrow(huerfanos) == 0
)

cat("\n=== hs_dictionary construido ===\n")
count(hs_dictionary, nivel) |> print()

sin_corto <- hs_dictionary |> filter(nivel == "Partida", is.na(nombre_corto))
message("Partidas sin nombre_corto: ", nrow(sin_corto),
        " (se agregan a Excel/hs_nombres_cortos.csv solo si se usan)")

largos <- hs_dictionary |> filter(!is.na(nombre_corto), nchar(nombre_corto) > 26)
if (nrow(largos) > 0) warning("nombre_corto con más de 26 caracteres: ",
                              paste(largos$codigo, collapse = ", "))

# Sección 6. Guardado                                                        ####

saveRDS(hs_dictionary, here("RDS", "hs_dictionary.rds"))
message("✔  hs_dictionary.rds guardado. Filas: ", nrow(hs_dictionary))

