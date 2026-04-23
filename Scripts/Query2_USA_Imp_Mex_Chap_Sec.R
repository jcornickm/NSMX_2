# imp_mex_sec_cap.R
# Importaciones de EUA provenientes de México — por Sección y Capítulo del SA
# Fuente: US Census Bureau — International Trade API
# Período: enero 2010 – diciembre 2025
# =============================================================================
# NOTAS SOBRE EL API (leer antes de ejecutar)
# -----------------------------------------------------------------------------
# • El API devuelve una columna `time` con formato 'AAAA-MM'. No devuelve
#   columnas separadas YEAR y MONTH. Se extraen con substr().
# • Se itera año por año para evitar timeouts en rangos largos.
# • CTY_CODE = "2010" corresponde a México.
# • Datos mensuales disponibles desde enero 2010 en este endpoint.
# • Los totales (por Sección, país, año) se calculan bajo demanda con
#   group_by() |> summarise(). Este archivo almacena un registro por
#   Capítulo por mes; no incluye filas de totales agregados.
# • Las variables de texto descriptivo (nombres de Sección y Capítulo)
#   se almacenan como factores ordenados por su número/roman numeral.
# =============================================================================

pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse,
               here, janitor, censusapi, scales)

# — Clave del API -------------------------------------------------------------
api_key <- Sys.getenv("CENSUS_API_KEY")
stopifnot("Clave del Census API no encontrada — definir CENSUS_API_KEY en .Renviron" =
            nchar(api_key) > 0)

# — Años a descargar ----------------------------------------------------------
años <- 2010:2025

# — Tabla de Secciones del SA -------------------------------------------------
# Una fila por Capítulo para facilitar el join.
# Sección_corto:     etiqueta de una palabra para gráficas y tablas.
# Sección_desc_es:   nombre en español (elaboración propia).
# Sección_desc_orig: nombre oficial del SA en inglés (referencia).

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

# — Nivel de los factores: orden natural de las Secciones del SA --------------
niveles_sección <- c("I","II","III","IV","V","VI","VII","VIII","IX","X",
                     "XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX","XXI")

# — Nombres en español de los Capítulos del SA --------------------------------
# Cap_corto:   etiqueta de una palabra para gráficas y tablas.
# Cap_desc_es: descripción en español (elaboración propia).

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
  10, "Cereales",          "Cereales",
  11, "Molinería",         "Productos de molinería",
  12, "Semillas",          "Semillas y frutos oleaginosos",
  13, "GomasResinas",      "Gomas, resinas y demás jugos vegetales",
  14, "MatVegetal",        "Materias trenzables y vegetales",
  15, "GrasasAceites",     "Grasas y aceites animales o vegetales",
  16, "PrepCarnes",        "Preparaciones de carne o pescado",
  17, "Azúcares",          "Azúcares y artículos de confitería",
  18, "Cacao",             "Cacao y sus preparaciones",
  19, "PrepCereales",      "Preparaciones a base de cereales",
  20, "PrepHortalizas",    "Preparaciones de hortalizas y frutas",
  21, "PrepAlim",          "Preparaciones alimenticias diversas",
  22, "Bebidas",           "Bebidas, líquidos alcohólicos y vinagre",
  23, "ResiduosAlim",      "Residuos de las industrias alimentarias",
  24, "Tabaco",            "Tabaco y sucedáneos del tabaco",
  25, "Sal",               "Sal, azufre, tierras y piedras",
  26, "Minerales",         "Minerales metalíferos, escorias y cenizas",
  27, "Combustibles",      "Combustibles y aceites minerales",
  28, "QuímInorg",         "Productos químicos inorgánicos",
  29, "QuímOrg",           "Productos químicos orgánicos",
  30, "Farmacéuticos",     "Productos farmacéuticos",
  31, "Fertilizantes",     "Fertilizantes",
  32, "Tintes",            "Extractos curtientes y tintóreos",
  33, "Perfumes",          "Aceites esenciales y perfumería",
  34, "Jabones",           "Jabones y preparaciones de limpieza",
  35, "MatAlbuminoideas",  "Materias albuminoideas y almidones",
  36, "Explosivos",        "Explosivos y artículos de pirotecnia",
  37, "FotoCine",          "Productos fotográficos o cinematográficos",
  38, "QuímDiversos",      "Productos químicos diversos",
  39, "Plásticos",         "Plásticos y sus manufacturas",
  40, "Caucho",            "Caucho y sus manufacturas",
  41, "PielesCuero",       "Pieles y cueros",
  42, "ArtCuero",          "Manufacturas de cuero",
  43, "Peletería",         "Peletería y confecciones de peletería",
  44, "Madera",            "Madera y sus manufacturas",
  45, "Corcho",            "Corcho y sus manufacturas",
  46, "Cestería",          "Manufacturas de espartería o cestería",
  47, "PastaPapel",        "Pasta de madera y demás materias fibrosas",
  48, "Papel",             "Papel, cartón y sus manufacturas",
  49, "ArtEditorial",      "Productos editoriales e impresos",
  50, "Seda",              "Seda",
  51, "LanaFibras",        "Lana y pelo fino u ordinario",
  52, "Algodón",           "Algodón",
  53, "FibrasVeg",         "Fibras vegetales textiles",
  54, "FilasSint",         "Filamentos sintéticos o artificiales",
  55, "FibrasSint",        "Fibras discontinuas sintéticas o artificiales",
  56, "Guatas",            "Guatas, fieltros y telas sin tejer",
  57, "Alfombras",         "Alfombras y revestimientos textiles para el suelo",
  58, "TejidosEsp",        "Tejidos especiales",
  59, "TejidosImp",        "Telas impregnadas y recubiertas",
  60, "TejidosPunto",      "Tejidos de punto",
  61, "PrendaPunto",       "Prendas de vestir de punto",
  62, "PrendaNoTejida",    "Prendas de vestir (excepto las de punto)",
  63, "ArtTextilHogar",    "Artículos textiles confeccionados para el hogar",
  64, "Calzado",           "Calzado",
  65, "Sombreros",         "Sombreros y artículos de tocado",
  66, "Paraguas",          "Paraguas y sombrillas",
  67, "PlumasFlores",      "Plumas preparadas y flores artificiales",
  68, "PiedraCem",         "Manufacturas de piedra, yeso y cemento",
  69, "Cerámica",          "Productos cerámicos",
  70, "Vidrio",            "Vidrio y sus manufacturas",
  71, "Joyería",           "Perlas, piedras y metales preciosos",
  72, "HierroAcero",       "Fundición, hierro y acero",
  73, "ArtHierroAcero",    "Manufacturas de fundición, hierro o acero",
  74, "Cobre",             "Cobre y sus manufacturas",
  75, "Níquel",            "Níquel y sus manufacturas",
  76, "Aluminio",          "Aluminio y sus manufacturas",
  78, "Plomo",             "Plomo y sus manufacturas",
  79, "Zinc",              "Zinc y sus manufacturas",
  80, "Estaño",            "Estaño y sus manufacturas",
  81, "OtrosMetales",      "Otros metales comunes y sus manufacturas",
  82, "HerramMetal",       "Herramientas y útiles de metal común",
  83, "ArtMetal",          "Manufacturas diversas de metal común",
  84, "Maquinaria",        "Reactores nucleares, calderas y maquinaria",
  85, "Eléctrico",         "Máquinas y aparatos eléctricos",
  86, "Ferroviario",       "Vehículos y material para vías férreas",
  87, "Automóviles",       "Automóviles y vehículos terrestres",
  88, "Aeronaves",         "Aeronaves y artefactos espaciales",
  89, "Barcos",            "Barcos y embarcaciones",
  90, "Óptica",            "Instrumentos de óptica, fotografía y medicina",
  91, "Relojería",         "Relojería",
  92, "InstMúsica",        "Instrumentos musicales",
  93, "Armas",             "Armas y municiones",
  94, "Muebles",           "Muebles y artículos de alumbrado",
  95, "Juguetes",          "Juguetes y artículos deportivos",
  96, "ManufDiversas",     "Manufacturas diversas",
  97, "Arte",              "Objetos de arte, de colección o de antigüedad",
  98, "EspecialEUA",       "Provisiones especiales de clasificación EUA",
  99, "OtrasEspeciales",   "Otras provisiones especiales"
)

# — Función de descarga (un año a la vez) -------------------------------------
descargar_mexico_hs2 <- function(año) {
  message("  Descargando año: ", año)
  tryCatch({
    getCensus(
      name     = "timeseries/intltrade/imports/hs",
      vars     = c("I_COMMODITY",
                   "I_COMMODITY_LDESC",
                   "GEN_VAL_MO",
                   "GEN_VAL_YR"),
      time     = paste0("from ", año, " to ", año),
      key      = api_key,
      CTY_CODE = "2010",
      COMM_LVL = "HS2"
    )
  }, error = function(e) {
    message("  ERROR en año ", año, ": ", conditionMessage(e))
    NULL
  })
}

# — Descarga ------------------------------------------------------------------
message("\n=== Descargando: importaciones de EUA desde México por Capítulo SA ===")
raw_list <- map(años, descargar_mexico_hs2)

# — Limpieza y construcción del tibble final ----------------------------------
imp_mex_sec_cap <- raw_list |>
  compact() |>
  bind_rows() |>
  as_tibble() |>
  mutate(
    fecha    = as.Date(paste0(time, "-01")),
    capitulo = as.integer(I_COMMODITY),
    val_mes  = as.numeric(GEN_VAL_MO),
    val_acum = as.numeric(GEN_VAL_YR)
  ) |>
  left_join(secciones_sa, by = c("capitulo" = "Capítulo")) |>
  left_join(capitulos_es, by = c("capitulo" = "Capítulo")) |>
  mutate(
    # Factores ordenados por número/numeral romano natural del SA
    Sección          = factor(Sección,       levels = niveles_sección, ordered = TRUE),
    Sección_corto    = factor(Sección_corto, levels = secciones_sa |>
                                distinct(Sección, Sección_corto) |>
                                arrange(factor(Sección, levels = niveles_sección)) |>
                                pull(Sección_corto),
                              ordered = TRUE),
    Sección_desc_es  = factor(Sección_desc_es, levels = secciones_sa |>
                                distinct(Sección, Sección_desc_es) |>
                                arrange(factor(Sección, levels = niveles_sección)) |>
                                pull(Sección_desc_es),
                              ordered = TRUE),
    Cap_corto        = factor(Cap_corto,   levels = capitulos_es |>
                                arrange(Capítulo) |>
                                pull(Cap_corto),
                              ordered = TRUE),
    Cap_desc_es      = factor(Cap_desc_es, levels = capitulos_es |>
                                arrange(Capítulo) |>
                                pull(Cap_desc_es),
                              ordered = TRUE)
  ) |>
  select(
    fecha,
    Sección,
    Sección_corto,
    Sección_desc_es,
    Sección_desc_orig,
    Capítulo          = capitulo,
    Cap_corto,
    Cap_desc_es,
    Cap_desc_api      = I_COMMODITY_LDESC,
    Val_mes           = val_mes,
    Val_acum          = val_acum
  ) |>
  arrange(fecha, Capítulo)

# — Seasonal adjustment -------------------------------------------------------
imp_mex_sec_cap <- imp_mex_sec_cap |>
  group_by(Capítulo) |>
  arrange(fecha, .by_group = TRUE) |>
  mutate(
    Val_mes_sa = tryCatch(
      sa_adj(Val_mes, fecha),
      error = function(e) {
        message("  SA failed for Capítulo ", first(Capítulo), " — returning unadjusted values. Reason: ", conditionMessage(e))
        Val_mes
      }
    )
  ) |>
  ungroup()

# — Verificación de NAs en columnas clave ------------------------------------
nas_sección  <- sum(is.na(imp_mex_sec_cap$Sección))
nas_cap_desc <- sum(is.na(imp_mex_sec_cap$Cap_desc_es))

cat("\nNAs en 'Sección':     ", nas_sección,  "\n")
cat("NAs en 'Cap_desc_es':", nas_cap_desc, "\n")

if (nas_sección > 0 | nas_cap_desc > 0) {
  message("  ⚠️  Capítulos sin correspondencia en las tablas de referencia:")
  imp_mex_sec_cap |>
    filter(is.na(Sección) | is.na(Cap_desc_es)) |>
    distinct(Capítulo, Cap_desc_api) |>
    print()
}

# — Verificación de consistencia: suma de Capítulos vs. imp_por_pais ----------
if (!exists("imp_por_pais")) {
  rds_path <- here("RDS", "imp_por_pais.rds")
  if (file.exists(rds_path)) {
    imp_por_pais <- readRDS(rds_path)
    message("  imp_por_pais cargado desde RDS.")
  } else {
    message("  ⚠️  imp_por_pais no encontrado. Se omite la verificación de consistencia.")
    imp_por_pais <- NULL
  }
}

if (!is.null(imp_por_pais)) {
  
  fechas_comunes <- intersect(
    unique(imp_mex_sec_cap$fecha),
    unique(imp_por_pais$fecha)
  )
  
  total_caps <- imp_mex_sec_cap |>
    filter(fecha %in% fechas_comunes) |>
    group_by(fecha) |>
    summarise(suma_caps = sum(Val_mes, na.rm = TRUE), .groups = "drop")
  
  total_q1 <- imp_por_pais |>
    filter(fecha %in% fechas_comunes, iso3 == "MEX") |>
    select(fecha, val_q1 = Imp_mes)
  
  verificación <- left_join(total_caps, total_q1, by = "fecha") |>
    mutate(diferencia = suma_caps - val_q1,
           dif_pct    = diferencia / val_q1 * 100)
  
  cat("\n=== Verificación de consistencia: suma de Capítulos vs. imp_por_pais ===\n")
  cat("Fechas comparadas:       ", length(fechas_comunes), "\n")
  cat("Diferencia máxima (USD): ", comma(max(abs(verificación$diferencia), na.rm = TRUE)), "\n")
  cat("Diferencia máxima (%):   ", round(max(abs(verificación$dif_pct),    na.rm = TRUE), 4), "\n")
  
  if (max(abs(verificación$diferencia), na.rm = TRUE) == 0) {
    cat("✔  Las sumas coinciden exactamente con imp_por_pais en todos los meses.\n")
  } else {
    cat("⚠️  Existen discrepancias. Revisar el objeto 'verificación' para el detalle.\n")
    verificación |>
      filter(abs(diferencia) > 0) |>
      print()
  }
}

# — Metadatos -----------------------------------------------------------------
meta_imp_mex_sec_cap <- list(
  fuente         = "US Census Bureau — International Trade API",
  endpoint       = "timeseries/intltrade/imports/hs",
  url            = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga = Sys.time(),
  país_origen    = "México (CTY_CODE = 2010)",
  nivel          = "Capítulo SA (2 dígitos); Sección derivada por agrupación",
  período        = paste(range(imp_mex_sec_cap$fecha), collapse = " – "),
  notas          = "Val_mes y Val_acum en dólares corrientes.
                    Sección_desc_orig: nombre oficial del SA en inglés.
                    Sección_desc_es y Cap_desc_es: nombres en español (elaboración propia).
                    Cap_desc_api: nombre devuelto por el API en inglés (referencia).
                    Capítulos 98-99 incluidos (provisiones especiales EUA).
                    Variables descriptivas de texto almacenadas como factores ordenados
                    según el orden natural del SA (Secciones I–XXI; Capítulos 1–99).
                    No incluye filas de totales agregados; calcular con group_by()."
)

# — Guardar -------------------------------------------------------------------
saveRDS(imp_mex_sec_cap,      here("RDS", "imp_mex_sec_cap.rds"))
saveRDS(meta_imp_mex_sec_cap, here("RDS", "meta_imp_mex_sec_cap.rds"))

cat("\nListo. Filas:", nrow(imp_mex_sec_cap),
    "\nGuardado en: RDS/imp_mex_sec_cap.rds\n")