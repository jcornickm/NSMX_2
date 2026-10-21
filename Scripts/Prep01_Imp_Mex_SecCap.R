# Prep01_Imp_Mex_SecCap.R   ####
# Importaciones de EUA desde México por Capítulo del SA (HS2), con ajuste estacional.
#
# NO descarga nada: se DERIVA de RDS/raw_df_mex_vnm_twn.rds (Query02, fuente
# maestra de Census). Ejecutar Query01 y Query02 antes.
#
# Salida: RDS/imp_mex_sec_cap.rds — una fila por mes × Capítulo (1–99), serie
#         completa disponible (el corte a 2024 para el Cap. 2 se hace al graficar).
#         Val_mes_sa se recalcula sobre la serie completa cada vez que se agregan
#         datos (X-13 revisa la historia).

pacman::p_load(tidyverse, here, scales, seasonal)

source(here("Scripts", "funciones.R"))   # hs_agregar_etiquetas(), sa_adj()

#  Sección 1. Capítulos (HS2) de México desde la fuente maestra            ####

raw_mx <- readRDS(here("RDS", "raw_df_mex_vnm_twn.rds")) |>
  filter(Pais == "México") |>
  mutate(cod = as.character(I_COMMODITY))

caps_raw <- raw_mx |>
  filter(grepl("^[0-9]{2}$", cod)) |>
  transmute(
    fecha        = as.Date(paste0(time, "-01")),
    Capítulo     = as.integer(cod),
    Cap_desc_api = as.character(I_COMMODITY_LDESC),
    Val_mes      = as.numeric(GEN_VAL_MO),
    Val_acum     = as.numeric(GEN_VAL_YR)
  )

stopifnot("Hay filas duplicadas fecha × Capítulo" =
            !anyDuplicated(caps_raw[, c("fecha", "Capítulo")]))

cat("Capítulos:", n_distinct(caps_raw$Capítulo),
    "| filas:", nrow(caps_raw),
    "| período:", format(min(caps_raw$fecha)), "a", format(max(caps_raw$fecha)), "\n")

#  Sección 2. Ajuste estacional (X-13) por Capítulo, serie completa        ####
# sa_adj() asume meses consecutivos. Los meses sin registro (capítulo sin
# importaciones ese mes) se completan con 0 ANTES del ajuste y luego se
# descartan, para no desplazar la serie. Si X-13 falla en un capítulo, se
# devuelve el valor sin ajustar y se reporta (no es silencioso).

ajustar_capitulo <- function(df) {
  malla <- tibble(fecha = seq(min(df$fecha), max(df$fecha), by = "month")) |>
    left_join(select(df, fecha, Val_mes), by = "fecha") |>
    mutate(v = replace_na(Val_mes, 0))
  
  sa <- tryCatch(
    list(x = sa_adj(malla$v, malla$fecha), ok = TRUE, msg = NA_character_),
    error = function(e) list(x = malla$v, ok = FALSE, msg = conditionMessage(e))
  )
  
  tibble(fecha = malla$fecha, Val_mes_sa = sa$x,
         sa_ok = sa$ok, sa_msg = sa$msg, meses_completados = sum(is.na(malla$Val_mes))) |>
    semi_join(df, by = "fecha")
}

message("\n=== Ajuste estacional por Capítulo (puede tardar unos minutos) ===")

sa_tab <- caps_raw |>
  arrange(Capítulo, fecha) |>
  group_by(Capítulo) |>
  group_modify(~ ajustar_capitulo(.x)) |>
  ungroup()

fallidos <- sa_tab |>
  group_by(Capítulo) |>
  summarise(sa_ok = all(sa_ok), motivo = first(sa_msg), n_meses = n(),
            meses_completados = first(meses_completados), .groups = "drop")

cat("\nCapítulos con ajuste estacional exitoso:", sum(fallidos$sa_ok), "de", nrow(fallidos), "\n")
if (any(!fallidos$sa_ok)) {
  message("⚠️  X-13 falló; se usa el valor SIN ajustar en estos Capítulos:")
  fallidos |> filter(!sa_ok) |> print(n = Inf)
}
cat("Meses completados con 0 antes del ajuste (total):", sum(fallidos$meses_completados), "\n")

#  Sección 3. Etiquetas y ensamblaje                                       ####

imp_mex_sec_cap <- caps_raw |>
  left_join(select(sa_tab, Capítulo, fecha, Val_mes_sa), by = c("Capítulo", "fecha")) |>
  hs_agregar_etiquetas() |>
  select(fecha, Sección, Sección_corto, Capítulo, Cap_corto,
         Cap_desc_api, Val_mes, Val_acum, Val_mes_sa) |>
  arrange(fecha, Capítulo)

cat("\nNAs en Sección:", sum(is.na(imp_mex_sec_cap$Sección)),
    "| NAs en Cap_corto:", sum(is.na(imp_mex_sec_cap$Cap_corto)),
    "| NAs en Val_mes_sa:", sum(is.na(imp_mex_sec_cap$Val_mes_sa)), "\n")

#  Sección 4. Verificaciones                                               ####

## 4a. Suma de Capítulos vs. total ("-") de la propia fuente y vs. Query01   ####
tol <- 0.5   # USD; las sumas de flotantes no son exactas al centavo

total_caps <- imp_mex_sec_cap |>
  group_by(fecha) |>
  summarise(suma_caps = sum(Val_mes, na.rm = TRUE), .groups = "drop")

total_fuente <- raw_mx |>
  filter(cod == "-") |>
  transmute(fecha = as.Date(paste0(time, "-01")), total_raw = as.numeric(GEN_VAL_MO))

total_q1 <- readRDS(here("RDS", "imp_por_pais_all.rds")) |>
  filter(CTY_CODE == "2010") |>
  select(fecha, total_q1 = Imp_mes)

verif <- total_caps |>
  full_join(total_fuente, by = "fecha") |>
  full_join(total_q1, by = "fecha") |>
  mutate(dif_vs_raw = suma_caps - total_raw,
         dif_vs_q1  = suma_caps - total_q1)

cat("\n=== Verificación: suma de Capítulos vs. total ===\n")
cat("Meses comparados:", sum(!is.na(verif$suma_caps) & !is.na(verif$total_q1)), "\n")
cat("Dif. máx. vs. total de Query02 (USD):", comma(max(abs(verif$dif_vs_raw), na.rm = TRUE)), "\n")
cat("Dif. máx. vs. Query01 (USD):         ", comma(max(abs(verif$dif_vs_q1),  na.rm = TRUE)), "\n")
if (all(abs(verif$dif_vs_raw) <= tol, na.rm = TRUE) && all(abs(verif$dif_vs_q1) <= tol, na.rm = TRUE) &&
    !anyNA(verif$suma_caps) && !anyNA(verif$total_q1)) {
  cat("✔  La suma de Capítulos coincide con el total en todos los meses.\n")
} else {
  message("⚠️  Discrepancias — revisar:")
  verif |> filter(abs(dif_vs_raw) > tol | abs(dif_vs_q1) > tol | is.na(suma_caps) | is.na(total_q1)) |> print(n = 30)
}

## 4b. Cambios respecto a la versión anterior del archivo (revisiones)       ####
ruta_prev <- here("RDS", "imp_mex_sec_cap.rds")
if (file.exists(ruta_prev)) {
  previo <- readRDS(ruta_prev) |> select(fecha, Capítulo, Val_mes_prev = Val_mes)
  cmp <- full_join(previo, select(imp_mex_sec_cap, fecha, Capítulo, Val_mes), by = c("fecha", "Capítulo"))
  cat("\n=== Cambios vs. versión anterior de imp_mex_sec_cap.rds (por año) ===\n")
  cmp |>
    mutate(año = year(fecha)) |>
    group_by(año) |>
    summarise(
      nuevas     = sum(is.na(Val_mes_prev) & !is.na(Val_mes)),
      desaparece = sum(!is.na(Val_mes_prev) & is.na(Val_mes)),
      revisadas  = sum(!is.na(Val_mes_prev) & !is.na(Val_mes) & abs(Val_mes - Val_mes_prev) > tol),
      suma_prev  = sum(Val_mes_prev, na.rm = TRUE),
      suma_nueva = sum(Val_mes, na.rm = TRUE),
      dif_pct    = if_else(suma_prev == 0, NA_real_, round((suma_nueva / suma_prev - 1) * 100, 4)),
      .groups = "drop"
    ) |>
    filter(nuevas > 0 | desaparece > 0 | revisadas > 0) |>
    print(n = Inf)
}

#  Sección 5. Metadatos y guardado                                         ####

meta_imp_mex_sec_cap <- list(
  fuente         = "US Census Bureau — International Trade API (vía Query02: raw_df_mex_vnm_twn.rds)",
  país_origen    = "México (CTY_CODE = 2010)",
  nivel          = "Capítulo SA (2 dígitos); Sección derivada por agrupación",
  período        = paste(range(imp_mex_sec_cap$fecha), collapse = " – "),
  fecha_creación = Sys.time(),
  sa             = list(
    método   = "X-13ARIMA-SEATS (seasonal::seas, especificación automática) sobre la serie completa",
    meses_sin_registro = "completados con 0 antes del ajuste y descartados después",
    capítulos_sin_ajuste = fallidos$Capítulo[!fallidos$sa_ok]
  ),
  notas          = "Val_mes y Val_acum en dólares corrientes.
                    Sección_corto y Cap_corto: nombres cortos de RDS/hs_dictionary.rds.
                    Cap_desc_api: nombre en inglés devuelto por el API (referencia).
                    Capítulos 98-99 incluidos (provisiones especiales EUA).
                    Sin filas de totales; calcular con group_by().
                    Val_mes_sa cambia en TODA la historia al agregar datos."
)

saveRDS(imp_mex_sec_cap,      here("RDS", "imp_mex_sec_cap.rds"))
saveRDS(meta_imp_mex_sec_cap, here("RDS", "meta_imp_mex_sec_cap.rds"))

cat("\nListo. Filas:", nrow(imp_mex_sec_cap),
    "| hasta:", format(max(imp_mex_sec_cap$fecha)),
    "\nGuardado en: RDS/imp_mex_sec_cap.rds\n")
