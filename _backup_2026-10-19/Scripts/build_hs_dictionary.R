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
# Alcance de esta primera versión:
#   - Secciones:  las 21, completas.
#   - Capítulos:  los 96 capítulos activos del SA (se excluyen el 77,
#                 reservado para uso futuro, y 98/99, que son provisiones
#                 especiales de clasificación de EUA y NO forman parte de la
#                 nomenclatura internacional del SA — no están en NALADISA ni
#                 en WCO Trade Tools. Se omiten de este diccionario; si se
#                 necesitan para fines de EUA, deben tratarse por separado).
#   - Partidas:   únicamente para los capítulos 84, 85, 87 y 90 (manufactura,
#                 eléctrico, automotriz y óptica/médico), que son los de
#                 mayor interés para el proyecto. Se pueden agregar más
#                 capítulos más adelante repitiendo el mismo patrón.
#   - Subpartidas: no incluidas aún; se agregarán entradas puntuales según
#                 se identifiquen necesidades específicas (p. ej. al analizar
#                 Vietnam/Taiwán).
#
# Estructura de salida (formato largo, una fila por código):
#   nivel          — "Sección", "Capítulo" o "Partida"
#   codigo         — "I".."XXI" (Sección); "01".."97" (Capítulo); "8401" etc. (Partida)
#   codigo_padre   — Sección a la que pertenece el Capítulo; Capítulo (2 dígitos)
#                    al que pertenece la Partida; NA para Secciones.
#   nombre_corto   — Etiqueta corta sin acentos/espacios (CamelCase), para usar
#                    en gráficas y leyendas. Definida solo para Sección y
#                    Capítulo por ahora; NA para Partida (pendiente, se
#                    completará solo para las partidas que se usen en análisis).
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

seccion_corto <- c(
  "I"="Animales", "II"="Vegetales", "III"="GrasasAceites", "IV"="Alimentos",
  "V"="Minerales", "VI"="Químicos", "VII"="PlásticosHule", "VIII"="Cuero",
  "IX"="Madera", "X"="Papel", "XI"="Textiles", "XII"="Calzado",
  "XIII"="PiedraCerámica", "XIV"="Joyería", "XV"="MetalesBase", "XVI"="Maquinaria",
  "XVII"="Transporte", "XVIII"="Instrumentos", "XIX"="Armas", "XX"="Manufactura",
  "XXI"="Arte"
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

capitulos <- naladisa |>
  filter(nchar(codigo) == 2)

capitulos_de_interes_hs4 <- c("84", "85", "87", "90")

partidas <- naladisa |>
  filter(nchar(codigo) == 4, substr(codigo, 1, 2) %in% capitulos_de_interes_hs4)

# Nombres cortos para Capítulos — heredados/adaptados de versiones previas
# del proyecto; revisar y ajustar según se detecten imprecisiones.
capitulo_corto <- c(
  "01"="AnimalesVivos","02"="Carnes","03"="Pescados","04"="Lácteos","05"="OtrosAnimales",
  "06"="PlantasVivas","07"="Hortalizas","08"="FrutasNueces","09"="Café","10"="Cereales",
  "11"="Molinería","12"="Semillas","13"="GomasResinas","14"="MatVegetal","15"="GrasasAceites",
  "16"="PrepCarnes","17"="Azúcares","18"="Cacao","19"="PrepCereales","20"="PrepHortalizas",
  "21"="PrepAlim","22"="Bebidas","23"="ResiduosAlim","24"="Tabaco","25"="Sal",
  "26"="Minerales","27"="Combustibles","28"="QuímInorg","29"="QuímOrg","30"="Farmacéuticos",
  "31"="Fertilizantes","32"="Tintes","33"="Perfumes","34"="Jabones","35"="MatAlbuminoideas",
  "36"="Explosivos","37"="FotoCine","38"="QuímDiversos","39"="Plásticos","40"="Caucho",
  "41"="PielesCuero","42"="ArtCuero","43"="Peletería","44"="Madera","45"="Corcho",
  "46"="Cestería","47"="PastaPapel","48"="Papel","49"="ArtEditorial","50"="Seda",
  "51"="LanaFibras","52"="Algodón","53"="FibrasVeg","54"="FilsSint","55"="FibrasSint",
  "56"="Guatas","57"="Alfombras","58"="TejidosEsp","59"="TejidosImp","60"="TejidosPunto",
  "61"="PrendaPunto","62"="PrendaNoTejida","63"="ArtTextilHogar","64"="Calzado","65"="Sombreros",
  "66"="Paraguas","67"="PlumasFlores","68"="PiedraCem","69"="Cerámica","70"="Vidrio",
  "71"="Joyería","72"="HierroAcero","73"="ArtHierroAcero","74"="Cobre","75"="Níquel",
  "76"="Aluminio","78"="Plomo","79"="Zinc","80"="Estaño","81"="OtrosMetales",
  "82"="HerramMetal","83"="ArtMetal","84"="Maquinaria","85"="Eléctrico","86"="Ferroviario",
  "87"="Automóviles","88"="Aeronaves","89"="Barcos","90"="Óptica","91"="Relojería",
  "92"="InstMúsica","93"="Armas","94"="Muebles","95"="Juguetes","96"="ManufDiversas",
  "97"="Arte"
)

stopifnot(
  "Todos los capítulos presentes deben tener nombre corto" =
    all(capitulos$codigo %in% names(capitulo_corto))
)

# Sección 3. Ensamblaje del diccionario en formato largo                     ####

to_sentence <- function(x) {
  x <- str_to_lower(x)
  str_c(str_to_upper(str_sub(x, 1, 1)), str_sub(x, 2))
}

secciones_tbl <- secciones_oficial |>
  transmute(
    nivel          = "Sección",
    codigo         = Sección,
    codigo_padre   = NA_character_,
    nombre_corto   = seccion_corto[Sección],
    nombre_oficial = to_sentence(nombre_oficial_caps)
  )

seccion_de_capitulo <- secciones_oficial |>
  rowwise() |>
  mutate(cap = list(cap_desde:cap_hasta)) |>
  unnest(cap) |>
  transmute(cap = sprintf("%02d", cap), Sección)

capitulos_tbl <- capitulos |>
  left_join(seccion_de_capitulo, by = c("codigo" = "cap")) |>
  transmute(
    nivel          = "Capítulo",
    codigo,
    codigo_padre   = Sección,
    nombre_corto   = capitulo_corto[codigo],
    nombre_oficial = to_sentence(descripcion)
  )

partidas_tbl <- partidas |>
  transmute(
    nivel          = "Partida",
    codigo,
    codigo_padre   = substr(codigo, 1, 2),
    nombre_corto   = NA_character_,   # pendiente, completar según se use
    nombre_oficial = to_sentence(descripcion)
  )

hs_dictionary <- bind_rows(secciones_tbl, capitulos_tbl, partidas_tbl)

# Sección 4. Validaciones                                                    ####

stopifnot(
  "No debe haber códigos duplicados dentro de un mismo nivel" =
    hs_dictionary |> count(nivel, codigo) |> pull(n) |> max() == 1,
  "Deben existir 96 Capítulos activos" =
    sum(hs_dictionary$nivel == "Capítulo") == 96,
  "No debe haber nombre_oficial faltante" =
    sum(is.na(hs_dictionary$nombre_oficial)) == 0
)

cat("\n=== hs_dictionary construido ===\n")
count(hs_dictionary, nivel) |> print()

# Sección 5. Guardado                                                        ####

saveRDS(hs_dictionary, here("RDS", "hs_dictionary.rds"))
message("✔  hs_dictionary.rds guardado. Filas: ", nrow(hs_dictionary))
