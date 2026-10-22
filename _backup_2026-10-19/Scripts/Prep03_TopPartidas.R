# Prep03_TopPartidas.R   ####
# PENDIENTE: este script debe reescribirse. (1) Se descartó el Top 50 por
# crecimiento (sección 4); (2) los años de referencia están hard-coded
# (2024–2025 y 2018) y el periodo de identificación de las partidas principales
# sigue por decidir (ver Scripts/Explora_Top_Partidas_Periodos.R).
# Identificación de las Partidas (HS4) más importantes y de mayor crecimiento
# en las importaciones de EUA provenientes de México.
# Fuente: imp_mex_hs4.rds (Prep02, derivado de Query02 — US Census Bureau, todos los capítulos)
# (Cobertura anual 2018/2024/2025 ya verificada — no se repite aquí)
#
# a. Top 50 Partidas por valor — suma 2024 + 2025 — depurado de categorías
#    sin interés para nearshoring (combustibles, muebles, bebidas, alimentos,
#    materias primas, partidas especiales). Lista completa (sin limitar a 20),
#    con nombre corto en español (del diccionario del SA). Este es el
#    objeto que se guarda como .rds.
# b. Top 50 Partidas por crecimiento — año completo 2018 vs. 2025 (objetivo
#    independiente; ya no se combina con (a) — ver nota más abajo).

pacman::p_load(tidyverse, here, scales, flextable)
source(here("Scripts", "funciones.R"))   # hs_etiquetas_partida() — nombres del SA desde RDS/hs_dictionary.rds

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
  select(Cod_partida, Capítulo, Cap_corto, Desc_api_partida)

# Top 50 Partidas por valor — suma 2024 + 2025

top_partidas_valor_50 <- imp_mex_hs4 |>
  filter(year(fecha) %in% c(2024, 2025)) |>
  group_by(Cod_partida) |>
  summarise(Val_2024_2025 = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(desc_partida, by = "Cod_partida") |>
  arrange(desc(Val_2024_2025)) |>
  slice_head(n = 50) |>
  mutate(ranking = row_number()) |>
  select(ranking, Cod_partida, Capítulo, Cap_corto, Desc_api_partida, Val_2024_2025)

cat("\n=== Top 50 Partidas por valor (suma 2024-2025), antes de depurar ===\n")
print(top_partidas_valor_50, n = 50)

# Depuración: categorías sin interés para nearshoring (combustibles, muebles,
# bebidas, alimentos/agro, materias primas, partidas especiales/EUA).
# Se excluye por NÚMERO de capítulo (no por nombre corto), así los nombres
# pueden editarse sin romper la depuración.

capitulos_excluir <- c(
  27, 94, 22,          # Combustibles, Muebles, Bebidas (exclusiones originales)
  8, 7, 19, 2,         # alimentos/agro: Frutas y nueces, Hortalizas, Prep. de cereales, Carnes
  39, 40,              # materias primas/insumos: Plásticos, Caucho
  71,                  # Joyería: no manufactura de interés
  98, 99               # Especial EUA / Otras especiales: reparación/reexportación, no industria real
)

partidas_excluidas <- top_partidas_valor_50 |>
  filter(Capítulo %in% capitulos_excluir)

cat("\n=== Partidas excluidas del Top 50 ===\n")
if (nrow(partidas_excluidas) > 0) {
  print(partidas_excluidas |> select(ranking, Cod_partida, Capítulo, Cap_corto, Desc_api_partida))
} else {
  cat("(ninguna partida del Top 50 corresponde a estas categorías)\n")
}

top_partidas_valor_depurado <- top_partidas_valor_50 |>
  filter(!Capítulo %in% capitulos_excluir) |>
  mutate(ranking = row_number()) |>
  select(ranking, Cod_partida, Capítulo, Cap_corto, Desc_api_partida, Val_2024_2025)

cat("\n=== Top", nrow(top_partidas_valor_depurado),
    "Partidas por valor, depurado ===\n")
print(top_partidas_valor_depurado, n = nrow(top_partidas_valor_depurado))

# Sección 3. Nombre corto de cada partida (diccionario del SA)   ####
# Los nombres salen de RDS/hs_dictionary.rds (Excel/hs_nombres_cortos.csv).
# Si una partida del Top no tiene nombre_corto, queda NA y se reporta abajo:
# agregarla al CSV y correr Scripts/build_hs_dictionary.R.

top_partidas_valor_depurado <- top_partidas_valor_depurado |>
  hs_etiquetas_partida(estricto = FALSE) |>
  rename(Nombre_corto_partida = Part_corto,
         Nombre_tabla_partida = Part_tabla)

partidas_sin_nombre <- top_partidas_valor_depurado |>
  filter(is.na(Nombre_corto_partida))

cat("\n=== Partidas SIN nombre_corto (agregar a Excel/hs_nombres_cortos.csv) ===\n")
if (nrow(partidas_sin_nombre) > 0) {
  cat(paste0(partidas_sin_nombre$Cod_partida, " (", partidas_sin_nombre$Cap_corto, ") — ",
             partidas_sin_nombre$Desc_api_partida),
      sep = "\n")
} else {
  cat("(todas las partidas tienen nombre corto)\n")
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
  select(ranking, Cod_partida, Capítulo, Cap_corto, Desc_api_partida,
         val_2018, val_2025, crecimiento_abs, crecimiento_pct, tcac)

cat("\n=== Top 50 Partidas por crecimiento (2018 → 2025) ===\n")
print(top_partidas_crecimiento_50, n = 50)

# Sección 5. Tablas flextable   ####
# (flextable, no gt: renderiza bien a Word). Se muestra el número de Capítulo
# junto al nombre. Solo para revisión; no se guardan.

tabla_valor <- top20_valor |>
  mutate(Capítulo = paste0(Capítulo, " – ", Cap_corto)) |>
  select(ranking, Cod_partida, Nombre_tabla_partida, Capítulo, Val_2024_2025) |>
  flextable() |>
  set_header_labels(ranking = "#", Cod_partida = "Partida",
                    Nombre_tabla_partida = "Nombre", Capítulo = "Capítulo",
                    Val_2024_2025 = "Valor 2024–2025 (USD)") |>
  colformat_num(j = "Val_2024_2025", big.mark = ",", digits = 0) |>
  add_header_lines("Las 20 Partidas (HS4) más importantes en las importaciones de EUA desde México, 2024–2025") |>
  add_footer_lines("Elaboración propia con base en U.S. Census Bureau, International Trade API. Depurado de categorías sin interés para NS.") |>
  theme_booktabs() |>
  autofit()

tabla_crecimiento <- top_partidas_crecimiento_50 |>
  mutate(Capítulo = paste0(Capítulo, " – ", Cap_corto)) |>
  select(ranking, Cod_partida, Capítulo, Desc_api_partida,
         val_2018, val_2025, crecimiento_abs, crecimiento_pct, tcac) |>
  flextable() |>
  set_header_labels(ranking = "#", Cod_partida = "Partida", Capítulo = "Capítulo",
                    Desc_api_partida = "Descripción (API, EN)",
                    val_2018 = "Valor 2018", val_2025 = "Valor 2025",
                    crecimiento_abs = "Δ Absoluto", crecimiento_pct = "Crecimiento %",
                    tcac = "TCAC 2018–25 %") |>
  colformat_num(j = c("val_2018", "val_2025", "crecimiento_abs"), big.mark = ",", digits = 0) |>
  colformat_num(j = c("crecimiento_pct", "tcac"), digits = 1) |>
  add_header_lines("Las 50 Partidas (HS4) con mayor crecimiento en las importaciones de EUA desde México, 2018 vs. 2025") |>
  add_footer_lines("Elaboración propia con base en U.S. Census Bureau, International Trade API.") |>
  theme_booktabs() |>
  autofit()

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