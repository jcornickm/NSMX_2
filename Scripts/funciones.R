# En Scripts/funciones.R

# ── Ventana temporal del Capítulo 2 ───────────────────────────────────────────
# Todos los gráficos y tablas derivadas del Capítulo 2 terminan en diciembre
# de 2024. El Capítulo 3 usa los datos más recientes y NO usa estas constantes.
ANIO_FIN  <- 2024L
FECHA_FIN <- as.Date("2024-12-31")
# ── sa_adj(): ajuste estacional genérico ──────────────────────────────────────
# Acepta cualquier vector + columna fecha Date.
# Detecta la frecuencia automáticamente desde la mediana del intervalo entre
# fechas (fallback: frequency puede pasarse explícitamente).
#
# Uso:
#   mutate(val_sa = sa_adj(val, fecha))           # frecuencia auto
#   mutate(val_sa = sa_adj(val, fecha, freq = 4)) # forzar trimestral

sa_adj <- function(x, dates, freq = NULL) {
  
  if (!requireNamespace("seasonal", quietly = TRUE))
    stop("Instala el paquete 'seasonal' para usar esta función.")
  
  # — Detectar frecuencia si no se pasa explícitamente --------------------
  # Nota: antes esto usaba dplyr::case_when() con stop() en la rama ~TRUE,
  # pero case_when() evalúa todas las ramas de forma eager, así que el
  # stop() se disparaba siempre, sin importar el intervalo real. Se
  # reemplaza por if/else, que sí evalúa de forma perezosa.
  if (is.null(freq)) {
    intervalo_dias <- as.numeric(median(diff(sort(dates)), na.rm = TRUE))
    freq <- if (intervalo_dias < 45) {
      12L   # mensual  (~30 días)
    } else if (intervalo_dias < 120) {
      4L    # trimestral (~91 días)
    } else {
      stop("Frecuencia no reconocida. Pasa freq = 4 o freq = 12.")
    }
  }
  
  # — Calcular start desde la fecha mínima --------------------------------
  start_date <- min(dates, na.rm = TRUE)
  start_year <- as.integer(format(start_date, "%Y"))
  
  start_period <- if (freq == 4L) {
    as.integer(ceiling(as.integer(format(start_date, "%m")) / 3))
  } else {
    as.integer(format(start_date, "%m"))
  }
  
  # — Construir serie de tiempo y ajustar ----------------------------------
  y_ts <- ts(x, start = c(start_year, start_period), frequency = freq)
  
  # Si la selección automática de modelo falla (p. ej. matriz de covarianza
  # singular), se reintenta con un modelo airline fijo (0 1 1)(0 1 1).
  m <- tryCatch(
    seasonal::seas(y_ts),
    error = function(e) {
      message("  ↺ seas() automático falló; reintentando con airline (0 1 1)(0 1 1)")
      seasonal::seas(y_ts, automdl = NULL, arima.model = "(0 1 1)(0 1 1)")
    }
  )
  
  m |>
    seasonal::final()  |>
    as.numeric()
}


# ── Etiquetas del Sistema Armonizado (SA/HS) ─────────────────────────────────
# Fuente única: RDS/hs_dictionary.rds (lo construye Scripts/build_hs_dictionary.R
# a partir de Excel/naladisa_2022.xlsx y Excel/hs_nombres_cortos.csv).
# Los nombres cortos se editan SOLO en el CSV; no hay tribbles ad hoc en los
# scripts de consulta ni en los qmd.
#
# Uso típico en un Query:
#   source(here::here("Scripts", "funciones.R"))
#   df <- df |> hs_agregar_etiquetas()          # df con columna numérica Capítulo
#   top <- top |> hs_etiquetas_partida()        # df con columna Cod_partida

hs_cargar <- function() {
  ruta <- here::here("RDS", "hs_dictionary.rds")
  if (!file.exists(ruta))
    stop("Falta RDS/hs_dictionary.rds: corre Scripts/build_hs_dictionary.R")
  readRDS(ruta)
}

# Tablas de referencia (Capítulo numérico -> Sección / nombres cortos)
hs_tablas <- function(dic = hs_cargar()) {
  secc <- dic[dic$nivel == "Sección", ]
  cap  <- dic[dic$nivel == "Capítulo", ]
  niveles_secc <- secc$codigo                       # I ... XXI, en orden
  cap_tbl <- data.frame(
    Capítulo   = as.numeric(cap$codigo),
    Sección    = cap$codigo_padre,
    Cap_corto  = cap$nombre_corto,
    Cap_tabla  = cap$nombre_tabla,
    stringsAsFactors = FALSE
  )
  cap_tbl <- cap_tbl[order(cap_tbl$Capítulo), ]
  secc_tbl <- data.frame(
    Sección       = secc$codigo,
    Sección_corto = secc$nombre_corto,
    Sección_tabla = secc$nombre_tabla,
    stringsAsFactors = FALSE
  )
  list(secciones = secc_tbl, capitulos = cap_tbl, niveles_sección = niveles_secc)
}

# Agrega Sección, Sección_corto y Cap_corto como factores ordenados.
# Requiere una columna numérica `Capítulo` (o indicar `col_cap`).
# Se detiene si algún capítulo queda sin etiqueta.
hs_agregar_etiquetas <- function(df, col_cap = "Capítulo", dic = hs_cargar()) {
  tb <- hs_tablas(dic)
  cap <- tb$capitulos
  sec <- tb$secciones
  cap_sin <- setdiff(unique(df[[col_cap]]), c(cap$Capítulo, NA))
  if (length(cap_sin) > 0)
    stop("Capítulos sin etiqueta en hs_dictionary: ",
         paste(sort(cap_sin), collapse = ", "))
  out <- df
  if (col_cap != "Capítulo") out$Capítulo <- out[[col_cap]]
  out <- dplyr::left_join(out, cap[, c("Capítulo", "Sección", "Cap_corto")],
                          by = "Capítulo")
  out <- dplyr::left_join(out, sec[, c("Sección", "Sección_corto")],
                          by = "Sección")
  out$Sección       <- factor(out$Sección, levels = tb$niveles_sección, ordered = TRUE)
  out$Sección_corto <- factor(out$Sección_corto, levels = sec$Sección_corto, ordered = TRUE)
  out$Cap_corto     <- factor(out$Cap_corto, levels = cap$Cap_corto, ordered = TRUE)
  if (col_cap != "Capítulo") out$Capítulo <- NULL
  out
}

# Nombre corto (y de tabla) por partida HS4. Con estricto = TRUE (default) se
# detiene si falta alguno; con FALSE solo avisa y deja NA:
# agregar la fila a Excel/hs_nombres_cortos.csv y correr build_hs_dictionary.R
hs_etiquetas_partida <- function(df, col_part = "Cod_partida", estricto = TRUE, dic = hs_cargar()) {
  p <- dic[dic$nivel == "Partida", c("codigo", "nombre_corto", "nombre_tabla")]
  names(p) <- c(col_part, "Part_corto", "Part_tabla")
  usados <- unique(df[[col_part]])
  usados <- usados[!usados %in% c("Resto")]
  sin <- usados[is.na(p$Part_corto[match(usados, p[[col_part]])])]
  if (length(sin) > 0 && !estricto)
    message("⚠ ", length(sin), " partidas sin nombre_corto (quedan NA; agregar a Excel/hs_nombres_cortos.csv). Primeras: ",
            paste(head(sort(sin), 10), collapse = ", "))
  if (length(sin) > 0 && estricto)
    stop("Partidas sin nombre_corto en hs_nombres_cortos.csv: ",
         paste(sort(sin), collapse = ", "))
  dplyr::left_join(df, p, by = col_part)
}

# Re-etiqueta un data frame ya existente con el diccionario actual (idempotente):
# quita las columnas de etiquetas viejas (incl. *_desc_es) y vuelve a ponerlas.
# Sirve para que los qmd usen siempre los nombres vigentes aunque el RDS se haya
# generado antes de un cambio en Excel/hs_nombres_cortos.csv.
hs_relabel <- function(df) {
  viejas <- c("Sección_corto", "Sección_desc_es", "Sección_desc_orig",
              "Cap_corto", "Cap_desc_es", "Part_corto", "Part_desc_es", "Part_tabla")
  if ("Capítulo" %in% names(df)) {
    df <- df[, setdiff(names(df), c(viejas, "Sección")), drop = FALSE]
    df <- hs_agregar_etiquetas(df)
  }
  if ("Cod_partida" %in% names(df)) {
    resto <- df$Cod_partida == "Resto"
    df <- hs_etiquetas_partida(df, estricto = FALSE)
    if (any(resto, na.rm = TRUE)) {
      df$Part_corto[resto] <- "Resto"
      df$Part_tabla[resto] <- "Resto"
    }
  }
  df
}


# ── Categorías y paleta de TCAC (mapa y tabla de exportaciones estatales) ────
# Una sola definición para que mapa y tabla coincidan en bins y colores.
breaks_tcac <- c(-Inf, -5, -2.5, 0, 2.5, 5, 7.5, Inf)
labels_tcac <- c("< −5%", "−5 a −2.5%", "−2.5 a 0%", "0 a 2.5%",
                 "2.5 a 5%", "5 a 7.5%", "> 7.5%")
paleta_tcac <- c(
  "< −5%"       = "#E66100",
  "−5 a −2.5%"  = "#F4A261",
  "−2.5 a 0%"   = "#FFE8A3",
  "0 a 2.5%"    = "#D6E9F8",
  "2.5 a 5%"    = "#A8C8DE",
  "5 a 7.5%"    = "#5B8FB9",
  "> 7.5%"      = "#1F4E79"
)
