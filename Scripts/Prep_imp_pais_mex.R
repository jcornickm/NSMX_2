# Prep_imp_pais_mex.R   ####
# Tablas derivadas para los capítulos de importaciones de EUA (Capítulo 2).
# Antes se calculaban dentro de los chunks origAnualPerc, prep-sec-pct y
# prep-caps de C2_Revised_*.qmd.
#
# Entradas: RDS/imp_por_pais.rds (Query1), RDS/imp_mex_sec_cap.rds (Query2)
# Salidas:
#   RDS/impPais_Perc.rds      — importaciones anuales de EUA por país (ajustadas
#                               estacionalmente) y participación, 2010–2025
#   RDS/impMex_sec_pct.rds    — importaciones anuales desde México por Sección y
#                               participación (2010–2025)
#   RDS/impMex_caps_2025.rds  — 2025: valor y participación por Capítulo dentro
#                               de las Secciones XVI, XVII y XVIII
#
# Requiere el paquete 'seasonal' (X-13) para sa_adj().

pacman::p_load(tidyverse, here, lubridate)
source(here("Scripts", "funciones.R"))   # sa_adj(), hs_relabel()

# 1. Participación de cada país en las importaciones de EUA ---------------------
impPais <- readRDS(here("RDS", "imp_por_pais.rds"))

impPais_Perc <- impPais |>
  filter(grupo %in% c("Top20", "Resto")) |>
  arrange(País, fecha) |>
  group_by(País, rank) |>
  mutate(Imp_mes_sa = sa_adj(Imp_mes, fecha, freq = 12)) |>
  group_by(País, rank, año = lubridate::year(fecha)) |>
  summarise(Imp_anual = sum(Imp_mes_sa, na.rm = TRUE), .groups = "drop") |>
  group_by(año) |>
  mutate(share = Imp_anual / sum(Imp_anual)) |>
  ungroup() |>
  select(año, País, rank, Imp_anual, share)

saveRDS(impPais_Perc, here("RDS", "impPais_Perc.rds"))

# 2. Importaciones desde México por Sección -------------------------------------
impMex <- readRDS(here("RDS", "imp_mex_sec_cap.rds")) |> hs_relabel()

# Participaciones anuales por Sección del SA enero–diciembre
impMex_sec_pct <- map_dfr(2010:2025, function(año) {
  impMex |>
    filter(year(fecha) == año) |>
    group_by(año = year(fecha), Sección, Sección_corto) |>
    summarise(Val_anual = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    group_by(año) |>
    mutate(pct = Val_anual / sum(Val_anual)) |>
    ungroup()
})

saveRDS(impMex_sec_pct, here("RDS", "impMex_sec_pct.rds"))

# 3. Capítulos de las Secciones XVI, XVII y XVIII, 2025 -------------------------
secciones_interes <- c("XVI", "XVII", "XVIII")   # Maquinaria, Transporte, Instrumentos

impMex_caps_2025 <- impMex |>
  filter(Sección %in% secciones_interes, year(fecha) == 2025) |>
  group_by(Sección, Sección_corto, Capítulo, Cap_corto) |>
  summarise(Val_anual = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
  group_by(Sección) |>
  mutate(pct = Val_anual / sum(Val_anual)) |>
  ungroup()

saveRDS(impMex_caps_2025, here("RDS", "impMex_caps_2025.rds"))
message("✔  impPais_Perc.rds, impMex_sec_pct.rds e impMex_caps_2025.rds guardados.")
