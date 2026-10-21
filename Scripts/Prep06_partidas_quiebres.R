# Prep06_partidas_quiebres.R   ####
# (antes: chunk prep-top-partidas-quiebres de C2_Revised_*.qmd)
#
# Detección de quiebres estructurales (Bai-Perron, paquete strucchange) para
# las partidas presentadas INDIVIDUALMENTE (es decir, Cod_partida != "Resto")
# en las tablas de los Capítulos 84, 85, 87 y 90 (tcac_shares, chunk
# prep-tablas-cap). A diferencia de la versión anterior (chunk
# prep-top-partidas-quiebres-old-v1), que usaba el top-30 global de
# partidas_valor_depurado.rds, aquí el universo de partidas graficadas queda
# alineado con el de las tablas: solo se incluyen las que superan el criterio
# de 80% acumulado del capítulo; el resto queda fuera del panel (igual que
# queda agrupado en "Resto" en la tabla). Esto reduce el número de partidas
# por capítulo respecto a la versión anterior: Cap. 84 pasa de 13 a 9,
# Cap. 85 de ~11 a 10, Cap. 87 a 3 y Cap. 90 a 7 (verificar y actualizar la
# prosa descriptiva que menciona conteos y partidas específicas, p. ej. el
# párrafo "Empezamos con el Capítulo 84... hemos seleccionado 13 partidas...").
#
# Entradas: RDS/imp_mex_hs4.rds, RDS/TCAC_y_shares_84858790.rds (ambos de Prep02)
# Salidas:  RDS/partidas_tendencia.rds, RDS/quiebres_partida.rds

pacman::p_load(tidyverse, here, strucchange)
source(here("Scripts", "funciones.R"))   # sa_adj(), hs_relabel()

imp_mex_hs4 <- readRDS(here("RDS", "imp_mex_hs4.rds")) |> hs_relabel()

tcac_shares <- readRDS(here("RDS", "TCAC_y_shares_84858790.rds")) |> hs_relabel()

partidas_individuales <- tcac_shares |>
  filter(Capítulo %in% c(84, 85, 87, 90), Cod_partida != "Resto") |>
  distinct(Cod_partida, Nombre_corto_partida = Part_corto)

partidas_panel <- imp_mex_hs4 |>
  filter(
    Cod_partida %in% partidas_individuales$Cod_partida,
    fecha >= as.Date("2010-01-01"),
    fecha <= as.Date("2025-12-31")
  ) |>
  left_join(partidas_individuales, by = "Cod_partida") |>
  arrange(Cap_corto, Cod_partida, fecha)

partidas_sa <- partidas_panel |>
  group_by(Cod_partida) |>
  arrange(fecha, .by_group = TRUE) |>
  mutate(
    Val_mes_sa = tryCatch(
      sa_adj(Val_mes, fecha),
      error = function(e) Val_mes
    )
  ) |>
  ungroup()

partidas_indices <- partidas_sa |>
  group_by(Cod_partida) |>
  mutate(
    base_ene2018 = Val_mes_sa[fecha == as.Date("2018-01-01")][1],
    Indice       = (Val_mes_sa / base_ene2018) * 100
  ) |>
  ungroup()

H_MIN_SEGMENTO <- 24   # mínimo de meses por segmento entre quiebres (2 años)

fit_quiebre <- function(df) {
  df  <- df |> filter(!is.na(Indice))
  cod <- first(df$Cod_partida)

  vacio <- function(d) list(
    datos    = d,
    quiebres = tibble(Cod_partida = cod, psi_fecha = as.Date(character()))
  )

  if (nrow(df) < 2 * H_MIN_SEGMENTO) {
    df$Indice_tendencia <- NA_real_
    return(vacio(df))
  }

  df_reg <- df |> mutate(x = as.numeric(fecha), y = Indice)

  bp_full <- tryCatch(
    suppressWarnings(strucchange::breakpoints(y ~ x, data = df_reg, h = H_MIN_SEGMENTO)),
    error = function(e) NULL
  )

  if (is.null(bp_full)) {
    df$Indice_tendencia <- fitted(lm(y ~ x, data = df_reg))
    return(vacio(df))
  }

  bp_optimo <- tryCatch(
    suppressWarnings(strucchange::breakpoints(bp_full)),
    error = function(e) NULL
  )

  sin_quiebres <- is.null(bp_optimo) ||
    length(bp_optimo$breakpoints) == 0 ||
    all(is.na(bp_optimo$breakpoints))

  if (sin_quiebres) {
    df$Indice_tendencia <- fitted(lm(y ~ x, data = df_reg))
    return(vacio(df))
  }

  idx_quiebre <- bp_optimo$breakpoints
  psi_fecha   <- df_reg$fecha[idx_quiebre]
  psi_x       <- as.numeric(psi_fecha)

  for (i in seq_along(psi_x)) {
    df_reg[[paste0("hinge", i)]] <- pmax(df_reg$x - psi_x[i], 0)
  }
  formula_continua <- as.formula(
    paste("y ~ x +", paste(paste0("hinge", seq_along(psi_x)), collapse = " + "))
  )
  modelo_continuo     <- lm(formula_continua, data = df_reg)
  df$Indice_tendencia <- fitted(modelo_continuo)
  quiebres            <- tibble(Cod_partida = cod, psi_fecha = psi_fecha)

  list(datos = df, quiebres = quiebres)
}

resultados_quiebre <- partidas_indices |>
  arrange(Cod_partida, fecha) |>
  group_by(Cod_partida) |>
  group_split() |>
  map(fit_quiebre)

partidas_tendencia <- map_dfr(resultados_quiebre, "datos") |>
  mutate(
    num_cap       = as.integer(Cod_partida) %/% 100,
    label_partida = paste0(sprintf("%04d", as.integer(Cod_partida)), " — ", Nombre_corto_partida)
  )

quiebres_partida <- map_dfr(resultados_quiebre, "quiebres") |>
  left_join(
    partidas_tendencia |> distinct(Cod_partida, label_partida, num_cap),
    by = "Cod_partida"
  )

stopifnot("Sin quiebres calculados" = nrow(partidas_tendencia) > 0)

saveRDS(partidas_tendencia, here("RDS", "partidas_tendencia.rds"))
saveRDS(quiebres_partida,   here("RDS", "quiebres_partida.rds"))
message("✔  partidas_tendencia.rds y quiebres_partida.rds guardados.")
