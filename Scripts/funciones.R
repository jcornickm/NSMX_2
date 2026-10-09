# En Scripts/funciones.R
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
  
  seasonal::seas(y_ts) |>
    seasonal::final()  |>
    as.numeric()
}
