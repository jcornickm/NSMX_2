# funciones_datos.R   ####
# Helpers para DESCARGAR y ACTUALIZAR datos que vienen de APIs.
#
# Se mantienen aparte de funciones.R (etiquetas del SA, ajuste estacional,
# paleta de TCAC), que sí se carga desde los qmd: los qmd no necesitan nada de
# lo que hay aquí. Uso en un Query:
#   source(here::here("Scripts", "funciones_datos.R"))
#
# Estrategia (para no repetir toda la historia en cada actualización):
#   1. Se descarga SOLO desde un año de solape (p. ej. 2023) hasta el último mes
#      disponible, un año por archivo, guardando cada año en RDS/raw/ apenas se
#      obtiene (si una descarga larga se cae, no se pierde lo ya bajado).
#   2. actualizar_rds() reemplaza en el RDS existente todo lo que cae desde el
#      año de solape por lo nuevo, y reporta cuánto cambió lo ya publicado
#      (Census revisa los años recientes).
#
# Funciones:
#   census_ultimo_mes()       último mes con datos en el API de Census
#   census_descargar()        una descarga (con caché en disco y reintentos)
#   census_descargar_anios()  varias descargas, una por año, y las une
#   actualizar_rds()          une datos viejos y nuevos y reporta revisiones

pacman::p_load(tidyverse, here, lubridate, censusapi, httr)

CENSUS_IMPORTS <- "timeseries/intltrade/imports/hs"


# ── census_ultimo_mes() ───────────────────────────────────────────────────────
# Devuelve el último mes con datos publicados ("AAAA-MM") para el año dado, o NA
# si todavía no hay ninguno. Prueba mes por mes hacia atrás (una fila por
# llamada: México, total sin desagregar).
census_ultimo_mes <- function(anio    = lubridate::year(Sys.Date()),
                              name    = CENSUS_IMPORTS,
                              api_key = Sys.getenv("CENSUS_API_KEY")) {
  stopifnot("CENSUS_API_KEY no encontrada en .Renviron" = nchar(api_key) > 0)
  m_max <- if (anio < lubridate::year(Sys.Date())) 12L else lubridate::month(Sys.Date())
  for (m in m_max:1) {
    tiempo <- sprintf("%d-%02d", anio, m)
    r <- tryCatch(
      censusapi::getCensus(name = name, vars = "GEN_VAL_MO", time = tiempo,
                           key = api_key, CTY_CODE = "2010"),
      error = function(e) NULL
    )
    if (!is.null(r) && nrow(r) > 0) return(tiempo)
  }
  NA_character_
}


# ── census_descargar() ────────────────────────────────────────────────────────
# Una descarga: variables `vars`, del mes `desde` al mes `hasta` ("AAAA-MM"),
# con `filtros` opcionales (p. ej. list(CTY_CODE = "2010")).
#   - Guarda el resultado en `archivo` apenas lo recibe.
#   - Si `archivo` ya existe y tiene menos de `max_edad_horas` horas, lo lee en
#     vez de descargar (Inf = usar siempre el archivo). Para años que Census
#     puede haber revisado, usar un valor finito (p. ej. 12): reanuda tras una
#     caída el mismo día, pero al día siguiente vuelve a descargar.
#   - Reintenta `intentos` veces (reiniciando la sesión HTTP) antes de rendirse.
# Devuelve un tibble, o NULL si falló.
census_descargar <- function(vars, desde, hasta, archivo,
                             filtros        = list(),
                             max_edad_horas = Inf,
                             intentos       = 3,
                             pausa          = 10,
                             name           = CENSUS_IMPORTS,
                             api_key        = Sys.getenv("CENSUS_API_KEY")) {
  stopifnot("CENSUS_API_KEY no encontrada en .Renviron" = nchar(api_key) > 0)

  if (file.exists(archivo)) {
    edad <- as.numeric(difftime(Sys.time(), file.mtime(archivo), units = "hours"))
    if (edad <= max_edad_horas) {
      message("  (archivo existente) ", basename(archivo))
      return(readRDS(archivo))
    }
  }

  for (i in seq_len(intentos)) {
    httr::handle_reset("https://api.census.gov")
    res <- tryCatch(
      do.call(censusapi::getCensus,
              c(list(name = name, vars = vars,
                     time = paste0("from ", desde, " to ", hasta),
                     key  = api_key),
                filtros)),
      error = function(e) {
        message("  ERROR (intento ", i, "/", intentos, "): ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(res) && nrow(res) > 0) {
      res <- tibble::as_tibble(res)
      dir.create(dirname(archivo), showWarnings = FALSE, recursive = TRUE)
      saveRDS(res, archivo)
      message("  Guardado: ", basename(archivo), " (", nrow(res), " filas)")
      return(res)
    }
    if (i < intentos) {
      message("  Reintentando en ", pausa, " segundos...")
      Sys.sleep(pausa)
    }
  }
  NULL
}


# ── census_descargar_anios() ──────────────────────────────────────────────────
# Una descarga por año (enero–diciembre) y las une. Cada año se guarda en
# RDS/raw/<prefijo>_<año>.rds. El año en curso se baja solo hasta
# `mes_fin_actual` (resultado de census_ultimo_mes()); si es NA, se omite.
# Si algún año falla, se detiene indicando cuáles; los años ya bajados quedan
# guardados y se reutilizan al volver a correr (ver max_edad_horas).
census_descargar_anios <- function(prefijo, anios, vars,
                                   filtros        = list(),
                                   mes_fin_actual = NA_character_,
                                   max_edad_horas = Inf,
                                   ...) {
  anio_actual <- lubridate::year(Sys.Date())
  piezas <- map(anios, \(a) {
    hasta <- if (a == anio_actual) mes_fin_actual else sprintf("%d-12", a)
    if (is.na(hasta)) return(tibble())   # año en curso sin datos todavía
    census_descargar(
      vars = vars, desde = sprintf("%d-01", a), hasta = hasta,
      archivo = here::here("RDS", "raw", sprintf("%s_%d.rds", prefijo, a)),
      filtros = filtros, max_edad_horas = max_edad_horas, ...
    )
  })
  fallos <- anios[map_lgl(piezas, is.null)]
  if (length(fallos) > 0)
    stop("Fallaron los años: ", paste(fallos, collapse = ", "),
         ". Los demás quedaron guardados en RDS/raw/; vuelve a correr el script.")
  bind_rows(piezas)
}


# ── actualizar_rds() ──────────────────────────────────────────────────────────
# Une datos viejos con datos nuevos que se solapan, y reporta las revisiones.
#   viejo   data frame existente (el contenido actual del RDS)
#   nuevo   data frame recién descargado, con las MISMAS columnas, que empieza en
#           `desde` y llega hasta el último mes disponible
#   llaves  columnas que identifican una fila además de `fecha` (p. ej. "CTY_CODE";
#           character(0) si la fila se identifica solo por fecha)
#   valor   columna numérica cuyas revisiones se reportan
#   desde   primer mes que se reemplaza (Date o "AAAA-MM-DD")
# Todo lo de `viejo` desde `desde` se descarta y se sustituye por `nuevo`;
# lo anterior a `desde` no se toca. Se detiene si `nuevo` tiene duplicados,
# meses faltantes, otras columnas, o si hay un hueco entre viejo y nuevo.
# Devuelve list(datos = <datos unidos>, revision = <tabla por año>).
actualizar_rds <- function(viejo, nuevo, llaves, valor, desde,
                           tol = 0.5, nombre = "datos") {
  desde    <- as.Date(desde)
  llaves_f <- c(llaves, "fecha")

  if (!setequal(names(viejo), names(nuevo)))
    stop("viejo y nuevo tienen columnas distintas: ",
         paste(setdiff(union(names(viejo), names(nuevo)),
                       intersect(names(viejo), names(nuevo))), collapse = ", "))

  nuevo <- nuevo |> filter(fecha >= desde)
  if (nrow(nuevo) == 0 || min(nuevo$fecha) > desde)
    stop("'nuevo' no cubre el mes de inicio ", format(desde))
  if (anyDuplicated(nuevo[llaves_f]) > 0)
    stop("'nuevo' tiene filas duplicadas para las llaves: ", paste(llaves_f, collapse = ", "))

  meses_esperados <- seq(desde, max(nuevo$fecha), by = "month")
  faltan <- setdiff(as.character(meses_esperados), as.character(unique(nuevo$fecha)))
  if (length(faltan) > 0)
    stop("Meses faltantes en 'nuevo': ", paste(faltan, collapse = ", "))

  previo <- viejo |> filter(fecha < desde)
  mes_anterior <- seq(desde, by = "-1 month", length.out = 2)[2]
  if (nrow(previo) == 0 || max(previo$fecha) != mes_anterior)
    stop("Hueco entre 'viejo' (último mes antes de ", format(desde), ": ",
         if (nrow(previo) > 0) format(max(previo$fecha)) else "ninguno",
         ") y 'nuevo'.")

  # — Revisión: valores ya publicados vs. valores nuevos, en el solape ----------
  a <- viejo |> filter(fecha >= desde) |> select(all_of(llaves_f), viejo = all_of(valor))
  b <- nuevo |> select(all_of(llaves_f), nuevo = all_of(valor))
  revision <- full_join(a, b, by = llaves_f) |>
    mutate(
      año    = lubridate::year(fecha),
      estado = case_when(
        is.na(viejo)             ~ "nueva",
        is.na(nuevo)             ~ "desaparece",
        abs(nuevo - viejo) > tol ~ "revisada",
        TRUE                     ~ "igual"
      )
    ) |>
    group_by(año) |>
    summarise(
      filas        = n(),
      nuevas       = sum(estado == "nueva"),
      desaparecen  = sum(estado == "desaparece"),
      revisadas    = sum(estado == "revisada"),
      suma_vieja   = sum(viejo[!is.na(nuevo)], na.rm = TRUE),
      suma_nueva   = sum(nuevo[!is.na(viejo)], na.rm = TRUE),
      dif_pct      = if_else(suma_vieja == 0, NA_real_, (suma_nueva / suma_vieja - 1) * 100),
      .groups = "drop"
    )

  message("\n=== Revisión de ", nombre, " (", valor, ") desde ", format(desde), " ===")
  print(revision, n = Inf)

  datos <- bind_rows(previo, nuevo)[names(viejo)] |>
    arrange(across(all_of(llaves_f)))

  list(datos = datos, revision = revision)
}
