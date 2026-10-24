# funciones_verificacion.R
# Verificaciones posteriores a una descarga. Funciones pequeñas y componibles.
# Genérico: no depende de ningún proyecto. Documentación y razonamiento en
# Quarto/Protocolo_verificacion_descargas.qmd (mantener ambos en sincronía).
#
# Convenciones
#  - Cada chk_*() recibe un data.frame (o vectores) y devuelve su entrada
#    de forma invisible, para poder encadenar con |>.
#  - `accion` = "stop" (detiene) o "warn" (avisa y sigue).
#    Defecto: "stop" para estructura y suma vs total; "warn" para rangos
#    y revisiones (ver el protocolo, sección "Detener o avisar").
#  - `etiqueta` identifica la fuente en el mensaje (qué se estaba verificando).
#  - Requiere solo base R (dplyr no es necesario).

.chk_fallo <- function(msg, accion = c("stop", "warn"), etiqueta = NULL) {
  accion <- match.arg(accion)
  if (!is.null(etiqueta)) msg <- paste0("[", etiqueta, "] ", msg)
  if (accion == "stop") stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
}

.chk_ok <- function(msg, etiqueta = NULL) {
  if (!is.null(etiqueta)) msg <- paste0("[", etiqueta, "] ")  |> paste0(msg)
  message("OK  ", msg)
}

# 1. Dimensiones y columnas ---------------------------------------------------
# Columnas esperadas presentes, y número mínimo de filas.
chk_dimensiones <- function(df, columnas = NULL, n_min = 1,
                            accion = "stop", etiqueta = NULL) {
  faltan <- setdiff(columnas, names(df))
  if (length(faltan) > 0)
    .chk_fallo(paste("columnas ausentes:", paste(faltan, collapse = ", ")),
               accion, etiqueta)
  if (nrow(df) < n_min)
    .chk_fallo(sprintf("solo %d filas (mínimo esperado %d)", nrow(df), n_min),
               accion, etiqueta)
  .chk_ok(sprintf("dimensiones: %d filas x %d columnas", nrow(df), ncol(df)),
          etiqueta)
  invisible(df)
}

# 2. Claves únicas (duplicados) -----------------------------------------------
# `claves` = columnas que identifican una observación (p. ej. fecha + país).
chk_claves_unicas <- function(df, claves, accion = "stop", etiqueta = NULL) {
  dup <- duplicated(df[, claves, drop = FALSE]) |
         duplicated(df[, claves, drop = FALSE], fromLast = TRUE)
  if (any(dup))
    .chk_fallo(sprintf("%d filas con clave repetida (%s). Ejemplo: %s",
                       sum(dup), paste(claves, collapse = " + "),
                       paste(unlist(df[which(dup)[1], claves]), collapse = " / ")),
               accion, etiqueta)
  .chk_ok(sprintf("claves únicas (%s)", paste(claves, collapse = " + ")), etiqueta)
  invisible(df)
}

# 3. Valores faltantes --------------------------------------------------------
# Falla si la proporción de NA en alguna columna supera `max_prop`.
chk_na <- function(df, columnas = names(df), max_prop = 0,
                   accion = "stop", etiqueta = NULL) {
  prop <- vapply(df[, columnas, drop = FALSE], function(x) mean(is.na(x)), numeric(1))
  malas <- prop[prop > max_prop]
  if (length(malas) > 0)
    .chk_fallo(paste0("NA por encima de ", max_prop, " en: ",
                      paste0(names(malas), " (", round(100 * malas, 1), "%)",
                             collapse = ", ")),
               accion, etiqueta)
  .chk_ok("proporción de NA dentro de lo esperado", etiqueta)
  invisible(df)
}

# 4. Rango plausible ----------------------------------------------------------
chk_rango <- function(df, col, min = -Inf, max = Inf,
                      accion = "warn", etiqueta = NULL) {
  x <- df[[col]]
  fuera <- which(!is.na(x) & (x < min | x > max))
  if (length(fuera) > 0)
    .chk_fallo(sprintf("%d valores de '%s' fuera de [%s, %s]; rango observado [%s, %s]",
                       length(fuera), col, min, max,
                       signif(base::min(x, na.rm = TRUE), 6),
                       signif(base::max(x, na.rm = TRUE), 6)),
               accion, etiqueta)
  .chk_ok(sprintf("'%s' dentro de [%s, %s]", col, min, max), etiqueta)
  invisible(df)
}

# 5. Huecos en fechas ---------------------------------------------------------
# paso: "day", "week", "month", "quarter", "year". `por` = columnas de grupo
# (cada grupo debe tener su serie completa entre su mínimo y máximo).
chk_huecos_fecha <- function(df, fecha = "fecha", por = NULL, paso = "month",
                             accion = "stop", etiqueta = NULL) {
  f <- as.Date(df[[fecha]])
  grupo <- if (is.null(por)) rep("(todo)", nrow(df))
           else do.call(paste, c(df[, por, drop = FALSE], sep = " | "))
  huecos <- list()
  for (g in unique(grupo)) {
    fg <- sort(unique(f[grupo == g]))
    esperado <- seq(min(fg), max(fg), by = paso)
    falta <- setdiff(esperado, fg)
    if (length(falta) > 0)
      huecos[[g]] <- format(as.Date(falta, origin = "1970-01-01"))
  }
  if (length(huecos) > 0) {
    n <- length(huecos)
    ej <- names(huecos)[1]
    .chk_fallo(sprintf("%d grupo(s) con huecos de fechas (paso %s). %s: faltan %s",
                       n, paso, ej, paste(utils::head(huecos[[1]], 5), collapse = ", ")),
               accion, etiqueta)
  }
  .chk_ok(sprintf("sin huecos de fechas (paso %s)", paso), etiqueta)
  invisible(df)
}

# 6. Misma fecha final entre grupos -------------------------------------------
# Útil cuando varios países/series deberían llegar al mismo mes.
chk_misma_fecha_final <- function(df, fecha = "fecha", por,
                                  accion = "warn", etiqueta = NULL) {
  f <- as.Date(df[[fecha]])
  g <- do.call(paste, c(df[, por, drop = FALSE], sep = " | "))
  fin <- tapply(f, g, max)
  if (length(unique(fin)) > 1)
    .chk_fallo(paste("fechas finales distintas:",
                     paste(names(fin), format(as.Date(fin, origin = "1970-01-01")),
                           sep = " = ", collapse = "; ")),
               accion, etiqueta)
  .chk_ok(sprintf("misma fecha final (%s)", format(max(f))), etiqueta)
  invisible(df)
}

# 7. Suma de partes vs total --------------------------------------------------
# `partes` y `total` son vectores alineados (p. ej. suma por grupo y total
# publicado). Tolerancia absoluta `tol` o relativa `tol_rel` (se usa la mayor).
chk_suma_vs_total <- function(partes, total, tol = 0, tol_rel = 1e-6,
                              accion = "stop", etiqueta = NULL) {
  dif <- abs(partes - total)
  umbral <- pmax(tol, tol_rel * abs(total))
  malos <- which(!is.na(dif) & dif > umbral)
  if (length(malos) > 0)
    .chk_fallo(sprintf("%d casos donde suma de partes != total. Peor: partes=%s, total=%s (dif %s)",
                       length(malos),
                       format(partes[malos[which.max(dif[malos])]], big.mark = ","),
                       format(total[malos[which.max(dif[malos])]], big.mark = ","),
                       format(max(dif[malos]), big.mark = ",")),
               accion, etiqueta)
  .chk_ok("suma de partes = total", etiqueta)
  invisible(NULL)
}

# 8. Ancla externa ------------------------------------------------------------
# Compara un valor calculado con una cifra publicada conocida (órdenes de
# magnitud incluidos). `tol_rel = 0.05` -> acepta ±5 %.
chk_ancla <- function(valor, referencia, tol_rel = 0.05, descripcion = "",
                      accion = "stop", etiqueta = NULL) {
  rel <- abs(valor / referencia - 1)
  if (is.na(rel) || rel > tol_rel)
    .chk_fallo(sprintf("ancla '%s': calculado %s vs referencia %s (diferencia %.1f%%, tolerancia %.1f%%)",
                       descripcion, format(valor, big.mark = ","),
                       format(referencia, big.mark = ","),
                       100 * rel, 100 * tol_rel),
               accion, etiqueta)
  .chk_ok(sprintf("ancla '%s' dentro de %.1f%%", descripcion, 100 * tol_rel), etiqueta)
  invisible(valor)
}

# 9. Revisión contra la descarga anterior -------------------------------------
# `nuevo` y `anterior`: data.frames con las mismas claves y columna `valor`.
# Reporta cuántos valores del traslape cambiaron y cuánto. Por defecto avisa:
# las revisiones son normales; lo que importa es que sean pequeñas y esperadas.
chk_revision <- function(nuevo, anterior, claves, valor,
                         tol_rel = 0.01, accion = "warn", etiqueta = NULL) {
  k_n <- do.call(paste, c(nuevo[, claves, drop = FALSE], sep = "|"))
  k_a <- do.call(paste, c(anterior[, claves, drop = FALSE], sep = "|"))
  comunes <- intersect(k_n, k_a)
  if (length(comunes) == 0) {
    .chk_fallo("no hay traslape con la descarga anterior (¿cambió la clave?)",
               accion, etiqueta)
    return(invisible(NULL))
  }
  vn <- nuevo[[valor]][match(comunes, k_n)]
  va <- anterior[[valor]][match(comunes, k_a)]
  rel <- abs(vn / va - 1)
  cambian <- which(!is.na(rel) & rel > tol_rel)
  if (length(cambian) > 0)
    .chk_fallo(sprintf("%d de %d valores del traslape cambiaron más de %.1f%%; máximo %.1f%%",
                       length(cambian), length(comunes), 100 * tol_rel,
                       100 * max(rel[cambian])),
               accion, etiqueta)
  .chk_ok(sprintf("revisión vs descarga anterior: %d valores comparados", length(comunes)),
          etiqueta)
  invisible(NULL)
}
