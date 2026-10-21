# Prep08_immex.R   ####
# Participación de cada entidad en el empleo IMMEX (diciembre de cada año).
# (Antes: chunk prep-mapa-immex-4periodos de C2_Revised_*.qmd.)
#
# Entrada: RDS/immex_empleo.rds (Query08)
# Salida:  RDS/immex_pct.rds  (nombre, año, emp_estado, total_anual, pct)

pacman::p_load(tidyverse, here)

immex <- readRDS(here("RDS", "immex_empleo.rds"))

immex_pct <- immex |>
  filter(ID_MES == 12, !CVE_ENT %in% c("ZLF", "TOT")) |>
  group_by(año) |>
  mutate(total_anual = sum(emp_total, na.rm = TRUE)) |>
  ungroup() |>
  group_by(nombre, año) |>
  summarise(
    emp_estado  = sum(emp_total, na.rm = TRUE),
    total_anual = first(total_anual),
    .groups     = "drop"
  ) |>
  mutate(pct = emp_estado / total_anual)

saveRDS(immex_pct, here("RDS", "immex_pct.rds"))
message("✔  immex_pct.rds guardado (", nrow(immex_pct), " filas).")
