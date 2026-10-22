# ============================================================================
# Query03_Tariffs_USITC_Autos_Autopartes.R
#
# USITC DataWeb — Aranceles mensuales
# Partidas HTS: 8703 (automóviles para pasajeros) y 8708 (autopartes)
# Países: México (2010), Corea del Sur (5800), Japón (5880) y Alemania (4280;
#         representa a la UE, que tiene un arancel común)
# Período: 2010 – último mes disponible (se recorta al último mes con datos)
#
# Para otras partidas o conjuntos de países, copiar este script y cambiar
# HTS_CODES y paises (y el nombre del archivo y de los RDS de salida).
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

pacman::p_load(httr2, jsonlite, tidyverse, lubridate, here)
source(here("Scripts", "funciones_datos.R"))   # actualizar_rds()

# ── 0. Configuración ──────────────────────────────────────────────────────────

BASE_URL  <- "https://datawebws.usitc.gov/dataweb"
API_TOKEN <- Sys.getenv("DATAWEB_TOKEN")
stopifnot("DATAWEB_TOKEN no encontrado en .Renviron" = nchar(API_TOKEN) > 0)

# Partidas HTS4: código = descripción (la descripción solo se usa como etiqueta)
HTS_CODES <- c(
  "8703" = "MOTOR VEHICLES FOR TRANSPORT OF PERSONS",
  "8708" = "PARTS AND ACCESSORIES OF THE MOTOR VEHICLES OF HEADINGS 8701 TO 8705"
)
YEARS <- 2010:year(Sys.Date())   # DataWeb devuelve los meses disponibles del año en curso

paises <- list(
  list(code = "2010", nombre = "Mexico - MX - MEX"),
  list(code = "5800", nombre = "Korea, South - KR - KOR"),
  list(code = "5880", nombre = "Japan - JP - JPN"),
  list(code = "4280", nombre = "Germany - DE - DEU")
)

ARCHIVO_RDS      <- here("RDS", "aranceles_autos_autopartes_mensual.rds")
ARCHIVO_ANTERIOR <- here("RDS", "aranceles_hts8703_mex_kor_mensual.rds")   # versión previa (solo 8703, México y Corea)
DESDE_SOLAPE     <- as.Date("2023-01-01")   # desde aquí se reportan revisiones

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
      commoditiesManual   = paste(names(HTS_CODES), collapse = ","),
      commodityGroups     = list(systemGroups = list(), userGroups = list()),
      commodities         = as.list(names(HTS_CODES)),
      commoditiesExpanded = imap(HTS_CODES, \(nom, cod) list(name = nom, value = cod)) |> unname()
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

message("Consultando DataWeb: HTS ", paste(names(HTS_CODES), collapse = " + "),
        " | ", length(paises), " países",
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
  
  # Con varios países y partidas puede haber más de un grupo de filas
  rows <- unlist(map(table_obj$row_groups, "rowsNew"), recursive = FALSE)
  
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

# Verificación: deben venir todas las series país × partida solicitadas
n_series_esperadas <- length(paises) * length(HTS_CODES)
n_series           <- n_distinct(aranceles$pais, aranceles$cod_hts)
if (n_series != n_series_esperadas)
  warning("Series recibidas: ", n_series, " (esperadas: ", n_series_esperadas, "). Revisar abajo.")

# ── 4b. Recorte al último mes con datos y guardado ────────────────────────────
# Para el año en curso DataWeb puede devolver meses futuros con valor 0.

ultimo_mes <- aranceles |> filter(val_imp > 0) |> pull(fecha) |> max(na.rm = TRUE)
aranceles  <- aranceles |> filter(fecha <= ultimo_mes)
message("Último mes con datos: ", format(ultimo_mes, "%Y-%m"))

# La consulta baja toda la historia (una sola llamada), así que no hay que
# acumular: el archivo se sobrescribe completo. Antes se reporta cuánto se
# revisaron los datos ya publicados desde DESDE_SOLAPE, comparando contra el
# archivo nuevo previo si existe o, en la primera corrida, contra la versión
# anterior (solo las series que ésta contenía).
archivo_comp <- c(ARCHIVO_RDS, ARCHIVO_ANTERIOR)
archivo_comp <- archivo_comp[file.exists(archivo_comp)][1]

if (!is.na(archivo_comp)) {
  message("Comparando contra: ", basename(archivo_comp))
  viejo <- readRDS(archivo_comp)
  invisible(actualizar_rds(
    viejo  = viejo,
    nuevo  = semi_join(aranceles, viejo, by = c("pais", "cod_hts")),
    llaves = c("pais", "cod_hts"),
    valor  = "val_imp",
    desde  = DESDE_SOLAPE,
    nombre = "aranceles autos y autopartes"
  ))
}

saveRDS(aranceles, ARCHIVO_RDS)
message("✔ Guardado: RDS/", basename(ARCHIVO_RDS))

# ── 5. Diagnóstico rápido ─────────────────────────────────────────────────────

cat("\nRango de fechas:", format(min(aranceles$fecha, na.rm = TRUE)),
    "→", format(max(aranceles$fecha, na.rm = TRUE)), "\n")
cat("Filas:", nrow(aranceles), " | NAs en fecha:",
    sum(is.na(aranceles$fecha)), "\n")
cat("\nFilas por país y partida:\n")
aranceles |> count(pais, cod_hts) |> print()

# ── 6. Muestra de resultados ──────────────────────────────────────────────────

cat("\n=== Muestra — últimos 3 meses ===\n\n")
aranceles |>
  filter(fecha >= ultimo_mes %m-% months(2)) |>
  mutate(
    val_imp        = scales::comma(val_imp),
    val_gravable   = scales::comma(val_gravable),
    derechos       = scales::comma(derechos),
    tasa_efectiva  = scales::percent(tasa_efectiva,  accuracy = 0.001),
    tasa_implicita = scales::percent(tasa_implicita, accuracy = 0.001)
  ) |>
  print(n = Inf, width = 120)

# ── 7. Gráfico: estilo IDB Tariff Tracker ─────────────────────────────────────

etiquetas_pais <- c("Mexico" = "México", "South Korea" = "Corea del Sur",
                    "Japan"  = "Japón",  "Germany"     = "Alemania")
etiquetas_hts  <- c("8703" = "8703 · Automóviles", "8708" = "8708 · Autopartes")

colores_pais <- c("México" = "#00BFC4", "Corea del Sur" = "#F8766D",
                  "Japón"  = "#7CAE00", "Alemania"      = "#C77CFF")

aranceles |>
  filter(fecha >= as.Date("2025-01-01")) |>
  pivot_longer(
    cols      = c(tasa_efectiva, tasa_implicita),
    names_to  = "tipo",
    values_to = "tasa"
  ) |>
  mutate(
    pais_label = coalesce(unname(etiquetas_pais[pais]), pais),
    hts_label  = coalesce(unname(etiquetas_hts[cod_hts]), cod_hts),
    tipo_label = if_else(tipo == "tasa_efectiva", "Efectiva", "Implícita")
  ) |>
  ggplot(aes(x = fecha, y = tasa, color = pais_label, linetype = tipo_label)) +
  geom_step(linewidth = 0.9) +
  facet_wrap(~ hts_label, ncol = 1) +
  scale_color_manual(values = colores_pais) +
  scale_linetype_manual(values = c("Efectiva" = "solid", "Implícita" = "dotted")) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "2 months") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, NA)) +
  labs(
    title    = "Aranceles EUA sobre automóviles y autopartes",
    subtitle = "México, Corea del Sur, Japón y Alemania, desde enero de 2025",
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

# ── 8. Metadatos ──────────────────────────────────────────────────────────────

meta_aranceles <- list(
  fuente         = "USITC DataWeb",
  endpoint       = "https://datawebws.usitc.gov/dataweb/api/v2/report2/runReport",
  fecha_descarga = Sys.time(),
  cod_hts        = names(HTS_CODES),
  desc_hts       = HTS_CODES,
  países         = paste0(map_chr(paises, \(p) p$nombre), " (CTY_CODE ", map_chr(paises, \(p) p$code), ")"),
  nota_países    = "Alemania (4280) se usa como representante de la UE, que aplica un arancel común.",
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

saveRDS(meta_aranceles, here("RDS", "meta_aranceles_autos_autopartes.rds"))
message("✔ Guardado: RDS/meta_aranceles_autos_autopartes.rds")
