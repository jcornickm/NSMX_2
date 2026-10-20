# Top_Partidas_HS4.R   ####
# Identificación de las Partidas (HS4) más importantes y de mayor crecimiento
# en las importaciones de EUA provenientes de México.
# Fuente: imp_mex_hs4.rds (Query 3 — US Census Bureau, todos los capítulos)
# (Cobertura anual 2018/2024/2025 ya verificada — no se repite aquí)
#
# a. Top 50 Partidas por valor — suma 2024 + 2025 — depurado de categorías
#    sin interés para nearshoring (combustibles, muebles, bebidas, alimentos,
#    materias primas, partidas especiales). Lista completa (sin limitar a 20),
#    con traducción de descripciones y nombre corto en español. Este es el
#    objeto que se guarda como .rds.
# b. Top 50 Partidas por crecimiento — año completo 2018 vs. 2025 (objetivo
#    independiente; ya no se combina con (a) — ver nota más abajo).

pacman::p_load(tidyverse, here, scales, gt)

# Sección 1. Carga de datos   ####

imp_mex_hs4 <- readRDS(here::here("RDS", "imp_mex_hs4.rds"))

# Sección 2. Descripciones de partida y Top 50 por valor   ####
# Descripción más reciente disponible por partida (la descripción del API
# puede variar levemente entre años; se toma la del registro más reciente)
desc_partida <- imp_mex_hs4 |>
  filter(!is.na(Desc_api_partida)) |>
  group_by(Cod_partida) |>
  slice_max(fecha, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(Cod_partida, Cap_corto, Desc_api_partida)

# Top 50 Partidas por valor — suma 2024 + 2025

top_partidas_valor_50 <- imp_mex_hs4 |>
  filter(year(fecha) %in% c(2024, 2025)) |>
  group_by(Cod_partida) |>
  summarise(Val_2024_2025 = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(desc_partida, by = "Cod_partida") |>
  arrange(desc(Val_2024_2025)) |>
  slice_head(n = 50) |>
  mutate(ranking = row_number()) |>
  select(ranking, Cod_partida, Cap_corto, Desc_api_partida, Val_2024_2025)

cat("\n=== Top 50 Partidas por valor (suma 2024-2025), antes de depurar ===\n")
print(top_partidas_valor_50, n = 50)

# Depuración: categorías sin interés para nearshoring (combustibles, muebles,
# bebidas, alimentos/agro, materias primas, partidas especiales/EUA).
# Cap_corto es un factor ordenado con categorías limpias, por lo que se usa
# coincidencia exacta en lugar de búsqueda de texto parcial.

categorias_excluir <- c(
  "Combustibles", "Muebles", "Bebidas",                    # exclusiones originales
  "FrutasNueces", "Hortalizas", "PrepCereales", "Carnes",   # alimentos/agro
  "Plásticos", "Plástico", "Caucho",                        # materias primas/insumos
  "Joyería",                                                 # no manufactura de interés
  "EspecialEUA",                                              # "otras especiales" — partidas de reparación/reexportación, no industria real
  "OtrasEspeciales"
)

partidas_excluidas <- top_partidas_valor_50 |>
  filter(Cap_corto %in% categorias_excluir)

cat("\n=== Partidas excluidas del Top 50 ===\n")
if (nrow(partidas_excluidas) > 0) {
  print(partidas_excluidas |> select(ranking, Cod_partida, Cap_corto, Desc_api_partida))
} else {
  cat("(ninguna partida del Top 50 corresponde a estas categorías)\n")
}

top_partidas_valor_depurado <- top_partidas_valor_50 |>
  filter(!Cap_corto %in% categorias_excluir) |>
  mutate(ranking = row_number()) |>
  select(ranking, Cod_partida, Cap_corto, Desc_api_partida, Val_2024_2025)

cat("\n=== Top", nrow(top_partidas_valor_depurado),
    "Partidas por valor, depurado ===\n")
print(top_partidas_valor_depurado, n = nrow(top_partidas_valor_depurado))

# Sección 3. Traducción de descripciones y nombre corto en español   ####
# Diccionario manual: solo se completan los códigos verificados contra la
# descripción real en inglés (para no inventar texto). Los códigos pendientes
# quedan señalados al final — hay que compartir su Cod_partida + Desc_api_partida
# completos para terminar el diccionario.

traducciones_partidas <- tribble(
  ~Cod_partida, ~Desc_es, ~Nombre_corto_partida,
  "8471", "Máquinas automáticas para tratamiento o procesamiento de datos y sus unidades", "Computadoras",
  "8703", "Automóviles de turismo y demás vehículos automóviles concebidos para transporte de personas", "Automóviles",
  "8704", "Vehículos automóviles para transporte de mercancías", "Camiones",
  "8708", "Partes y accesorios de vehículos automóviles", "Autopartes",
  "8544", "Hilos, cables y demás conductores aislados para electricidad", "Cableado",
  "9018", "Instrumentos y aparatos de medicina, cirugía, odontología o veterinaria", "Médico",
  "8517", "Teléfonos, incluidos los celulares y aparatos de otras redes inalámbricas", "Telefonía",
  "8528", "Monitores, proyectores y aparatos receptores de televisión", "Televisores",
  "8537", "Cuadros, paneles y consolas para control o distribución eléctrica", "Tableros",
  "8701", "Tractores", "Tractores",
  "8415", "Máquinas y aparatos de aire acondicionado", "Climatización",
  "8418", "Refrigeradores, congeladores y demás equipo de refrigeración", "Refrigeración",
  "8504", "Transformadores eléctricos, convertidores estáticos y bobinas de reactancia", "Transformadores",
  "8543", "Máquinas y aparatos eléctricos con función propia, no clasificados en otra parte", "Misceláneos",
  "8536", "Aparatos para corte, protección o conexión de circuitos eléctricos", "Conmutación",
  "8421", "Centrifugadoras y aparatos para filtrar o depurar líquidos o gases", "Centrifugadoras",
  "8501", "Motores y generadores eléctricos", "Motores",
  "8407", "Motores de émbolo de encendido por chispa (motores de explosión)", "Combustión",
  "8409", "Partes para motores de émbolo (pistón) de encendido por chispa y de encendido por compresión", "Pistones",
  "8481", "Llaves, grifos, válvulas y artículos similares para tuberías, calderas, tanques, cubas o similares; sus partes", "Válvulas",
  "8414", "Bombas de aire o vacío, compresores de aire o gas, ventiladores; campanas aspirantes con ventilador incorporado; gabinetes de seguridad biológica herméticos a gases; sus partes", "Compresores",
  "8512", "Aparatos eléctricos de alumbrado o señalización, limpiaparabrisas, eliminadores de escarcha y vaho, para velocípedos o vehículos automóviles; sus partes", "Iluminación",
  "8413", "Bombas para líquidos, incluso con dispositivo medidor; elevadores de líquidos; sus partes", "Bombas",
  "8716", "Remolques y semirremolques; los demás vehículos no propulsados mecánicamente; sus partes", "Remolques",
  "8473", "Partes y accesorios para máquinas de escribir y otras máquinas de oficina de las partidas 8469 a 8472", "Oficina",
  "8516", "Calentadores eléctricos de agua y calentadores de inmersión; aparatos eléctricos para calefacción de espacios o del suelo; aparatos electrotérmicos para el cuidado del cabello, secadores de manos, planchas, etc.; sus partes", "Calefacción",
  "8411", "Turborreactores, turbopropulsores y demás turbinas de gas, y sus partes", "Turbinas",
  "8408", "Motores de émbolo (pistón) de encendido por compresión (motores diésel o semidiésel)", "Diésel",
  "8431", "Partes de las máquinas de las partidas 8425 a 8430: grúas, carretillas elevadoras, transportadores, topadoras autopropulsadas, niveladoras, quitanieves, etc.", "Construcción",
  "8507", "Acumuladores eléctricos, incluidos sus separadores; sus partes", "Baterías"
)

top_partidas_valor_depurado <- top_partidas_valor_depurado |>
  left_join(traducciones_partidas, by = "Cod_partida")

partidas_sin_traducir <- top_partidas_valor_depurado |>
  filter(is.na(Desc_es))

cat("\n=== Partidas SIN traducir (compartir Cod_partida + Desc_api_partida completos) ===\n")
if (nrow(partidas_sin_traducir) > 0) {
  cat(paste0(partidas_sin_traducir$Cod_partida, " (", partidas_sin_traducir$Cap_corto, ") — ",
             partidas_sin_traducir$Desc_api_partida),
      sep = "\n")
} else {
  cat("(todas las partidas tienen traducción)\n")
}

# Top 20 (para tabla de presentación; el objeto guardado es la lista completa)
top20_valor <- top_partidas_valor_depurado |>
  slice_head(n = 20)

cat("\n=== Top 20 Partidas por valor (depurado) ===\n")
print(top20_valor, n = 20)

# Sección 4. Top 50 Partidas por crecimiento — 2018 vs. 2025   ####
# Objetivo independiente del capítulo; no se combina con la lista de valor
# (las partidas de alto crecimiento tienen bases 2018 muy pequeñas y caen en
# categorías distintas a las del Top de valor — ver diagnóstico previo).

valor_anual <- imp_mex_hs4 |>
  filter(year(fecha) %in% c(2018, 2025)) |>
  mutate(año = year(fecha)) |>
  group_by(Cod_partida, año) |>
  summarise(Val_año = sum(Val_mes, na.rm = TRUE), .groups = "drop")

crecimiento_partidas <- valor_anual |>
  pivot_wider(names_from = año, values_from = Val_año, names_prefix = "val_") |>
  filter(!is.na(val_2018), !is.na(val_2025), val_2018 > 0) |>
  mutate(
    crecimiento_abs = val_2025 - val_2018,
    crecimiento_pct = (val_2025 / val_2018 - 1) * 100,
    tcac            = ((val_2025 / val_2018)^(1 / 7) - 1) * 100  # 2018→2025 = 7 años
  ) |>
  left_join(desc_partida, by = "Cod_partida")

top_partidas_crecimiento_50 <- crecimiento_partidas |>
  arrange(desc(crecimiento_pct)) |>
  slice_head(n = 50) |>
  mutate(ranking = row_number()) |>
  select(ranking, Cod_partida, Cap_corto, Desc_api_partida,
         val_2018, val_2025, crecimiento_abs, crecimiento_pct, tcac)

cat("\n=== Top 50 Partidas por crecimiento (2018 → 2025) ===\n")
print(top_partidas_crecimiento_50, n = 50)

# Sección 5. Tablas gt   ####

tabla_valor <- top20_valor |>
  gt() |>
  tab_header(
    title    = "Las 20 Partidas (HS4) más importantes en las importaciones de EUA desde México",
    subtitle = "Suma de valor mensual, 2024–2025 (USD corrientes) — depurado de categorías sin interés para NS"
  ) |>
  fmt_currency(columns = Val_2024_2025, currency = "USD", decimals = 0) |>
  cols_label(
    ranking               = "#",
    Cod_partida           = "Partida",
    Cap_corto             = "Capítulo",
    Desc_api_partida      = "Descripción (EN)",
    Desc_es               = "Descripción",
    Nombre_corto_partida  = "Nombre corto",
    Val_2024_2025         = "Valor 2024–2025"
  ) |>
  tab_source_note("Elaboración propia con base en U.S. Census Bureau, International Trade API.") |>
  opt_row_striping() |>
  tab_options(
    heading.background.color  = "white",
    table.border.top.style    = "hidden",
    table.border.bottom.style = "hidden",
    table_body.hlines.color   = "white"
  ) |>
  opt_table_font(font = google_font("IBM Plex Sans"))

tabla_crecimiento <- top_partidas_crecimiento_50 |>
  gt() |>
  tab_header(
    title    = "Las 50 Partidas (HS4) con mayor crecimiento en las importaciones de EUA desde México",
    subtitle = "Comparación de valor anual, 2018 vs. 2025 (años completos)"
  ) |>
  fmt_currency(columns = c(val_2018, val_2025, crecimiento_abs),
               currency = "USD", decimals = 0) |>
  fmt_number(columns = c(crecimiento_pct, tcac), decimals = 1) |>
  cols_label(
    ranking          = "#",
    Cod_partida      = "Partida",
    Cap_corto        = "Capítulo",
    Desc_api_partida = "Descripción",
    val_2018         = "Valor 2018",
    val_2025         = "Valor 2025",
    crecimiento_abs  = "Δ Absoluto",
    crecimiento_pct  = "Crecimiento %",
    tcac             = "TCAC 2018–25 %"
  ) |>
  tab_source_note("Elaboración propia con base en U.S. Census Bureau, International Trade API.") |>
  opt_row_striping() |>
  tab_options(
    heading.background.color  = "white",
    table.border.top.style    = "hidden",
    table.border.bottom.style = "hidden",
    table_body.hlines.color   = "white"
  ) |>
  opt_table_font(font = google_font("IBM Plex Sans"))

tabla_valor
tabla_crecimiento

# Sección 6. Guardado   ####
# Se guarda la lista completa (sin limitar a 20) de partidas que quedan tras
# la depuración de categorías, ya con traducción y nombre corto en español.

tryCatch({
  saveRDS(top_partidas_valor_depurado, here("RDS", "partidas_valor_depurado.rds"))
  message("✔  partidas_valor_depurado.rds guardado (", nrow(top_partidas_valor_depurado), " partidas).")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))

# tryCatch({
#   saveRDS(top_partidas_crecimiento_50, here("RDS", "top50_partidas_crecimiento.rds"))
#   message("✔  top50_partidas_crecimiento.rds guardado.")
# }, error = function(e) message("✗  ERROR: ", conditionMessage(e)))