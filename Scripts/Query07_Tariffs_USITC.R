# ============================================================================
# Query07_Tariffs_USITC.R
#
# USITC DataWeb — Aranceles mensuales
# Partida HTS 8703 (automóviles para pasajeros)
# Países: México (2010) y Corea del Sur (5800)
# Período: 2010–2025
#
# Tres medidas:
#   CONS_CUSTOMS_VALUE          → val_imp      (valor de importación, USD)
#   CONS_CUSTOMS_VALUE_SUB_DUTY → val_gravable (valor sujeto a arancel, USD)
#   CONS_CALC_DUTY              → derechos     (derechos calculados, USD)
#
# Tasas calculadas:
#   tasa_efectiva  = derechos     / val_imp
#   tasa_implicita = val_gravable / val_imp
#
# ============================================================================

pacman::p_load(httr2, jsonlite, tidyverse, lubridate)

# ── 0. Configuración ──────────────────────────────────────────────────────────

BASE_URL  <- "https://datawebws.usitc.gov/dataweb"
API_TOKEN <- Sys.getenv("DATAWEB_TOKEN")
stopifnot("DATAWEB_TOKEN no encontrado en .Renviron" = nchar(API_TOKEN) > 0)

HTS_CODE <- "8703"
YEARS    <- 2010:2025

paises <- list(
  list(code = "2010", nombre = "Mexico - MX - MEX"),
  list(code = "5800", nombre = "Korea, South - KR - KOR")
)

# ── 1. Query body ─────────────────────────────────────────────────────────────

query_body <- list(
  
  reportOptions = list(
    tradeType            = "Import",
    classificationSystem = "HTS"
  ),
  
  searchOptions = list(
    
    componentSettings = list(
      dataToReport = list(
        "CONS_CUSTOMS_VALUE",
        "CONS_CUSTOMS_VALUE_SUB_DUTY",
        "CONS_CALC_DUTY"
      ),
      scale               = "1",
      timeframeSelectType = "fullYears",
      years               = as.list(as.character(YEARS)),
      yearsTimeline       = "Monthly",
      startDate           = NULL,
      endDate             = NULL,
      startMonth          = NULL,
      endMonth            = NULL
    ),
    
    countries = list(
      aggregation         = "Break Out Countries",
      countriesSelectType = "list",
      countryGroups       = list(systemGroups = list(), userGroups = list()),
      countries           = map(paises, \(p) p$code),
      countriesExpanded   = map(paises, \(p) list(name = p$nombre, value = p$code))
    ),
    
    commodities = list(
      aggregation         = "Break Out Commodities",
      codeDisplayFormat   = "YES",
      commoditySelectType = "list",
      granularity         = "4",
      groupGranularity    = NULL,
      searchGranularity   = NULL,
      showHTSValidDetails = "",
      commoditiesManual   = HTS_CODE,
      commodityGroups     = list(systemGroups = list(), userGroups = list()),
      commodities         = list(HTS_CODE),
      commoditiesExpanded = list(
        list(name = "MOTOR VEHICLES FOR TRANSPORT OF PERSONS", value = HTS_CODE)
      )
    ),
    
# El código que sigue serviría para filtrar los datos.  Aquí estamos escogiendo no filtarar, así que el código es un "place holder" por si en algún momento quisiéramos filtar por alguno de estos criterios

    MiscGroup = list(
      importPrograms = list(
        aggregation        = NULL,
        importPrograms     = list(),
        programsSelectType = "all"
      ),
      provisionCodes = list(
        aggregation              = "Aggregate RPCODE",
        provisionCodesSelectType = "all",
        rateProvisionCodes       = list()
      ),
      districts = list(
        aggregation    = "Aggregate District",
        districtGroups = list(userGroups = list()),
        districts      = list()
      )
    )
  ),
  
  sortingAndDataFormat = list(
    DataSort = list(
      columnOrder = list("COUNTRY", "HTS6 & DESCRIPTION")
    ),
    reportCustomizations = list(
      exportCombineTables = FALSE,
      totalRecords        = "20000",
      exportRawData       = FALSE
    )
  )
)

# ── 2. Enviar solicitud ───────────────────────────────────────────────────────

message("Consultando DataWeb: HTS ", HTS_CODE,
        " | México + Corea del Sur",
        " | Años ", min(YEARS), "-", max(YEARS), " | Mensual")

resp <- request(paste0(BASE_URL, "/api/v2/report2/runReport")) |>
  req_headers(
    "Content-Type"  = "application/json; charset=utf-8",
    "Authorization" = paste("Bearer", API_TOKEN)
  ) |>
  req_body_raw(
    toJSON(query_body, auto_unbox = TRUE, null = "null"),
    "application/json"
  ) |>
  req_error(is_error = \(r) FALSE) |>
  req_perform()

http_status <- resp_status(resp)
message("HTTP status: ", http_status)

if (http_status >= 400) {
  stop("Error del API ", http_status, ": ", resp_body_string(resp))
}

resp_json <- resp_body_string(resp) |>
  fromJSON(simplifyVector = FALSE)

n_tables <- length(resp_json$dto$tables)
message("Tablas recibidas: ", n_tables)

cat("Países en la respuesta:",
    paste(unlist(resp_json$dto$countriesExpanded), collapse = ", "), "\n")

if (n_tables == 0) {
  stop("No se recibieron tablas. Verificar código HTS, código de país y año.")
}

# ── 3. Parseo de la respuesta ─────────────────────────────────────────────────

parse_table <- function(table_obj, nombre_var) {
  
  col_labels <- table_obj$column_groups |>
    map(\(g) map_chr(g$columns, \(c) c$label)) |>
    unlist()
  
  message("  [", nombre_var, "] columnas: ",
          paste(head(col_labels, 8), collapse = " | "),
          if (length(col_labels) > 8) " ..." else "")
  
  rows <- table_obj$row_groups[[1]]$rowsNew
  
  wide <- map_dfr(rows, function(row) {
    vals <- map_chr(row$rowEntries, \(e) as.character(e$value))
    setNames(as.list(vals), col_labels) |> as_tibble()
  })
  
  id_cols   <- c("Country", "COUNTRY", "Year", "YEAR",
                 "HTS Number", "HTS NUMBER", "Description", "DESCRIPTION")
  time_cols <- col_labels[!col_labels %in% id_cols]
  
  if (length(time_cols) == 0) {
    stop("parse_table(): no se encontraron columnas de tiempo para '", nombre_var, "'.")
  }
  
  wide |>
    pivot_longer(
      cols      = all_of(time_cols),
      names_to  = "mes",
      values_to = nombre_var
    ) |>
    rename(
      pais    = any_of(c("Country",    "COUNTRY")),
      cod_hts = any_of(c("HTS Number", "HTS NUMBER")),
      anio    = any_of(c("Year",       "YEAR"))
    ) |>
    mutate(
      fecha        = lubridate::my(paste(mes, anio), quiet = TRUE),
      !!nombre_var := as.numeric(str_remove_all(.data[[nombre_var]], ","))
    ) |>
    select(pais, cod_hts, fecha, all_of(nombre_var))
}

# ── 4. Unir las tres medidas y calcular tasas ─────────────────────────────────

nombres_vars <- c("val_imp", "val_gravable", "derechos")

aranceles <- map2(
  resp_json$dto$tables[seq_len(min(n_tables, 3))],
  nombres_vars[seq_len(min(n_tables, 3))],
  parse_table
) |>
  reduce(left_join, by = c("pais", "cod_hts", "fecha")) |>
  mutate(
    tasa_efectiva  = derechos     / val_imp,
    tasa_implicita = val_gravable / val_imp
  ) |>
  select(pais, cod_hts, fecha,
         val_imp, val_gravable, derechos,
         tasa_efectiva, tasa_implicita) |>
  arrange(pais, cod_hts, fecha)

# ── 5. Diagnóstico rápido ─────────────────────────────────────────────────────

cat("\nRango de fechas:", format(min(aranceles$fecha, na.rm = TRUE)),
    "→", format(max(aranceles$fecha, na.rm = TRUE)), "\n")
cat("Filas:", nrow(aranceles), " | NAs en fecha:",
    sum(is.na(aranceles$fecha)), "\n")
cat("\nFilas por país:\n")
aranceles |> count(pais) |> print()

# ── 6. Muestra de resultados ──────────────────────────────────────────────────

cat("\n=== Muestra — HTS", HTS_CODE, "| México y Corea del Sur ===\n\n")
aranceles |>
  filter(fecha >= "2024-01-01") |>
  mutate(
    val_imp        = scales::comma(val_imp),
    val_gravable   = scales::comma(val_gravable),
    derechos       = scales::comma(derechos),
    tasa_efectiva  = scales::percent(tasa_efectiva,  accuracy = 0.001),
    tasa_implicita = scales::percent(tasa_implicita, accuracy = 0.001)
  ) |>
  print(width = 120)

# ── 7. Guardar ────────────────────────────────────────────────────────────────

# saveRDS(aranceles, here::here("RDS", "aranceles_hts8703_mex_kor_mensual.rds"))
# write_csv(aranceles, here::here("RDS", "aranceles_hts8703_mex_kor_mensual.csv"))
# message("Guardado: RDS/aranceles_hts8703_mex_kor_mensual.rds / .csv")

# ── 8. Gráfico: estilo IDB Tariff Tracker ─────────────────────────────────────

aranceles_graf <- aranceles |>
  mutate(
    pais_label = case_when(
      pais == "Mexico"      ~ "Mex",
      pais == "South Korea" ~ "Kor",
      TRUE                  ~ pais
    )
  ) |>
  pivot_longer(
    cols      = c(tasa_efectiva, tasa_implicita),
    names_to  = "tipo",
    values_to = "tasa"
  ) |>
  mutate(
    tipo_label  = if_else(tipo == "tasa_efectiva", "efec", "imp"),
    serie_label = paste0(pais_label, "_", tipo_label)
  )

niveles   <- c("Mex_efec", "Mex_imp", "Kor_efec", "Kor_imp")
colores   <- c("#00BFC4",  "#00BFC4", "#F8766D",  "#F8766D")
linetypes <- c("solid",    "dotted",  "solid",    "dotted")
names(colores)   <- niveles
names(linetypes) <- niveles

aranceles_graf |>
  filter(fecha >= "2025-01-01") |>
  mutate(serie_label = factor(serie_label, levels = niveles)) |>
  ggplot(aes(x = fecha, y = tasa,
             color    = serie_label,
             linetype = serie_label)) +
  geom_step(linewidth = 1) +
  scale_color_manual(values = colores) +
  scale_linetype_manual(values = linetypes) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "1 month") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, NA)) +
  labs(
    title    = "Aranceles EUA sobre automóviles (HTS 8703)",
    subtitle = "México y Corea del Sur, 2025",
    x        = NULL,
    y        = "Tasa arancelaria (%)",
    color    = NULL,
    linetype = NULL,
    caption  = "Elaboración propia con base en USITC DataWeb.\nTasa efectiva = derechos / valor importado. Tasa implícita = valor gravable / valor importado."
  ) +
  theme_bw() +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    axis.text.x      = element_text(angle = 90, vjust = 0.5)
  )

saveRDS(aranceles, here::here("RDS", "aranceles_hts8703_mex_kor_mensual.rds"))

# ── 9. Metadatos ──────────────────────────────────────────────────────────────

meta_aranceles <- list(
  fuente         = "USITC DataWeb",
  endpoint       = "https://datawebws.usitc.gov/dataweb/api/v2/report2/runReport",
  fecha_descarga = Sys.time(),
  cod_hts        = HTS_CODE,
  desc_hts       = "Motor vehicles for transport of persons",
  países         = "México (CTY_CODE 2010), Corea del Sur (CTY_CODE 5800)",
  período        = paste(range(aranceles$fecha, na.rm = TRUE), collapse = " – "),
  frecuencia     = "Mensual",
  unidad         = "Dólares corrientes (val_imp, val_gravable, derechos); proporción 0–1 (tasas)",
  variables_fuente = "CONS_CUSTOMS_VALUE → val_imp;
                      CONS_CUSTOMS_VALUE_SUB_DUTY → val_gravable;
                      CONS_CALC_DUTY → derechos",
  tasas_derivadas  = "tasa_efectiva = derechos / val_imp;
                      tasa_implicita = val_gravable / val_imp",
  notas          = "La tasa efectiva mide el arancel realmente pagado sobre el valor total importado.
                    La tasa implícita mide qué proporción del valor importado quedó sujeta a arancel.
                    Ambas tasas pueden ser NA o Inf cuando val_imp = 0."
)

saveRDS(meta_aranceles, here::here("RDS", "meta_aranceles_hts8703.rds"))
message("✔ Guardado: RDS/meta_aranceles_hts8703.rds")
