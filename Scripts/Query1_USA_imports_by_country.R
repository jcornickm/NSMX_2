# ============================================================================
# Query1_revised.R
# US imports: total + by country of origin, 2010–2025
# Two-pass approach: total first, then by country, then join
# ============================================================================

pacman::p_load(httr, jsonlite, forcats, zoo, tidyverse, here, janitor, censusapi)

api_key <- Sys.getenv("CENSUS_API_KEY")
años <- 2010:2025

# — PASO 1: Total de importaciones de EUA, sin desagregación por país ----------
message("=== Paso 1: Descargando totales ===")

fetch_total <- function(año) {
  message("  Año: ", año)
  tryCatch({
    getCensus(
      name = "timeseries/intltrade/imports/hs",
      vars = c("GEN_VAL_MO", "GEN_VAL_YR"),
      time = paste0("from ", año, " to ", año),
      key  = api_key
    )
  }, error = function(e) {
    message("  ERROR: ", conditionMessage(e)); NULL
  })
}

imp_total <- map(años, fetch_total) |>
  compact() |>
  bind_rows() |>
  as_tibble() |>
  mutate(
    fecha   = as.Date(paste0(time, "-01")),
    Imp_total = as.numeric(GEN_VAL_MO)
  ) |>
  select(fecha, Imp_total)

# — PASO 2: Importaciones por país de origen -----------------------------------
message("=== Paso 2: Descargando por país ===")

fetch_by_country <- function(año) {
  message("  Año: ", año)
  tryCatch({
    getCensus(
      name = "timeseries/intltrade/imports/hs",
      vars = c("CTY_CODE", "CTY_NAME", "GEN_VAL_MO"),
      time = paste0("from ", año, " to ", año),
      key  = api_key
    )
  }, error = function(e) {
    message("  ERROR: ", conditionMessage(e)); NULL
  })
}

imp_paises <- map(años, fetch_by_country) |>
  compact() |>
  bind_rows() |>
  as_tibble() |>
  mutate(
    fecha   = as.Date(paste0(time, "-01")),
    Imp_mes = as.numeric(GEN_VAL_MO)
  ) |>
  filter(as.integer(CTY_CODE) >= 1000) |>
  select(fecha, CTY_CODE, CTY_NAME, Imp_mes)

# — Verificación: ¿suma de países ≈ total? ------------------------------------
# Si hay una diferencia grande, hay más códigos de agregados que filtrar
verificacion <- imp_paises |>
  group_by(fecha) |>
  summarise(suma_paises = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(imp_total, by = "fecha") |>
  mutate(
    diferencia = Imp_total - suma_paises,
    dif_pct    = diferencia / Imp_total * 100
  )

cat("\nDiferencia promedio (%):", round(mean(abs(verificacion$dif_pct), na.rm = TRUE), 2), "\n")
cat("Diferencia máxima (%):", round(max(abs(verificacion$dif_pct), na.rm = TRUE), 2), "\n")

# — PASO 3: Identificar Top 20 por valor 2024-2025 combinado ------------------
top20_codigos <- imp_paises |>
  filter(fecha >= "2024-01-01") |>
  group_by(CTY_CODE, CTY_NAME) |>
  summarise(total_24_25 = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  slice_max(total_24_25, n = 20) |>
  arrange(desc(total_24_25))

# — Revisar antes de continuar ------------------------------------------------
print(top20_codigos, n = 20)

# — Tabla de nombres en español -----------------------------------------------
top20_nombres <- tibble(
  CTY_CODE = c("2010","1220","5700","5520","5830","4280","5880",
               "5800","4190","5330","4419","5490","4759","4120",
               "4279","5570","3510","5590","4210","5600"),
  País = c("México","Canadá","China","Vietnam","Taiwán","Alemania","Japón",
           "Corea_S","Irlanda","India","Suiza","Tailandia","Italia","R_Unido",
           "Francia","Malasia","Brasil","Singapur","P_Bajos","Indonesia"),
  rank = 1:20
)

# — PASO 4: Construir imp_por_pais_all ----------------------------------------
imp_por_pais_all <- imp_paises |>
  left_join(top20_nombres, by = "CTY_CODE") |>
  left_join(imp_total, by = "fecha")

# — PASO 5: Construir imp_por_pais (Top20 + Resto + Total) --------------------

# Top 20
top20 <- imp_por_pais_all |>
  filter(CTY_CODE %in% top20_nombres$CTY_CODE) |>
  mutate(grupo = "Top20") |>
  select(fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo)

# Resto = Total - suma Top20 por mes
resto <- top20 |>
  group_by(fecha) |>
  summarise(suma_top20 = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(imp_total, by = "fecha") |>
  mutate(
    CTY_CODE  = "REST",
    País      = "Resto",
    rank      = 21L,
    Imp_mes   = Imp_total - suma_top20,
    grupo     = "Resto"
  ) |>
  select(fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo)

# Total
total <- imp_total |>
  mutate(
    CTY_CODE = "TOT",
    País     = "Total",
    rank     = 0L,
    Imp_mes  = Imp_total,
    grupo    = "Total"
  ) |>
  select(fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo)

# Unir
imp_por_pais <- bind_rows(total, top20, resto) |>
  arrange(fecha, rank)

# — Verificación rápida -------------------------------------------------------
# Top20 + Resto debe sumar exactamente al Total
verificacion2 <- imp_por_pais |>
  filter(grupo != "Total") |>
  group_by(fecha) |>
  summarise(suma = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(imp_total, by = "fecha") |>
  mutate(dif = Imp_total - suma)

cat("Diferencia máxima Top20+Resto vs Total:", max(abs(verificacion2$dif)), "\n")

# — Metadatos -----------------------------------------------------------------
meta_imp_por_pais <- list(
  fuente         = "US Census Bureau — International Trade API",
  endpoint       = "timeseries/intltrade/imports/hs",
  url            = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga = Sys.time(),
  periodo        = paste(range(imp_por_pais$fecha), collapse = " – "),
  notas          = "Top 20 países identificados por valor acumulado 2024-2025 (ene 2024 - nov 2025).
                    Resto = Total mensual menos suma de Top 20.
                    Total proviene de descarga sin desagregación por país (Paso 1).
                    Datos en dólares corrientes, granularidad mensual."
)

# — Guardar -------------------------------------------------------------------
saveRDS(imp_por_pais_all,  here("RDS", "imp_por_pais_all.rds"))
saveRDS(imp_por_pais,      here("RDS", "imp_por_pais.rds"))
saveRDS(meta_imp_por_pais, here("RDS", "meta_imp_por_pais.rds"))


cat("Listo. Filas en imp_por_pais:", nrow(imp_por_pais), "\n")
cat("Listo. Filas en imp_por_pais_all:", nrow(imp_por_pais_all), "\n")
