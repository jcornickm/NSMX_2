# Query11_Imp_MEX_VNM_TWN_HS4.R   ####
# Importaciones de EUA provenientes de México, Vietnam y Taiwán — Partidas (HS4)
# Fuente: US Census Bureau — International Trade API
# Período: 2010–2025 (años completos) + enero–julio 2026
# Todos los capítulos (sin restringir a 84/85/87/90): el objetivo es identificar,
# de manera independiente para cada país, sus partidas más relevantes, y luego
# intersectar esas listas con las de México (partidas "en competencia").
#
# Este script cubre únicamente LA DESCARGA Y LIMPIEZA (paso 1 del ejercicio).
# La identificación de top-partidas por país y la intersección México vs.
# Vietnam/Taiwán se abordan en un script posterior.

#   NOTAS SOBRE EL API                                                      ####

# • COMM_LVL omitido intencionalmente (igual que en Query3): la combinación
#   CTY_CODE + COMM_LVL genera error del servidor para HS4/HS6. Sin COMM_LVL,
#   el API devuelve todos los niveles mezclados en I_COMMODITY:
#     cod == "-"      →  total nacional
#     nchar(cod) == 2 →  Capítulo (HS2)
#     nchar(cod) == 4 →  Partida  (HS4)      <- nivel usado en este ejercicio
#     nchar(cod) == 6 →  Subpartida (HS6)
#     nchar(cod) == 10→  Schedule B (10 dígitos)
#   Se separan por nchar(I_COMMODITY) en la limpieza, igual que en Query3.
# • CTY_CODE: México = 2010, Vietnam = 5520, Taiwán = 5830
#   (códigos tomados de Query1_USA_imports_by_country.R, ya verificados).
# • Se itera año por año (y por país) — el API falla con rangos temporales
#   largos. 2026 se descarga aparte, como período parcial (enero–julio).
# • Cada combinación país-año se guarda inmediatamente como RDS individual
#   para proteger el progreso ante fallos de conexión.

pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse,
               here, janitor, censusapi, scales)

#  Sección 1. Tareas preparatorias                                          ####

api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("CENSUS_API_KEY no encontrado — definir en .Renviron" =
            nchar(api_key) > 0)
dir.create(here("RDS", "raw"), recursive = TRUE, showWarnings = FALSE)

## Países incluidos                                                         ####
paises <- tribble(
  ~CTY_CODE, ~Pais,
  "2010",    "México",
  "5520",    "Vietnam",
  "5830",    "Taiwán"
)

## Tablas de referencia (idénticas a Query3, para mantener consistencia)    ####

secciones_sa <- tribble(
  ~Sección, ~Sección_corto,   ~Sección_desc_es,                                              ~Sección_desc_orig,                                          ~cap_desde, ~cap_hasta,
  "I",      "Animales",       "Animales vivos y productos del reino animal",                  "Live animals; animal products",                                  1,   5,
  "II",     "Vegetales",      "Productos del reino vegetal",                                  "Vegetable products",                                             6,  14,
  "III",    "GrasasAceites",  "Grasas y aceites animales o vegetales",                        "Animal or vegetable fats and oils",                             15,  15,
  "IV",     "Alimentos",      "Productos de las industrias alimentarias; bebidas y tabaco",   "Prepared foodstuffs; beverages; tobacco",                        16,  24,
  "V",      "Minerales",      "Productos minerales",                                          "Mineral products",                                              25,  27,
  "VI",     "Químicos",       "Productos de las industrias químicas",                         "Chemical and allied industries",                                28,  38,
  "VII",    "PlásticosHule",  "Plásticos y caucho",                                           "Plastics and rubber",                                           39,  40,
  "VIII",   "Cuero",          "Pieles, cueros y sus manufacturas",                            "Raw hides, skins, leather, furskins",                           41,  43,
  "IX",     "Madera",         "Madera, carbón vegetal y sus manufacturas",                    "Wood and articles of wood",                                     44,  46,
  "X",      "Papel",          "Pasta de madera; papel y cartón",                              "Pulp of wood; paper and paperboard",                            47,  49,
  "XI",     "Textiles",       "Materias textiles y sus manufacturas",                         "Textiles and textile articles",                                 50,  63,
  "XII",    "Calzado",        "Calzado, sombreros y artículos similares",                     "Footwear, headgear, umbrellas",                                 64,  67,
  "XIII",   "PiedraCerámica", "Manufacturas de piedra, yeso, cerámica y vidrio",              "Articles of stone, plaster, ceramics, glass",                   68,  70,
  "XIV",    "Joyería",        "Perlas, piedras preciosas y metales preciosos",                "Natural or cultured pearls, precious metals",                   71,  71,
  "XV",     "MetalesBase",    "Metales comunes y sus manufacturas",                           "Base metals and articles",                                      72,  83,
  "XVI",    "Maquinaria",     "Máquinas, aparatos y material eléctrico",                      "Machinery and mechanical appliances; electrical equipment",      84,  85,
  "XVII",   "Transporte",     "Material de transporte",                                       "Vehicles, aircraft, vessels",                                   86,  89,
  "XVIII",  "Instrumentos",   "Instrumentos de óptica, fotografía y medicina",                "Optical, photographic, medical instruments",                     90,  92,
  "XIX",    "Armas",          "Armas y municiones",                                           "Arms and ammunition",                                           93,  93,
  "XX",     "Manufactura",    "Mercancías y productos diversos",                              "Miscellaneous manufactured articles",                           94,  96,
  "XXI",    "Arte",           "Objetos de arte, de colección o de antigüedad",                "Works of art, collectors' pieces",                              97,  99
) |>
  rowwise() |>
  mutate(Capítulo = list(cap_desde:cap_hasta)) |>
  unnest(Capítulo) |>
  select(Capítulo, Sección, Sección_corto, Sección_desc_es, Sección_desc_orig)

niveles_sección <- c("I","II","III","IV","V","VI","VII","VIII","IX","X",
                     "XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX","XXI")

capitulos_es <- tribble(
  ~Capítulo, ~Cap_corto,          ~Cap_desc_es,
  1,  "AnimalesVivos",     "Animales vivos",
  2,  "Carnes",            "Carne y despojos comestibles",
  3,  "Pescados",          "Pescados y crustáceos",
  4,  "Lácteos",           "Leche, productos lácteos y huevos",
  5,  "OtrosAnimales",     "Otros productos de origen animal",
  6,  "PlantasVivas",      "Plantas vivas y productos de floricultura",
  7,  "Hortalizas",        "Hortalizas y plantas",
  8,  "FrutasNueces",      "Frutas y frutos secos",
  9,  "Café",              "Café, té, yerba mate y especias",
  10,  "Cereales",          "Cereales",
  11,  "Molinería",         "Productos de molinería",
  12,  "Semillas",          "Semillas y frutos oleaginosos",
  13,  "GomasResinas",      "Gomas, resinas y demás jugos vegetales",
  14,  "MatVegetal",        "Materias trenzables y vegetales",
  15,  "GrasasAceites",     "Grasas y aceites animales o vegetales",
  16,  "PrepCarnes",        "Preparaciones de carne o pescado",
  17,  "Azúcares",          "Azúcares y artículos de confitería",
  18,  "Cacao",             "Cacao y sus preparaciones",
  19,  "PrepCereales",      "Preparaciones a base de cereales",
  20,  "PrepHortalizas",    "Preparaciones de hortalizas y frutas",
  21,  "PrepAlim",          "Preparaciones alimenticias diversas",
  22,  "Bebidas",           "Bebidas, líquidos alcohólicos y vinagre",
  23,  "ResiduosAlim",      "Residuos de las industrias alimentarias",
  24,  "Tabaco",            "Tabaco y sucedáneos del tabaco",
  25,  "Sal",               "Sal, azufre, tierras y piedras",
  26,  "Minerales",         "Minerales metalíferos, escorias y cenizas",
  27,  "Combustibles",      "Combustibles y aceites minerales",
  28,  "QuímInorg",         "Productos químicos inorgánicos",
  29,  "QuímOrg",           "Productos químicos orgánicos",
  30,  "Farmacéuticos",     "Productos farmacéuticos",
  31,  "Fertilizantes",     "Fertilizantes",
  32,  "Tintes",            "Extractos curtientes y tintóreos",
  33,  "Perfumes",          "Aceites esenciales y perfumería",
  34,  "Jabones",           "Jabones y preparaciones de limpieza",
  35,  "MatAlbuminoideas",  "Materias albuminoideas y almidones",
  36,  "Explosivos",        "Explosivos y artículos de pirotecnia",
  37,  "FotoCine",          "Productos fotográficos o cinematográficos",
  38,  "QuímDiversos",      "Productos químicos diversos",
  39,  "Plásticos",         "Plásticos y sus manufacturas",
  40,  "Caucho",            "Caucho y sus manufacturas",
  41,  "PielesCuero",       "Pieles y cueros",
  42,  "ArtCuero",          "Manufacturas de cuero",
  43,  "Peletería",         "Peletería y confecciones de peletería",
  44,  "Madera",            "Madera y sus manufacturas",
  45,  "Corcho",            "Corcho y sus manufacturas",
  46,  "Cestería",          "Manufacturas de espartería o cestería",
  47,  "PastaPapel",        "Pasta de madera y demás materias fibrosas",
  48,  "Papel",             "Papel, cartón y sus manufacturas",
  49,  "ArtEditorial",      "Productos editoriales e impresos",
  50,  "Seda",              "Seda",
  51,  "LanaFibras",        "Lana y pelo fino u ordinario",
  52,  "Algodón",           "Algodón",
  53,  "FibrasVeg",         "Fibras vegetales textiles",
  54,  "FilasSint",         "Filamentos sintéticos o artificiales",
  55,  "FibrasSint",        "Fibras discontinuas sintéticas o artificiales",
  56,  "Guatas",            "Guatas, fieltros y telas sin tejer",
  57,  "Alfombras",         "Alfombras y revestimientos textiles para el suelo",
  58,  "TejidosEsp",        "Tejidos especiales",
  59,  "TejidosImp",        "Telas impregnadas y recubiertas",
  60,  "TejidosPunto",      "Tejidos de punto",
  61,  "PrendaPunto",       "Prendas de vestir de punto",
  62,  "PrendaNoTejida",    "Prendas de vestir (excepto las de punto)",
  63,  "ArtTextilHogar",    "Artículos textiles confeccionados para el hogar",
  64,  "Calzado",           "Calzado",
  65,  "Sombreros",         "Sombreros y artículos de tocado",
  66,  "Paraguas",          "Paraguas y sombrillas",
  67,  "PlumasFlores",      "Plumas preparadas y flores artificiales",
  68,  "PiedraCem",         "Manufacturas de piedra, yeso y cemento",
  69,  "Cerámica",          "Productos cerámicos",
  70,  "Vidrio",            "Vidrio y sus manufacturas",
  71,  "Joyería",           "Perlas, piedras y metales preciosos",
  72,  "HierroAcero",       "Fundición, hierro y acero",
  73,  "ArtHierroAcero",    "Manufacturas de fundición, hierro o acero",
  74,  "Cobre",             "Cobre y sus manufacturas",
  75,  "Níquel",            "Níquel y sus manufacturas",
  76,  "Aluminio",          "Aluminio y sus manufacturas",
  78,  "Plomo",             "Plomo y sus manufacturas",
  79,  "Zinc",              "Zinc y sus manufacturas",
  80,  "Estaño",            "Estaño y sus manufacturas",
  81,  "OtrosMetales",      "Otros metales comunes y sus manufacturas",
  82,  "HerramMetal",       "Herramientas y útiles de metal común",
  83,  "ArtMetal",          "Manufacturas diversas de metal común",
  84,  "Maquinaria",        "Reactores nucleares, calderas y maquinaria",
  85,  "Eléctrico",         "Máquinas y aparatos eléctricos",
  86,  "Ferroviario",       "Vehículos y material para vías férreas",
  87,  "Automóviles",       "Automóviles y vehículos terrestres",
  88,  "Aeronaves",         "Aeronaves y artefactos espaciales",
  89,  "Barcos",            "Barcos y embarcaciones",
  90,  "Óptica",            "Instrumentos de óptica, fotografía y medicina",
  91,  "Relojería",         "Relojería",
  92,  "InstMúsica",        "Instrumentos musicales",
  93,  "Armas",             "Armas y municiones",
  94,  "Muebles",           "Muebles y artículos de alumbrado",
  95,  "Juguetes",          "Juguetes y artículos deportivos",
  96,  "ManufDiversas",     "Manufacturas diversas",
  97,  "Arte",              "Objetos de arte, de colección o de antigüedad",
  98,  "EspecialEUA",       "Provisiones especiales de clasificación EUA",
  99,  "OtrasEspeciales",   "Otras provisiones especiales"
)

# Sección 2. Descarga de datos — por país y año   ####

descargar_periodo <- function(cty_code, pais, etiqueta_periodo, time_str) {
  archivo <- here("RDS", "raw", paste0("raw_hs_", cty_code, "_", etiqueta_periodo, ".rds"))
  if (file.exists(archivo)) {
    message("  [", pais, " ", etiqueta_periodo, "] ya existe — se omite descarga.")
    return(readRDS(archivo))
  }
  message("  [", pais, " ", etiqueta_periodo, "] descargando...")
  tryCatch({
    resultado <- getCensus(
      name     = "timeseries/intltrade/imports/hs",
      vars     = c("I_COMMODITY", "I_COMMODITY_LDESC", "GEN_VAL_MO", "GEN_VAL_YR"),
      time     = time_str,
      key      = api_key,
      CTY_CODE = cty_code
    ) |>
      mutate(CTY_CODE_dl = cty_code, Pais = pais)
    saveRDS(resultado, archivo)
    message("  [", pais, " ", etiqueta_periodo, "] guardado: ", basename(archivo))
    resultado
  }, error = function(e) {
    message("  ERROR [", pais, " ", etiqueta_periodo, "]: ", conditionMessage(e))
    NULL
  })
}

años_completos <- 2010:2025

# — Años completos 2010–2025, por país ----------------------------------------
message("\n=== Descargando años completos 2010–2025 — México, Vietnam, Taiwán ===")

plan_años <- expand_grid(paises, año = años_completos)

raw_list_años <- pmap(
  plan_años,
  function(CTY_CODE, Pais, año) {
    descargar_periodo(
      cty_code         = CTY_CODE,
      pais             = Pais,
      etiqueta_periodo = as.character(año),
      time_str         = paste0("from ", año, " to ", año)
    )
  }
)

# — Período parcial 2026 (enero–julio), por país -------------------------------
message("\n=== Descargando enero–julio 2026 — México, Vietnam, Taiwán ===")

raw_list_2026 <- pmap(
  paises,
  function(CTY_CODE, Pais) {
    descargar_periodo(
      cty_code         = CTY_CODE,
      pais             = Pais,
      etiqueta_periodo = "2026_ene_jul",
      time_str         = "from 2026-01 to 2026-07"
    )
  }
)

raw_list <- c(raw_list_años, raw_list_2026)

fallos <- sum(map_lgl(raw_list, is.null))
if (fallos > 0) message(fallos, " descargas fallaron — revisar mensajes anteriores y volver a correr el script (se omiten las que ya tienen RDS).")

# Sección 3. Ensamblaje   ####

message("\n=== Ensamblando archivos raw (México, Vietnam, Taiwán — 2010 a jul-2026) ===")

raw_df <- raw_list |>
  compact() |>
  bind_rows() |>
  as_tibble()

cat("Filas en raw_df:", nrow(raw_df), "\n")
cat("\nFilas por país:\n")
raw_df |> count(Pais) |> print()

saveRDS(raw_df, here("RDS", "raw_df_mex_vnm_twn.rds"))

# Sección 4. Limpieza — variables derivadas, nivel de agregación   ####

message("\n=== Limpieza y clasificación de niveles ===")

imp_competidores_all <- raw_df |>
  mutate(
    fecha    = as.Date(paste0(time, "-01")),
    cod      = as.character(I_COMMODITY),
    nivel    = case_when(
      cod == "-"         ~ "total",
      nchar(cod) == 2    ~ "HS2",
      nchar(cod) == 4    ~ "HS4",
      nchar(cod) == 6    ~ "HS6",
      nchar(cod) == 10   ~ "HS10",
      .default           = "otro"
    ),
    Capítulo = case_when(
      nivel == "HS2"  ~ as.integer(cod),
      nivel == "HS4"  ~ as.integer(substr(cod, 1, 2)),
      nivel == "HS6"  ~ as.integer(substr(cod, 1, 2)),
      nivel == "HS10" ~ as.integer(substr(cod, 1, 2)),
      .default        = NA_integer_
    ),
    Val_mes  = as.numeric(GEN_VAL_MO),
    Val_acum = as.numeric(GEN_VAL_YR)
  )

cat("\nDistribución de niveles en imp_competidores_all:\n")
imp_competidores_all |> count(Pais, nivel) |> print(n = 30)

# Sección 5. Partidas (HS4) — los tres países, todos los capítulos   ####

agregar_etiquetas <- function(df) {
  df |>
    left_join(secciones_sa,  by = "Capítulo") |>
    left_join(capitulos_es,  by = "Capítulo") |>
    mutate(
      Sección         = factor(Sección,         levels = niveles_sección, ordered = TRUE),
      Sección_corto   = factor(Sección_corto,
                               levels = secciones_sa |>
                                 distinct(Sección, Sección_corto) |>
                                 arrange(factor(Sección, levels = niveles_sección)) |>
                                 pull(Sección_corto),
                               ordered = TRUE),
      Sección_desc_es = factor(Sección_desc_es,
                               levels = secciones_sa |>
                                 distinct(Sección, Sección_desc_es) |>
                                 arrange(factor(Sección, levels = niveles_sección)) |>
                                 pull(Sección_desc_es),
                               ordered = TRUE),
      Cap_corto       = factor(Cap_corto,
                               levels = capitulos_es |>
                                 arrange(Capítulo) |>
                                 pull(Cap_corto),
                               ordered = TRUE),
      Cap_desc_es     = factor(Cap_desc_es,
                               levels = capitulos_es |>
                                 arrange(Capítulo) |>
                                 pull(Cap_desc_es),
                               ordered = TRUE)
    )
}

message("\n=== Construyendo imp_competidores_hs4 (México, Vietnam, Taiwán — todos los capítulos) ===")

imp_competidores_hs4 <- imp_competidores_all |>
  filter(nivel == "HS4") |>
  agregar_etiquetas() |>
  mutate(
    Desc_api_partida = as.character(I_COMMODITY_LDESC)
  ) |>
  select(
    Pais,
    fecha,
    Sección,
    Sección_corto,
    Sección_desc_es,
    Capítulo,
    Cap_corto,
    Cap_desc_es,
    Cod_partida      = cod,
    Desc_api_partida,
    Val_mes,
    Val_acum
  ) |>
  arrange(Pais, fecha, Capítulo, Cod_partida)

cat("Filas en imp_competidores_hs4:", nrow(imp_competidores_hs4), "\n")
cat("\nCobertura temporal por país:\n")
imp_competidores_hs4 |>
  group_by(Pais) |>
  summarise(desde = min(fecha), hasta = max(fecha), n_meses = n_distinct(fecha), .groups = "drop") |>
  print()

cat("\nPartidas distintas por país:\n")
imp_competidores_hs4 |>
  distinct(Pais, Cod_partida) |>
  count(Pais, name = "n_partidas") |>
  print()

# Sección 6. Metadatos y guardado   ####

meta_query11 <- list(
  fuente              = "US Census Bureau — International Trade API",
  endpoint            = "timeseries/intltrade/imports/hs",
  url                 = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga      = Sys.time(),
  países              = "México (CTY_CODE = 2010), Vietnam (CTY_CODE = 5520), Taiwán (CTY_CODE = 5830)",
  período             = "2010-01 a 2025-12 (años completos) + 2026-01 a 2026-07 (parcial)",
  capítulos           = "Todos (sin restringir) — el filtro a capítulos/partidas de interés se hace en un script posterior",
  nivel               = "Partida (HS4) — filtrado por nchar(I_COMMODITY) == 4",
  archivos            = list(
    raw_df_mex_vnm_twn   = "Descarga cruda, los tres países, todos los niveles HS mezclados",
    imp_competidores_hs4 = "Partidas (HS4), los tres países, todos los capítulos, 2010 – jul 2026"
  ),
  notas               = "COMM_LVL omitido intencionalmente (igual que Query3): la combinación
                         CTY_CODE + COMM_LVL devuelve error del servidor. El API devuelve todos
                         los niveles mezclados cuando COMM_LVL se omite; se extrae HS4 filtrando
                         por nchar(I_COMMODITY). Val_mes y Val_acum en dólares corrientes.
                         2026 es año parcial (solo enero–julio) — no comparar directamente
                         contra años completos sin anualizar.
                         Paso siguiente: identificar top-partidas por país (valor 2024–2025 o
                         2024–jul2026) e intersectar con la lista de México para hallar partidas
                         en que México compite con Vietnam y/o Taiwán."
)

tryCatch({
  saveRDS(imp_competidores_hs4, here("RDS", "imp_competidores_hs4.rds"))
  message("✔  imp_competidores_hs4.rds guardado. Filas: ", nrow(imp_competidores_hs4))
}, error = function(e) message("✗  ERROR guardando imp_competidores_hs4.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(meta_query11, here("RDS", "meta_query11.rds"))
  message("✔  meta_query11.rds guardado.")
}, error = function(e) message("✗  ERROR guardando meta_query11.rds: ", conditionMessage(e)))
