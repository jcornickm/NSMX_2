# Prep06_tcac_estados.R   ####
# TCAC de las exportaciones estatales por subperíodo + tablas de apoyo para el
# mapa y la tabla del Capítulo 2 (chunks save-fig-tcac-estados y tbl-tcac-estados).
# Antes este cálculo estaba DUPLICADO en los dos chunks del qmd; ahora se hace
# una sola vez aquí.
#
# Entradas: RDS/xmex_total_ef.rds (Query04; fuente: ver MD/Catalogo_RDS.md)
# Salidas:  RDS/tcac_estados.rds   — formato largo: cve_geo, nombre, col, año_ini,
#                                    año_fin, tcac_pct (en %, p. ej. 5.2 = 5.2%)
#           RDS/estados_lookup.rds — list(abreviaturas, gadm_a_nombre)

pacman::p_load(tidyverse, here)

x_ef <- readRDS(here("RDS", "xmex_total_ef.rds"))

# Valor exportado anual por estado
xmex_val <- x_ef |>
  group_by(cve_geo, nombre, año) |>
  summarise(val_estado = sum(val_miles, na.rm = TRUE), .groups = "drop")

# TCAC (%) del valor exportado entre año_ini y año_fin, por estado
periodos <- tribble(
  ~col,             ~año_ini, ~año_fin,
  "tcac_2010_2017", 2010,     2017,
  "tcac_2017_2024", 2017,     2024,   # bloque 2018-2024, base 2017 (último año previo a la guerra comercial)
  "tcac_2024_2025", 2024,     2025
)

tcac_estados <- pmap_dfr(periodos, function(col, año_ini, año_fin) {
  xmex_val |>
    filter(año %in% c(año_ini, año_fin)) |>
    select(cve_geo, nombre, año, val_estado) |>
    pivot_wider(names_from = año, values_from = val_estado, names_prefix = "y") |>
    transmute(
      cve_geo, nombre, col, año_ini, año_fin,
      tcac_pct = ((.data[[paste0("y", año_fin)]] / .data[[paste0("y", año_ini)]])^(1 / (año_fin - año_ini)) - 1) * 100
    )
})

stopifnot("Deben ser 32 entidades por periodo" =
            all(count(tcac_estados, col)$n == 32))

# Abreviaturas por estado (para las etiquetas del mapa) -------------------------
abreviaturas <- c(
  "Aguascalientes"      = "AGS",   "Baja California"     = "BC",
  "Baja California Sur" = "BCS",   "Campeche"            = "Camp.",
  "Coahuila"            = "Coah.", "Colima"              = "Col.",
  "Chiapas"             = "Chis.", "Chihuahua"           = "Chih.",
  "Ciudad de México"    = "CDMX",  "Durango"             = "Dgo.",
  "Guanajuato"          = "Gto.",  "Guerrero"            = "Gro.",
  "Hidalgo"             = "Hgo.",  "Jalisco"             = "Jal.",
  "Estado de México"    = "Méx.",  "Michoacán"           = "Mich.",
  "Morelos"             = "Mor.",  "Nayarit"             = "Nay.",
  "Nuevo León"          = "NL",    "Oaxaca"              = "Oax.",
  "Puebla"              = "Pue.",  "Querétaro"           = "Qro.",
  "Quintana Roo"        = "QRoo",  "San Luis Potosí"     = "SLP",
  "Sinaloa"             = "Sin.",  "Sonora"              = "Son.",
  "Tabasco"             = "Tab.",  "Tamaulipas"          = "Tamps.",
  "Tlaxcala"            = "Tlax.", "Veracruz"            = "Ver.",
  "Yucatán"             = "Yuc.",  "Zacatecas"           = "Zac."
)

# Nombres del shapefile GADM -> nombre usado en xmex_total_ef -------------------
# (el resto de los nombres coincide tal cual)
gadm_a_nombre <- c(
  "México"           = "Estado de México",
  "Distrito Federal" = "Ciudad de México"
)

stopifnot("Todas las entidades de xmex deben tener abreviatura" =
            all(unique(tcac_estados$nombre) %in% names(abreviaturas)))

saveRDS(tcac_estados, here("RDS", "tcac_estados.rds"))
saveRDS(list(abreviaturas = abreviaturas, gadm_a_nombre = gadm_a_nombre),
        here("RDS", "estados_lookup.rds"))
message("✔  tcac_estados.rds y estados_lookup.rds guardados.")
