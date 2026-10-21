# Query01_USA_imports_by_country.R   ####
# Importaciones de EUA: total y por país de origen (Census, API de comercio
# internacional). Dos descargas por año: total sin desagregar, y por país.
#
# ACTUALIZACIÓN INCREMENTAL: no se vuelve a bajar toda la historia. Se descarga
# desde ANIO_SOLAPE hasta el último mes disponible (Census revisa los años
# recientes) y se reemplaza ese tramo en los RDS existentes; lo anterior no se
# toca. Cada año descargado queda en RDS/raw/q1_*_AAAA.rds.
#
# Entradas:  RDS/imp_por_pais_all.rds (versión actual), API de Census
# Salidas:   RDS/imp_por_pais_all.rds, RDS/imp_por_pais.rds,
#            RDS/meta_imp_por_pais.rds, RDS/revision_q1.rds (qué cambió)

pacman::p_load(tidyverse, here, lubridate)
source(here("Scripts", "funciones_datos.R"))

ANIO_SOLAPE    <- 2023L   # primer año que se vuelve a descargar
VIGENCIA_HORAS <- 12      # un archivo raw más viejo que esto se vuelve a descargar
ANIO_RANK      <- 2024L   # el Top 20 se identifica por valor desde enero de este año

# — PASO 0: ¿hasta qué mes hay datos? ------------------------------------------
anio_actual <- year(Sys.Date())
ultimo_mes  <- census_ultimo_mes(anio_actual)
message("Último mes disponible en Census: ", ultimo_mes)

años <- if (is.na(ultimo_mes)) ANIO_SOLAPE:(anio_actual - 1L) else ANIO_SOLAPE:anio_actual
desde <- as.Date(sprintf("%d-01-01", ANIO_SOLAPE))

# — PASO 1: Datos existentes ---------------------------------------------------
imp_por_pais_all_v <- readRDS(here("RDS", "imp_por_pais_all.rds"))
total_v  <- imp_por_pais_all_v |> distinct(fecha, Imp_total)
paises_v <- imp_por_pais_all_v |> select(fecha, CTY_CODE, CTY_NAME, Imp_mes)

# — PASO 2: Total de importaciones de EUA (sin desagregar por país) -------------
message("\n=== Descargando totales ", min(años), "–", max(años), " ===")
nuevo_total <- census_descargar_anios(
  prefijo = "q1_total", anios = años,
  vars = c("GEN_VAL_MO", "GEN_VAL_YR"),
  mes_fin_actual = ultimo_mes, max_edad_horas = VIGENCIA_HORAS
) |>
  mutate(fecha     = as.Date(paste0(time, "-01")),
         Imp_total = as.numeric(GEN_VAL_MO)) |>
  select(fecha, Imp_total)

act_total <- actualizar_rds(total_v, nuevo_total, llaves = character(0),
                            valor = "Imp_total", desde = desde,
                            nombre = "total de importaciones")
imp_total <- act_total$datos

# — PASO 3: Importaciones por país de origen ------------------------------------
message("\n=== Descargando por país ", min(años), "–", max(años), " ===")
nuevo_paises <- census_descargar_anios(
  prefijo = "q1_pais", anios = años,
  vars = c("CTY_CODE", "CTY_NAME", "GEN_VAL_MO"),
  mes_fin_actual = ultimo_mes, max_edad_horas = VIGENCIA_HORAS
) |>
  mutate(fecha   = as.Date(paste0(time, "-01")),
         Imp_mes = as.numeric(GEN_VAL_MO)) |>
  # El API incluye filas de agregados ("-", "1XXX"…"7XXX"): se excluyen antes de
  # convertir a número (evita el aviso "NAs introduced by coercion")
  filter(grepl("^[0-9]+$", CTY_CODE)) |>
  filter(as.integer(CTY_CODE) >= 1000) |>     # solo países (códigos 1000+)
  select(fecha, CTY_CODE, CTY_NAME, Imp_mes)

act_paises <- actualizar_rds(paises_v, nuevo_paises, llaves = "CTY_CODE",
                             valor = "Imp_mes", desde = desde,
                             nombre = "importaciones por país")
imp_paises <- act_paises$datos

# — Verificación: ¿suma de países ≈ total? --------------------------------------
# Si hay una diferencia grande, hay más códigos de agregados que filtrar
verificacion <- imp_paises |>
  group_by(fecha) |>
  summarise(suma_paises = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(imp_total, by = "fecha") |>
  mutate(dif_pct = (Imp_total - suma_paises) / Imp_total * 100)

stopifnot("Hay meses sin total" = !anyNA(verificacion$Imp_total))
cat("\nDiferencia promedio (%):", round(mean(abs(verificacion$dif_pct), na.rm = TRUE), 2), "\n")
cat("Diferencia máxima (%):",   round(max(abs(verificacion$dif_pct),  na.rm = TRUE), 2), "\n")

# — PASO 4: Top 20 ---------------------------------------------------------------
# La lista de 20 países (y sus nombres) es FIJA para que los capítulos usen los
# mismos países; abajo se avisa si con los datos nuevos el Top 20 cambiaría.
top20_nombres <- tibble(
  CTY_CODE = c("2010","1220","5700","5520","5830","4280","5880",
               "5800","4190","5330","4419","5490","4759","4120",
               "4279","5570","3510","5590","4210","5600"),
  País = c("México","Canadá","China","Vietnam","Taiwán","Alemania","Japón",
           "Corea_S","Irlanda","India","Suiza","Tailandia","Italia","R_Unido",
           "Francia","Malasia","Brasil","Singapur","P_Bajos","Indonesia"),
  rank = 1:20
)

top20_actual <- imp_paises |>
  filter(fecha >= as.Date(sprintf("%d-01-01", ANIO_RANK))) |>
  group_by(CTY_CODE, CTY_NAME) |>
  summarise(total = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  slice_max(total, n = 20) |>
  arrange(desc(total))

entran <- top20_actual |> filter(!CTY_CODE %in% top20_nombres$CTY_CODE)
salen  <- top20_nombres |> filter(!CTY_CODE %in% top20_actual$CTY_CODE)
if (nrow(entran) > 0 || nrow(salen) > 0) {
  message("\n⚠ Con los datos nuevos el Top 20 (desde ", ANIO_RANK, ") cambiaría:")
  message("  Entrarían: ", paste(entran$CTY_NAME, collapse = ", "))
  message("  Saldrían:  ", paste(salen$País, collapse = ", "))
  message("  La lista fija NO se modifica; decidir si se actualiza.")
} else {
  message("\n✓ El Top 20 no cambia con los datos nuevos.")
}

# — PASO 5: Construir imp_por_pais_all --------------------------------------------
imp_por_pais_all <- imp_paises |>
  left_join(top20_nombres, by = "CTY_CODE") |>
  left_join(imp_total, by = "fecha")

# — PASO 6: Construir imp_por_pais (Top 20 + Resto + Total) --------------------------
top20 <- imp_por_pais_all |>
  filter(CTY_CODE %in% top20_nombres$CTY_CODE) |>
  mutate(grupo = "Top20") |>
  select(fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo)

# Resto = Total − suma Top 20, por mes
resto <- top20 |>
  group_by(fecha) |>
  summarise(suma_top20 = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(imp_total, by = "fecha") |>
  mutate(CTY_CODE = "REST", País = "Resto", rank = 21L,
         Imp_mes = Imp_total - suma_top20, grupo = "Resto") |>
  select(fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo)

total <- imp_total |>
  mutate(CTY_CODE = "TOT", País = "Total", rank = 0L,
         Imp_mes = Imp_total, grupo = "Total") |>
  select(fecha, CTY_CODE, País, rank, Imp_mes, Imp_total, grupo)

imp_por_pais <- bind_rows(total, top20, resto) |>
  arrange(fecha, rank)

# — Verificación: Top 20 + Resto debe sumar exactamente al Total ----------------------
verificacion2 <- imp_por_pais |>
  filter(grupo != "Total") |>
  group_by(fecha) |>
  summarise(suma = sum(Imp_mes, na.rm = TRUE), .groups = "drop") |>
  left_join(imp_total, by = "fecha") |>
  mutate(dif = Imp_total - suma)
cat("Diferencia máxima Top20+Resto vs Total:", max(abs(verificacion2$dif)), "\n")
cat("Rango de fechas:", format(min(imp_por_pais$fecha)), "→", format(max(imp_por_pais$fecha)), "\n")

# — Metadatos -------------------------------------------------------------------------
meta_imp_por_pais <- list(
  fuente         = "US Census Bureau — International Trade API",
  endpoint       = "timeseries/intltrade/imports/hs",
  url            = "https://api.census.gov/data/timeseries/intltrade/imports/hs",
  fecha_descarga = Sys.time(),
  periodo        = paste(range(imp_por_pais$fecha), collapse = " – "),
  solape_desde   = format(desde),
  ultimo_mes     = ultimo_mes,
  notas          = paste(
    "Actualización incremental: los años anteriores a", ANIO_SOLAPE,
    "provienen de la descarga original (abril de 2026); desde", ANIO_SOLAPE,
    "se volvió a descargar (Census revisa años recientes; ver revision_q1.rds).",
    "Top 20 fijo (identificado por valor 2024-2025); Resto = Total mensual menos suma de Top 20.",
    "Total proviene de la descarga sin desagregación por país.",
    "Dólares corrientes, granularidad mensual."
  )
)

# — Guardar ---------------------------------------------------------------------------
tryCatch({
  saveRDS(imp_por_pais_all,  here("RDS", "imp_por_pais_all.rds"))
  saveRDS(imp_por_pais,      here("RDS", "imp_por_pais.rds"))
  saveRDS(meta_imp_por_pais, here("RDS", "meta_imp_por_pais.rds"))
  saveRDS(list(total  = act_total$revision, paises = act_paises$revision,
               fecha  = Sys.time()),
          here("RDS", "revision_q1.rds"))
  message("✓ imp_por_pais_all.rds, imp_por_pais.rds, meta_imp_por_pais.rds y revision_q1.rds guardados.")
}, error = function(e) message("✗ Error al guardar: ", conditionMessage(e)))

cat("Listo. Filas en imp_por_pais:", nrow(imp_por_pais), "\n")
cat("Listo. Filas en imp_por_pais_all:", nrow(imp_por_pais_all), "\n")
