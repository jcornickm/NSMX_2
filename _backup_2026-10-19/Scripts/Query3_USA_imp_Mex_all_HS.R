
# Query3_USA_Imp_Mex_all_HS.R   ####
# Importaciones de EUA provenientes de México — todos los niveles HS
# Fuente: US Census Bureau — International Trade API
# Período: 2010–2025
# Capítulos de interés: 84 (Maquinaria), 85 (Eléctrico),
#                       87 (Automóviles),  90 (Óptica)


#   NOTAS SOBRE EL API                                                      ####

# • COMM_LVL omitido intencionalmente. La combinación CTY_CODE + COMM_LVL
#   genera error del servidor para HS4 y HS6 (confirmado abril 2026).
#   Sin COMM_LVL, el API devuelve todos los niveles mezclados en I_COMMODITY:
#     cod == "-"      →  total nacional
#     nchar(cod) == 2 →  Capítulo (HS2)
#     nchar(cod) == 4 →  Partida  (HS4)
#     nchar(cod) == 6 →  Subpartida (HS6)
#     nchar(cod) == 10→  Schedule B (10 dígitos)
#   Se separan por nchar(I_COMMODITY) en la limpieza.
# • CTY_CODE = "2010" corresponde a México.
# • Se itera año por año — el API falla con rangos temporales largos.
# • Cada año se guarda inmediatamente como RDS individual para proteger
#   el progreso ante fallos de conexión.

pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse,
               here, janitor, censusapi, scales)

#  Sección 1. Tareas preparatorias                                          ####

## Api y directorio para resultados intermedios                             ####
api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("CENSUS_API_KEY no encontrado — definir en .Renviron" =
            nchar(api_key) > 0)
dir.create(here("RDS", "raw"), recursive = TRUE, showWarnings = FALSE)


## Tablas de referencia                                                     ####

# Secciones del SA

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

# Capítulos del SA (nombres en español)
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



# Sección 2. Descarga de datos     ####

 descargar_año <- function(año) {
   message("  Año: ", año)
   tryCatch({
     resultado <- getCensus(
       name     = "timeseries/intltrade/imports/hs",
       vars     = c("I_COMMODITY", "I_COMMODITY_LDESC", "GEN_VAL_MO", "GEN_VAL_YR"),
       time     = paste0("from ", año, " to ", año),
       key      = api_key,
       CTY_CODE = "2010"
     )
     saveRDS(resultado, here("RDS", "raw", paste0("raw_hs6_", año, ".rds")))
     message("  Guardado: raw_hs6_", año, ".rds")
     resultado
   }, error = function(e) {
     message("  ERROR en año ", año, ": ", conditionMessage(e))
     NULL
   })
 }

 años     <- 2025:2025  # we run one year at a time

 message("\n=== Descargando datos — México → EUA ===")
 raw_list <- map(años, descargar_año)
 
 años_fail <- años[map_lgl(raw_list, is.null)]
 if (length(años_fail) > 0) message("Años con error: ", paste(años_fail, collapse = ", "))


# SECCIÓN 3.  Ensamblaje de los archvivos con datos anuales

message("\n=== Ensamblando archivos raw (2010–2025) ===")

raw_list <- map(
  2010:2025,
  ~ readRDS(here("RDS", "raw", paste0("raw_hs6_", .x, ".rds")))
)

raw_df <- raw_list |>
  compact() |>
  bind_rows() |>
  as_tibble()

cat("Filas en raw_df:", nrow(raw_df), "\n")

saveRDS(raw_df, here("RDS", "raw_df.rds")) # Importaciones USA desde MX, todos los niveles de agregación

# ==============================================================================
# SECCIÓN 3: LIMPIEZA — variables derivadas, nivel de agregación, filtro
# ==============================================================================

message("\n=== Limpieza y clasificación de niveles ===")

USallImpMex <- raw_df |>
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

saveRDS(raw_df, here("RDS", "USallImpMex.rds")) # Importaciones USA desde MX, todos los niveles de agregación
# Diagnóstico de niveles recibidos
cat("\nDistribución de niveles en USallImpMex:\n")
USallImpMex |> count(nivel) |> print()


# ==============================================================================
# SECCIÓN 4: CONSTRUCCIÓN DE OBJETOS FINALES
# ==============================================================================

# — Función auxiliar: aplicar etiquetas de Sección y Capítulo como factores ---
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

# ---- 4a. Partidas (HS4) ------------------------------------------------------

message("\n=== Construyendo imp_mex_hs4_all (todos los capítulos) ===")

imp_mex_hs4_all <- raw_df |>
  filter(nivel == "HS4") |>
  agregar_etiquetas() |>
  mutate(
    Desc_api_partida = as.character(I_COMMODITY_LDESC)
  ) |>
  select(
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
  arrange(fecha, Capítulo, Cod_partida)

cat("\nPartidas por Capítulo (HS4):\n")
imp_mex_hs4_all |>
  distinct(Capítulo, Cod_partida) |>
  count(Capítulo, name = "n_partidas") |>
  left_join(capitulos_es, by = "Capítulo") |>
  select(Capítulo, Cap_corto, n_partidas) |>
  print()

cat("Filas en imp_mex_hs4_all:", nrow(imp_mex_hs4_all), "\n")

# ---- 4b. Subpartidas (HS6) ---------------------------------------------------

message("\n=== Construyendo imp_mex_hs6_all (todos los capítulos) ===")

imp_mex_hs6_all <- raw_df |>
  filter(nivel == "HS6") |>
  agregar_etiquetas() |>
  mutate(
    Cod_partida      = substr(cod, 1, 4),
    Desc_api_subpart = as.character(I_COMMODITY_LDESC)
  ) |>
  select(
    fecha,
    Sección,
    Sección_corto,
    Sección_desc_es,
    Capítulo,
    Cap_corto,
    Cap_desc_es,
    Cod_partida,
    Cod_subpartida   = cod,
    Desc_api_subpart,
    Val_mes,
    Val_acum
  ) |>
  arrange(fecha, Capítulo, Cod_subpartida)

cat("\nSubpartidas por Capítulo (HS6):\n")
imp_mex_hs6_all |>
  distinct(Capítulo, Cod_subpartida) |>
  count(Capítulo, name = "n_subpartidas") |>
  left_join(capitulos_es, by = "Capítulo") |>
  select(Capítulo, Cap_corto, n_subpartidas) |>
  print()

cat("Filas en imp_mex_hs6_all:", nrow(imp_mex_hs6_all), "\n")

# ---- 4c. Versiones filtradas a capítulos de interés -------------------------
caps_seleccionados <- c(84, 85, 87, 90)

imp_mex_hs4_84858790 <- imp_mex_hs4_all |> filter(Capítulo %in% caps_seleccionados)
imp_mex_hs6_84858790 <- imp_mex_hs6_all |> filter(Capítulo %in% caps_seleccionados)

cat("\nFilas en imp_mex_hs4_84858790:", nrow(imp_mex_hs4_84858790), "\n")
cat("Filas en imp_mex_hs6_84858790:", nrow(imp_mex_hs6_84858790), "\n")

# ---- 4d.  Top  partidas capitulos 84,85,87,90


# 1. Nombres en español (largo y corto) por partida
# Hay "trampa" en el código, en el sentido de que primero se identificaron las partidas más importantes y luego se creó esta tabla

nombres_partidas <- tribble(
  ~Cod_partida, ~Part_corto,       ~Part_desc_es,
  "8471", "Computadoras",    "Máquinas automáticas de procesamiento de datos",
  "8415", "AireAcond",       "Máquinas de aire acondicionado y sus partes",
  "8418", "Refrigeración",   "Refrigeradores, congeladores y equipo de refrigeración",
  "8421", "Centrifugadoras", "Centrifugadoras; máquinas para filtrar o depurar",
  "8407", "MotoresComb",     "Motores de émbolo de encendido por chispa",
  "8409", "PartesMotores",   "Partes para motores de combustión interna",
  "8481", "Válvulas",        "Grifos, llaves, válvulas y accesorios similares",
  "8414", "BombasAire",      "Bombas de aire/vacío, compresores y ventiladores",
  "8413", "BombasLiq",       "Bombas para líquidos y elevadores de líquidos",
  "8544", "CablesElec",      "Hilos, cables y conductores eléctricos aislados",
  "8517", "Teléfonos",       "Teléfonos, smartphones y aparatos de telecomunicación",
  "8528", "Televisores",     "Receptores de televisión, monitores y proyectores",
  "8537", "Tableros",        "Cuadros, paneles y consolas para control eléctrico",
  "8504", "Transformadores", "Transformadores eléctricos y convertidores estáticos",
  "8543", "MaqElecEsp",      "Máquinas y aparatos eléctricos de función propia",
  "8536", "AparatosConex",   "Aparatos para corte o protección de circuitos ≤1000V",
  "8501", "MotoresElec",     "Motores y generadores eléctricos",
  "8512", "IluminaciónVeh",  "Equipo eléctrico de iluminación/señalización para vehículos",
  "8516", "CalefElec",       "Calentadores eléctricos y aparatos electrotérmicos",
  "8703", "AutosPasajeros",  "Automóviles y vehículos para transporte de personas",
  "8704", "CamionesVeh",     "Vehículos para transporte de mercancías",
  "8708", "PartesAutos",     "Partes y accesorios para vehículos automotores",
  "9018", "InstMédicos",     "Instrumentos para medicina, cirugía y veterinaria",
  "9021", "OrtopedAud",      "Aparatos ortopédicos, prótesis y audífonos",
  "9028", "Medidores",       "Contadores de gas, líquidos y electricidad",
  "9032", "Reguladores",     "Instrumentos de regulación y control automático",
  "9019", "AparatosTerapia", "Aparatos de mecanoterapia, masaje y respiración",
  "9029", "Velocímetros",    "Cuentarrevoluciones, velocímetros y estroboscopios",
  "9026", "MedPresión",      "Instrumentos para medición de flujo, nivel y presión"
)

# 2. Identificar top partidas con base en 2024-2025
codigos_top <- imp_mex_hs4_84858790 |>
  filter(fecha >= "2024-01-01") |>
  group_by(Capítulo, Cap_corto, Cod_partida, Desc_api_partida) |>
  summarise(Val_total = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
  group_by(Capítulo, Cap_corto) |>
  arrange(desc(Val_total), .by_group = TRUE) |>
  mutate(
    share      = Val_total / sum(Val_total),
    share_acum = cumsum(share),
    incluir    = lag(share_acum, default = 0) < 0.80
  ) |>
  filter(incluir) |>
  ungroup() |>
  pull(Cod_partida)

# 3. Serie mensual completa 2010-2025, solo top partidas, con nombres en español
imp_mex_top_hs4 <- imp_mex_hs4_84858790 |>
  filter(Cod_partida %in% codigos_top) |>
  left_join(nombres_partidas, by = "Cod_partida")

# 4. Verificación
imp_mex_top_hs4 |>
  distinct(Capítulo, Cap_corto, Cod_partida, Part_corto, Part_desc_es) |>
  arrange(Capítulo, Cod_partida) |>
  print(n = 50)





# ==============================================================================
# SECCIÓN 5: VERIFICACIÓN DE CONSISTENCIA — HS4 vs. imp_mex_sec_cap (Query 2)
# ==============================================================================

rds_sec_cap <- here("RDS", "imp_mex_sec_cap.rds")

if (file.exists(rds_sec_cap)) {
  
  message("\n=== Verificación de consistencia: suma HS4 vs. imp_mex_sec_cap ===")
  imp_mex_sec_cap <- readRDS(rds_sec_cap)
  
  fechas_comunes <- intersect(
    unique(imp_mex_hs4_all$fecha),
    unique(imp_mex_sec_cap$fecha)
  )
  
  suma_hs4 <- imp_mex_hs4_all |>
    filter(fecha %in% fechas_comunes) |>
    group_by(fecha, Capítulo) |>
    summarise(suma_partidas = sum(Val_mes, na.rm = TRUE), .groups = "drop")
  
  suma_cap <- imp_mex_sec_cap |>
    filter(fecha %in% fechas_comunes) |>
    select(fecha, Capítulo, Val_cap = Val_mes)
  
  verif_hs4 <- left_join(suma_hs4, suma_cap, by = c("fecha", "Capítulo")) |>
    mutate(
      diferencia = suma_partidas - Val_cap,
      dif_pct    = diferencia / Val_cap * 100
    )
  
  cat("Diferencia máxima (USD):",
      scales::comma(max(abs(verif_hs4$diferencia), na.rm = TRUE)), "\n")
  cat("Diferencia máxima (%)  :",
      round(max(abs(verif_hs4$dif_pct), na.rm = TRUE), 4), "\n")
  
  if (max(abs(verif_hs4$diferencia), na.rm = TRUE) == 0) {
    cat("✔  Las sumas de Partidas coinciden exactamente con imp_mex_sec_cap.\n")
  } else {
    cat("⚠️  Existen discrepancias — revisar 'verif_hs4' para el detalle.\n")
  }
  
} else {
  message("  imp_mex_sec_cap.rds no encontrado — se omite la verificación de consistencia.")
}


# ==============================================================================
# SECCIÓN 6: METADATOS Y GUARDADO
# ==============================================================================

# — Versiones filtradas a los capítulos de interés ----------------------------
imp_mex_hs4_caps <- imp_mex_hs4_all |> filter(Capítulo %in% caps_seleccionados)
imp_mex_hs6_caps <- imp_mex_hs6_all |> filter(Capítulo %in% caps_seleccionados)

cat("\nFilas en imp_mex_hs4_caps (caps. 84/85/87/90):", nrow(imp_mex_hs4_caps), "\n")
cat("Filas en imp_mex_hs6_caps (caps. 84/85/87/90):", nrow(imp_mex_hs6_caps), "\n")

meta_query3 <- list(
  fuente              = "US Census Bureau — International Trade API",
  endpoint            = "timeseries/intltrade/imports/hs",
  url                 = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga      = Sys.time(),
  país_origen         = "México (CTY_CODE = 2010)",
  caps_seleccionados  = "84 (Maquinaria), 85 (Eléctrico), 87 (Automóviles), 90 (Óptica)",
  nivel_hs4           = "Partida (4 dígitos) — filtrado por nchar(I_COMMODITY) == 4",
  nivel_hs6           = "Subpartida (6 dígitos) — filtrado por nchar(I_COMMODITY) == 6",
  período_hs4         = paste(range(imp_mex_hs4_all$fecha), collapse = " – "),
  período_hs6         = paste(range(imp_mex_hs6_all$fecha), collapse = " – "),
  archivos            = list(
    imp_mex_hs4_all      = "Partidas (HS4), todos los capítulos",
    imp_mex_hs4_84858790 = "Partidas (HS4), capítulos 84/85/87/90 únicamente",
    imp_mex_hs6_all      = "Subpartidas (HS6), todos los capítulos",
    imp_mex_hs6_84858790 = "Subpartidas (HS6), capítulos 84/85/87/90 únicamente"
  ),
  notas               = "COMM_LVL omitido intencionalmente: la combinación CTY_CODE +
                         COMM_LVL='HS4' devuelve error del servidor (confirmado abril 2026).
                         El API devuelve todos los niveles mezclados cuando COMM_LVL se omite;
                         se extrae HS4 y HS6 filtrando por nchar(I_COMMODITY).
                         Val_mes y Val_acum en dólares corrientes.
                         Nombres de Sección y Capítulo en español, almacenados como factores
                         ordenados según el orden natural del SA (Secciones I–XXI; Caps. 1–99).
                         No incluye filas de totales; calcular con group_by()."
)

tryCatch({
  saveRDS(imp_mex_hs4_all,      here("RDS", "imp_mex_hs4.rds"))
  message("✔  imp_mex_hs4.rds guardado.       Filas: ", nrow(imp_mex_hs4_all))
}, error = function(e) message("✗  ERROR guardando imp_mex_hs4.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(imp_mex_hs4_84858790, here("RDS", "imp_mex_hs4_84858790.rds"))
  message("✔  imp_mex_hs4_84858790.rds guardado. Filas: ", nrow(imp_mex_hs4_84858790))
}, error = function(e) message("✗  ERROR guardando imp_mex_hs4_84858790.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(imp_mex_hs6_all,      here("RDS", "imp_mex_hs6.rds"))
  message("✔  imp_mex_hs6.rds guardado.       Filas: ", nrow(imp_mex_hs6_all))
}, error = function(e) message("✗  ERROR guardando imp_mex_hs6.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(imp_mex_hs6_84858790, here("RDS", "imp_mex_hs6_84858790.rds"))
  message("✔  imp_mex_hs6_84858790.rds guardado. Filas: ", nrow(imp_mex_hs6_84858790))
}, error = function(e) message("✗  ERROR guardando imp_mex_hs6_84858790.rds: ", conditionMessage(e)))

tryCatch({
  saveRDS(imp_mex_top_hs4, here("RDS", "imp_mex_top_hs4.rds"))
  message("✔  imp_mex_top_hs4.rds guardado. Filas: ", nrow(imp_mex_top_hs4))
}, error = function(e) message("✗  ERROR guardando imp_mex_top_hs4.rds: ", conditionMessage(e)))

# ==============================================================================
# SECCIÓN 7: TCAC Y SHARES POR PARTIDA — caps. 84, 85, 87, 90
# ==============================================================================
#
# Output: TCAC_y_shares_84858790.rds
#
# Una fila por partida (más fila "Resto" por capítulo).
# Valores: totales anualizados 2010, 2018, 2024, 2025.
# Tasas:   TCAC 2010–2018, TCAC 2018–2024, crecimiento anual 2024–2025.
# Shares:  % dentro del capítulo (denominador = total capítulo en ese año),
#          % del total de exportaciones México→EUA (denominador = todos los caps).
# Año de referencia para shares: 2025.
# Los porcentajes acumulados NO se calculan aquí; dependen del ordenamiento.
# ==============================================================================

message("\n=== Construyendo TCAC_y_shares_84858790 ===")

# — Paso 1: totales anuales por capítulo (denominadores de shares) -------------
# Fuente: imp_mex_sec_cap (Query 2). Si no está en memoria, cargar desde RDS.

if (!exists("imp_mex_sec_cap")) {
  imp_mex_sec_cap <- readRDS(here("RDS", "imp_mex_sec_cap.rds"))
  message("  imp_mex_sec_cap cargado desde RDS.")
}

años_ref <- c(2010L, 2018L, 2024L, 2025L)

total_cap_anual <- imp_mex_sec_cap |>
  filter(
    Capítulo %in% caps_seleccionados,
    year(fecha) %in% años_ref
  ) |>
  group_by(Capítulo, Cap_corto, Año = year(fecha)) |>
  summarise(Val_cap = sum(Val_mes, na.rm = TRUE), .groups = "drop")

# — Paso 2: total general México→EUA por año (denominador % del total) ---------
total_gral_anual <- imp_mex_sec_cap |>
  filter(year(fecha) %in% años_ref) |>
  group_by(Año = year(fecha)) |>
  summarise(Val_total_gral = sum(Val_mes, na.rm = TRUE), .groups = "drop")

# — Paso 3: totales anuales por partida (top partidas) -------------------------
partidas_anual <- imp_mex_top_hs4 |>
  filter(year(fecha) %in% años_ref) |>
  group_by(Capítulo, Cap_corto, Cod_partida, Part_corto, Part_desc_es,
           Año = year(fecha)) |>
  summarise(Val_partida = sum(Val_mes, na.rm = TRUE), .groups = "drop")

# — Paso 4: tabla ancha (una columna por año) ----------------------------------
partidas_ancha <- partidas_anual |>
  pivot_wider(
    names_from  = Año,
    values_from = Val_partida,
    names_prefix = "val_",
    values_fill  = 0
  )

# — Paso 5: construir filas de "Resto" -----------------------------------------
# Resto = total capítulo − suma de top partidas, por año

suma_top_por_cap <- partidas_anual |>
  group_by(Capítulo, Año) |>
  summarise(Val_top = sum(Val_partida, na.rm = TRUE), .groups = "drop")

resto_anual <- total_cap_anual |>
  left_join(suma_top_por_cap, by = c("Capítulo", "Año")) |>
  mutate(Val_resto = Val_cap - replace_na(Val_top, 0)) |>
  select(Capítulo, Cap_corto, Año, Val_resto)

resto_ancha <- resto_anual |>
  pivot_wider(
    names_from  = Año,
    values_from = Val_resto,
    names_prefix = "val_",
    values_fill  = 0
  ) |>
  mutate(
    Cod_partida  = "Resto",
    Part_corto   = "Resto",
    Part_desc_es = "Resto del capítulo"
  )

# — Paso 6: combinar partidas + resto ------------------------------------------
tabla_combinada <- bind_rows(partidas_ancha, resto_ancha) |>
  arrange(Capítulo, Cod_partida)

# — Paso 7: calcular TCAC y crecimiento anual ----------------------------------
# TCAC (k años): (val_final / val_inicial)^(1/k) − 1
# Crecimiento 2024–2025: (val_2025 − val_2024) / val_2024
# Precaución: si val inicial = 0, la TCAC es indefinida → NA

tabla_tasas <- tabla_combinada |>
  mutate(
    TCAC_1018 = if_else(val_2010 > 0, (val_2018 / val_2010)^(1/8) - 1, NA_real_),
    TCAC_1824 = if_else(val_2018 > 0, (val_2024 / val_2018)^(1/6) - 1, NA_real_),
    Crec_2425 = if_else(val_2024 > 0, (val_2025 - val_2024) / val_2024,  NA_real_)
  )

# — Paso 8: agregar shares 2025 ----------
total_cap_2025 <- total_cap_anual |>
  filter(Año == 2025) |>
  select(Capítulo, Val_cap_2025 = Val_cap)

total_gral_2025 <- total_gral_anual |>
  filter(Año == 2025) |>
  pull(Val_total_gral)

TCAC_y_shares_84858790 <- tabla_tasas |>
  left_join(total_cap_2025, by = "Capítulo") |>
  mutate(
    pct_cap   = val_2025 / Val_cap_2025,      # % dentro del capítulo en 2025
    pct_total = val_2025 / total_gral_2025     # % del total exportaciones en 2025
  ) |>
  select(
    Capítulo,
    Cap_corto,
    Cod_partida,
    Part_corto,
    Part_desc_es,
    val_2010,
    val_2018,
    val_2024,
    val_2025,
    TCAC_1018,
    TCAC_1824,
    Crec_2425,
    pct_cap,
    pct_total
  ) |>
  arrange(Capítulo, desc(val_2025))

# — Paso 9: verificación rápida ------------------------------------------------
cat("\n=== Verificación: shares deben sumar ~1 por capítulo ===\n")
TCAC_y_shares_84858790 |>
  group_by(Capítulo) |>
  summarise(
    suma_pct_cap   = sum(pct_cap,   na.rm = TRUE),
    suma_pct_total = sum(pct_total, na.rm = TRUE),
    .groups = "drop"
  ) |>
  print()

cat("\nFilas por capítulo:\n")
TCAC_y_shares_84858790 |> count(Capítulo, Cap_corto) |> print()

# — Paso 10: metadatos y guardado ----------------------------------------------
meta_TCAC_y_shares <- list(
  fuente          = "US Census Bureau — International Trade API (Query 3)",
  objetos_base    = c("imp_mex_top_hs4", "imp_mex_sec_cap"),
  fecha_creación  = Sys.time(),
  capítulos       = "84 (Maquinaria), 85 (Eléctrico), 87 (Automóviles), 90 (Óptica)",
  años_ref        = "2010, 2018, 2024, 2025 (suma de 12 meses en cada año)",
  tasas           = paste(
    "TCAC_1018: tasa anual compuesta 2010–2018 (8 años);",
    "TCAC_1824: tasa anual compuesta 2018–2024 (6 años);",
    "Crec_2425: crecimiento anual simple 2024–2025"
  ),
  shares          = paste(
    "pct_cap: participación de la partida dentro de su capítulo en 2025;",
    "pct_total: participación de la partida en el total México→EUA en 2025"
  ),
  resto           = paste(
    "Fila 'Resto' = total del capítulo (imp_mex_sec_cap) menos",
    "suma de top partidas (imp_mex_top_hs4), por año."
  ),
  acumulados      = "No incluidos — dependen del ordenamiento; calcular en el .qmd según necesidad",
  notas           = paste(
    "TCAC = NA cuando el valor inicial es 0.",
    "Valores en dólares corrientes.",
    "Ordenado por capítulo y val_2025 descendente."
  )
)

saveRDS(TCAC_y_shares_84858790, here("RDS", "TCAC_y_shares_84858790.rds"))
saveRDS(meta_TCAC_y_shares,     here("RDS", "meta_TCAC_y_shares.rds"))

message("✔  TCAC_y_shares_84858790.rds guardado. Filas: ",
        nrow(TCAC_y_shares_84858790))
