# Query06_WDI_IED_PIB.R   ####
# IED (flujos netos de entrada) como % del PIB — México, Costa Rica, Vietnam y
# República Dominicana. (Antes: chunk save-fig-ied-pib-comparadores de
# C2_Revised_*.qmd.)
#
# Fuente: World Bank, World Development Indicators (WDI), paquete WDI.
# Indicador: BX.KLT.DINV.WD.GD.ZS — "Foreign direct investment, net inflows (% of GDP)".
# La actualización más reciente del WDI puede no cubrir 2025 para todos los países.
# Es una DESCARGA (requiere internet); no se corre al reordenar datos existentes.
#
# Salida: RDS/ied_pib_wdi_comp.rds  (país, year, ied_pib_pct)

pacman::p_load(tidyverse, here, WDI)

paises <- c("MX", "CR", "VN", "DO")

ied_pib_wdi <- WDI(
  indicator = "BX.KLT.DINV.WD.GD.ZS",
  country   = paises,
  start     = 2010,
  end       = 2025
)

nombres_es <- c(
  "MX" = "México", "CR" = "Costa Rica",
  "VN" = "Vietnam", "DO" = "República Dominicana"
)

ied_pib_comp <- ied_pib_wdi |>
  rename(ied_pib_pct = BX.KLT.DINV.WD.GD.ZS) |>
  filter(!is.na(ied_pib_pct)) |>
  mutate(país = nombres_es[iso2c]) |>
  select(país, year, ied_pib_pct) |>
  arrange(país, year)

tryCatch({
  saveRDS(ied_pib_comp, here("RDS", "ied_pib_wdi_comp.rds"))
  message("✔  ied_pib_wdi_comp.rds guardado (", nrow(ied_pib_comp), " filas).")
}, error = function(e) message("✗  ERROR: ", conditionMessage(e)))
