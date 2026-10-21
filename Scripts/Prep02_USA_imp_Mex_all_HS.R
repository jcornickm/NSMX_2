# Prep02_USA_imp_Mex_all_HS.R   ####
# Importaciones de EUA desde México por Partida (HS4) y Subpartida (HS6),
# partidas principales de los Caps. 84/85/87/90 y tabla de TCAC y shares.
#
# NO descarga nada: se DERIVA de RDS/raw_df_mex_vnm_twn.rds (Query02) y usa
# RDS/imp_mex_sec_cap.rds (Prep01) como denominador de los shares.
# Orden: Query01 → Query02 → Prep01 → Prep02.
#
# Niveles en I_COMMODITY:  "-" total | 2 dígitos Capítulo | 4 Partida |
#                          6 Subpartida | 10 Schedule B.
#
# Parámetros ---------------------------------------------------------------
# · ANIOS_TOP:  años COMPLETOS con que se elige el conjunto de partidas
#               principales (regla: partidas que acumulan el 80% del capítulo).
# · ANIOS_REF:  años de referencia de la tabla TCAC (anuales, 12 meses).
# · Los valores "ytd" (enero–último mes disponible) se calculan para
#   ANIOS_REF, el año anterior al actual y el año actual, para comparar
#   periodos con el mismo número de meses (Capítulo 3).

pacman::p_load(tidyverse, here, scales)

source(here("Scripts", "funciones.R"))   # hs_agregar_etiquetas(), hs_etiquetas_partida(), hs_tablas()

ANIOS_TOP          <- 2024:2025
ANIOS_REF          <- c(2010L, 2018L, 2024L, 2025L)
caps_seleccionados <- c(84, 85, 87, 90)

capitulos_es <- hs_tablas()$capitulos |> tibble::as_tibble()   # Capítulo, Sección, Cap_corto, Cap_tabla

#  Sección 1. Datos de México desde la fuente maestra                       ####

message("\n=== Leyendo raw_df_mex_vnm_twn.rds (solo México) ===")

imp_mex_all <- readRDS(here("RDS", "raw_df_mex_vnm_twn.rds")) |>
  filter(Pais == "México") |>
  transmute(
    fecha    = as.Date(paste0(time, "-01")),
    cod      = as.character(I_COMMODITY),
    I_COMMODITY_LDESC,
    nivel    = case_when(
      cod == "-"       ~ "total",
      nchar(cod) == 2  ~ "HS2",
      nchar(cod) == 4  ~ "HS4",
      nchar(cod) == 6  ~ "HS6",
      nchar(cod) == 10 ~ "HS10",
      .default         = "otro"
    ),
    Capítulo = as.integer(if_else(grepl("^[0-9]{2}", cod), substr(cod, 1, 2), NA_character_)),
    Val_mes  = as.numeric(GEN_VAL_MO),
    Val_acum = as.numeric(GEN_VAL_YR)
  )

cat("Filas (México, todos los niveles):", nrow(imp_mex_all),
    "| período:", format(min(imp_mex_all$fecha)), "a", format(max(imp_mex_all$fecha)), "\n")
cat("\nDistribución de niveles:\n")
imp_mex_all |> count(nivel) |> print()

#  Sección 2. Partidas (HS4) y Subpartidas (HS6), todos los capítulos       ####

message("\n=== Construyendo imp_mex_hs4_all ===")

imp_mex_hs4_all <- imp_mex_all |>
  filter(nivel == "HS4") |>
  hs_agregar_etiquetas() |>
  transmute(
    fecha, Sección, Sección_corto, Capítulo, Cap_corto,
    Cod_partida      = cod,
    Desc_api_partida = as.character(I_COMMODITY_LDESC),
    Val_mes, Val_acum
  ) |>
  arrange(fecha, Capítulo, Cod_partida)

message("=== Construyendo imp_mex_hs6_all ===")

imp_mex_hs6_all <- imp_mex_all |>
  filter(nivel == "HS6") |>
  hs_agregar_etiquetas() |>
  transmute(
    fecha, Sección, Sección_corto, Capítulo, Cap_corto,
    Cod_partida      = substr(cod, 1, 4),
    Cod_subpartida   = cod,
    Desc_api_subpart = as.character(I_COMMODITY_LDESC),
    Val_mes, Val_acum
  ) |>
  arrange(fecha, Capítulo, Cod_subpartida)

cat("Filas HS4:", nrow(imp_mex_hs4_all), "| partidas:", n_distinct(imp_mex_hs4_all$Cod_partida), "\n")
cat("Filas HS6:", nrow(imp_mex_hs6_all), "| subpartidas:", n_distinct(imp_mex_hs6_all$Cod_subpartida), "\n")

imp_mex_hs4_84858790 <- imp_mex_hs4_all |> filter(Capítulo %in% caps_seleccionados)
imp_mex_hs6_84858790 <- imp_mex_hs6_all |> filter(Capítulo %in% caps_seleccionados)

rm(imp_mex_all); invisible(gc())

#  Sección 3. Partidas principales de los Caps. 84, 85, 87 y 90             ####
# Dentro de cada capítulo, partidas ordenadas por valor en ANIOS_TOP; se incluyen
# hasta cruzar el 80% acumulado. Serie mensual completa de esas partidas.

codigos_top <- imp_mex_hs4_84858790 |>
  filter(year(fecha) %in% ANIOS_TOP) |>
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

imp_mex_top_hs4 <- imp_mex_hs4_84858790 |>
  filter(Cod_partida %in% codigos_top) |>
  hs_etiquetas_partida()

cat("\nPartidas principales (", min(ANIOS_TOP), "–", max(ANIOS_TOP), "): ",
    length(codigos_top), "\n", sep = "")
imp_mex_top_hs4 |>
  distinct(Capítulo, Cap_corto, Cod_partida, Part_corto, Part_tabla) |>
  arrange(Capítulo, Cod_partida) |>
  print(n = 60)

#  Sección 4. Verificaciones de consistencia                                ####

tol <- 1   # USD

imp_mex_sec_cap <- readRDS(here("RDS", "imp_mex_sec_cap.rds"))

## 4a. Suma de Partidas (HS4) por Capítulo vs. imp_mex_sec_cap (Prep01)      ####
verif_hs4 <- imp_mex_hs4_all |>
  group_by(fecha, Capítulo) |>
  summarise(suma_partidas = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
  full_join(select(imp_mex_sec_cap, fecha, Capítulo, Val_cap = Val_mes),
            by = c("fecha", "Capítulo")) |>
  mutate(suma_partidas = replace_na(suma_partidas, 0),
         Val_cap       = replace_na(Val_cap, 0),
         diferencia    = suma_partidas - Val_cap)

cat("\n=== HS4 vs. Capítulos (Prep01) ===\n")
cat("Meses × Capítulos comparados:", nrow(verif_hs4),
    "| diferencia máxima (USD):", comma(max(abs(verif_hs4$diferencia))), "\n")
if (all(abs(verif_hs4$diferencia) <= tol)) {
  cat("✔  Las sumas de Partidas coinciden con imp_mex_sec_cap.\n")
} else {
  message("⚠️  Discrepancias HS4 vs. Capítulos (primeras 20):")
  verif_hs4 |> filter(abs(diferencia) > tol) |> arrange(desc(abs(diferencia))) |> print(n = 20)
}

## 4b. Suma de Subpartidas (HS6) por Partida vs. HS4 (informativo)           ####
verif_hs6 <- imp_mex_hs6_all |>
  group_by(fecha, Cod_partida) |>
  summarise(suma_hs6 = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
  full_join(select(imp_mex_hs4_all, fecha, Cod_partida, val_hs4 = Val_mes),
            by = c("fecha", "Cod_partida")) |>
  mutate(diferencia = replace_na(suma_hs6, 0) - replace_na(val_hs4, 0))

cat("\n=== HS6 vs. HS4 (informativo) ===\n")
cat("Diferencia máxima (USD):", comma(max(abs(verif_hs6$diferencia))),
    "| casos con |dif| >", tol, "USD:", sum(abs(verif_hs6$diferencia) > tol), "\n")

#  Sección 5. Metadatos y guardado de HS4/HS6                               ####

meta_query4 <- list(
  fuente             = "US Census Bureau — International Trade API (vía Query02: raw_df_mex_vnm_twn.rds)",
  país_origen        = "México (CTY_CODE = 2010)",
  caps_seleccionados = "84 (Maquinaria), 85 (Eléctrico), 87 (Automóviles), 90 (Óptica)",
  criterio_top       = paste0("Partidas que acumulan 80% del capítulo, con base en ", min(ANIOS_TOP), "–", max(ANIOS_TOP)),
  período_hs4        = paste(range(imp_mex_hs4_all$fecha), collapse = " – "),
  período_hs6        = paste(range(imp_mex_hs6_all$fecha), collapse = " – "),
  fecha_creación     = Sys.time(),
  archivos           = list(
    imp_mex_hs4          = "Partidas (HS4), todos los capítulos",
    imp_mex_hs4_84858790 = "Partidas (HS4), capítulos 84/85/87/90",
    imp_mex_hs6          = "Subpartidas (HS6), todos los capítulos",
    imp_mex_hs6_84858790 = "Subpartidas (HS6), capítulos 84/85/87/90",
    imp_mex_top_hs4      = "Serie mensual de las partidas principales, con nombres cortos"
  ),
  notas              = "Val_mes y Val_acum en dólares corrientes. Sin filas de totales.
                        Serie completa disponible; el corte a 2024 del Cap. 2 se hace al graficar."
)

guardar <- function(obj, archivo) {
  tryCatch({
    saveRDS(obj, here("RDS", archivo))
    message("✔  ", archivo, " guardado.", if (is.data.frame(obj)) paste0(" Filas: ", nrow(obj)) else "")
  }, error = function(e) message("✗  ERROR guardando ", archivo, ": ", conditionMessage(e)))
}

guardar(imp_mex_hs4_all,      "imp_mex_hs4.rds")
guardar(imp_mex_hs4_84858790, "imp_mex_hs4_84858790.rds")
guardar(imp_mex_hs6_all,      "imp_mex_hs6.rds")
guardar(imp_mex_hs6_84858790, "imp_mex_hs6_84858790.rds")
guardar(imp_mex_top_hs4,      "imp_mex_top_hs4.rds")
guardar(meta_query4,          "meta_query3.rds")   # nombre de archivo histórico (antes Query3)

#  Sección 6. TCAC y shares por partida — caps. 84, 85, 87, 90             ####
# Una fila por partida principal + fila "Resto" por capítulo (= total del capítulo
# menos suma de partidas principales).
# · val_AAAA:     suma de 12 meses, años ANIOS_REF.
# · val_ytd_AAAA: suma enero–mes_corte (último mes disponible), para ANIOS_REF,
#                 el año anterior al actual y el actual.
# · TCAC_1018, TCAC_1824, Crec_2425: sobre años completos (Capítulo 2).
# · TCAC_ytd_1018, TCAC_ytd_1824, TCAC_ytd_24act, Crec_ytd_act: lo mismo con
#   enero–mes_corte (Capítulo 3).
# · Shares (pct_*): sobre años completos 2025 y 2024; denominador = total del
#   capítulo / total general México→EUA (de imp_mex_sec_cap).
# · Los acumulados NO se calculan aquí (dependen del ordenamiento).

message("\n=== Construyendo TCAC_y_shares_84858790 ===")

fecha_max  <- max(imp_mex_sec_cap$fecha)
mes_corte  <- month(fecha_max)
anio_act   <- year(fecha_max)
ANIOS_YTD  <- sort(unique(c(ANIOS_REF, anio_act - 1L, anio_act)))
cat("Último mes disponible: ", format(fecha_max), " → ytd = enero–", month.abb[mes_corte], "\n", sep = "")

llaves <- c("Capítulo", "Cap_corto", "Cod_partida", "Part_corto", "Part_tabla")

agr <- function(df, grupo, anios, hasta_mes) {
  df |>
    filter(year(fecha) %in% anios, month(fecha) <= hasta_mes) |>
    group_by(across(all_of(grupo)), Año = year(fecha)) |>
    summarise(Val = sum(Val_mes, na.rm = TRUE), .groups = "drop")
}

# Tabla ancha (partidas + Resto) para un conjunto de años y un último mes.
construir_ancha <- function(anios, hasta_mes, prefijo) {
  total_cap <- imp_mex_sec_cap |>
    filter(Capítulo %in% caps_seleccionados) |>
    agr(c("Capítulo", "Cap_corto"), anios, hasta_mes) |>
    rename(Val_cap = Val)
  
  partidas <- agr(imp_mex_top_hs4,
                  c("Capítulo", "Cap_corto", "Cod_partida", "Part_corto", "Part_tabla"),
                  anios, hasta_mes)
  
  resto <- total_cap |>
    left_join(partidas |> group_by(Capítulo, Año) |> summarise(Val_top = sum(Val), .groups = "drop"),
              by = c("Capítulo", "Año")) |>
    transmute(Capítulo, Cap_corto, Año, Val = Val_cap - replace_na(Val_top, 0),
              Cod_partida = "Resto", Part_corto = "Resto", Part_tabla = "Resto")
  
  bind_rows(partidas, resto) |>
    pivot_wider(names_from = Año, values_from = Val, names_prefix = prefijo, values_fill = 0)
}

ancha_anual <- construir_ancha(ANIOS_REF, 12L,       "val_")
ancha_ytd   <- construir_ancha(ANIOS_YTD, mes_corte, "val_ytd_")

# Denominadores de los shares (años completos)
total_cap_anual <- imp_mex_sec_cap |>
  filter(Capítulo %in% caps_seleccionados) |>
  agr(c("Capítulo"), c(2024L, 2025L), 12L) |>
  pivot_wider(names_from = Año, values_from = Val, names_prefix = "Val_cap_")

total_gral_anual <- imp_mex_sec_cap |>
  agr(character(0), c(2024L, 2025L), 12L)
total_gral_2024 <- total_gral_anual$Val[total_gral_anual$Año == 2024L]
total_gral_2025 <- total_gral_anual$Val[total_gral_anual$Año == 2025L]

col_ytd_act  <- paste0("val_ytd_", anio_act)
col_ytd_prev <- paste0("val_ytd_", anio_act - 1L)

tcac <- function(fin, ini, n) if_else(ini > 0, (fin / ini)^(1 / n) - 1, NA_real_)
crec <- function(fin, ini)    if_else(ini > 0, fin / ini - 1, NA_real_)

TCAC_y_shares_84858790 <- ancha_anual |>
  left_join(ancha_ytd |> select(all_of(llaves), starts_with("val_ytd_")), by = llaves) |>
  left_join(total_cap_anual, by = "Capítulo") |>
  mutate(
    TCAC_1018 = tcac(val_2018, val_2010, 8),
    TCAC_1824 = tcac(val_2024, val_2018, 6),
    Crec_2425 = crec(val_2025, val_2024),
    
    TCAC_ytd_1018  = tcac(val_ytd_2018, val_ytd_2010, 8),
    TCAC_ytd_1824  = tcac(val_ytd_2024, val_ytd_2018, 6),
    TCAC_ytd_24act = tcac(.data[[col_ytd_act]], val_ytd_2024, anio_act - 2024L),
    Crec_ytd_act   = crec(.data[[col_ytd_act]], .data[[col_ytd_prev]]),
    
    pct_cap        = val_2025 / Val_cap_2025,
    pct_total      = val_2025 / total_gral_2025,
    pct_cap_2024   = val_2024 / Val_cap_2024,
    pct_total_2024 = val_2024 / total_gral_2024
  ) |>
  select(
    all_of(llaves),
    val_2010, val_2018, val_2024, val_2025,
    TCAC_1018, TCAC_1824, Crec_2425,
    pct_cap, pct_total, pct_cap_2024, pct_total_2024,
    starts_with("val_ytd_"),
    TCAC_ytd_1018, TCAC_ytd_1824, TCAC_ytd_24act, Crec_ytd_act
  ) |>
  arrange(Capítulo, desc(val_2025))

cat("\n=== Verificación: shares deben sumar 1 por capítulo ===\n")
TCAC_y_shares_84858790 |>
  group_by(Capítulo) |>
  summarise(suma_pct_cap = sum(pct_cap, na.rm = TRUE), suma_pct_total = sum(pct_total, na.rm = TRUE),
            suma_pct_cap_2024 = sum(pct_cap_2024, na.rm = TRUE), suma_pct_total_2024 = sum(pct_total_2024, na.rm = TRUE),
            .groups = "drop") |>
  print()

cat("\nFilas por capítulo:\n")
TCAC_y_shares_84858790 |> count(Capítulo, Cap_corto) |> print()

cat("\nFilas con val_ytd_", anio_act, " == 0: ", sum(TCAC_y_shares_84858790[[col_ytd_act]] == 0), "\n", sep = "")

meta_TCAC_y_shares <- list(
  fuente         = "US Census Bureau — International Trade API (Query02 → Prep02)",
  objetos_base   = c("imp_mex_top_hs4", "imp_mex_sec_cap"),
  fecha_creación = Sys.time(),
  capítulos      = "84 (Maquinaria), 85 (Eléctrico), 87 (Automóviles), 90 (Óptica)",
  años_ref       = paste(ANIOS_REF, collapse = ", "),
  mes_corte      = paste0("ytd = enero–", month.name[mes_corte], " (último dato: ", format(fecha_max), ")"),
  años_ytd       = paste(ANIOS_YTD, collapse = ", "),
  tasas          = paste(
    "TCAC_1018 (8 años), TCAC_1824 (6 años), Crec_2425: años completos.",
    "TCAC_ytd_1018, TCAC_ytd_1824: lo mismo con enero–mes_corte;",
    "TCAC_ytd_24act: 2024 → año actual (enero–mes_corte);",
    "Crec_ytd_act: año anterior → año actual (enero–mes_corte)."
  ),
  shares         = "pct_cap y pct_total: base 2025; pct_cap_2024 y pct_total_2024: base 2024. Años completos.",
  resto          = "Fila 'Resto' = total del capítulo (imp_mex_sec_cap) menos suma de partidas principales, por periodo.",
  acumulados     = "No incluidos — dependen del ordenamiento",
  notas          = "TCAC/crecimiento = NA si el valor inicial es 0. Dólares corrientes. Ordenado por capítulo y val_2025 descendente."
)

guardar(TCAC_y_shares_84858790, "TCAC_y_shares_84858790.rds")
guardar(meta_TCAC_y_shares,     "meta_TCAC_y_shares.rds")

cat("\nListo.\n")
