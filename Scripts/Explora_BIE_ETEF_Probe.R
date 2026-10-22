# Explora_BIE_ETEF_Probe.R   ####
# Sondeo de UNA clave de subsector (6207095715, la de la prueba vieja) con
# distintas combinaciones de banco (BISE / BIE) y código geográfico, para
# averiguar cómo pedir un subsector por entidad. No guarda nada.
#
# Hipótesis: los subsectores por entidad solo están en el banco BIE, donde
# los códigos de área no son "01", "05" sino otros (p. ej. "0700" nacional).

pacman::p_load(httr2, jsonlite, tidyverse)

bie_token <- Sys.getenv("BIE_TOKEN")
stopifnot("BIE_TOKEN no encontrado" = nchar(bie_token) > 0)

CLAVE <- "6207095715"

sondeo <- function(banco, geo, clave = CLAVE) {
  Sys.sleep(0.2)
  url <- paste0(
    "https://www.inegi.org.mx/app/api/indicadores/desarrolladores/jsonxml/",
    "INDICATOR/", clave, "/es/", geo, "/false/", banco, "/2.0/", bie_token,
    "?type=json"
  )
  resp <- tryCatch(
    request(url) |> req_error(is_error = \(r) FALSE) |> req_perform(),
    error = \(e) NULL
  )
  if (is.null(resp)) return(tibble(banco, geo, status = NA_integer_, n = NA_integer_,
                                   ultimo = NA_character_, valor = NA_real_, cobertura = NA_character_))
  st <- resp_status(resp)
  if (st >= 400) return(tibble(banco, geo, status = st, n = 0L,
                               ultimo = NA_character_, valor = NA_real_, cobertura = NA_character_))
  
  raw <- resp_body_string(resp) |> fromJSON(simplifyVector = FALSE)
  obs <- raw$Series[[1]]$OBSERVATIONS
  n   <- length(obs)
  periodos <- if (n > 0) map_chr(obs, "TIME_PERIOD") else character(0)
  ult <- if (n > 0) obs[[which(periodos == max(periodos))[1]]] else NULL
  tibble(
    banco = banco, geo = geo, status = st, n = n,
    ultimo    = if (n > 0) ult$TIME_PERIOD else NA_character_,
    valor     = if (n > 0) suppressWarnings(as.numeric(ult$OBS_VALUE)) else NA_real_,
    cobertura = if (n > 0) as.character(ult$COBER_GEO) else NA_character_
  )
}

combos <- expand_grid(
  banco = c("BISE", "BIE"),
  geo   = c("00", "0700", "01", "05", "07000001", "07000005", "0700001", "0700005", "010000", "050000")
)

cat("Sondeando clave", CLAVE, "(", nrow(combos), "combinaciones )\n")
resultado <- pmap_dfr(combos, \(banco, geo) sondeo(banco, geo))

print(resultado, n = Inf, width = 120)

cat("\nLectura:\n",
    "- status 200 y n > 0: esa combinación (banco, geo) responde.\n",
    "- Compara 'cobertura' y 'valor': la entidad correcta debe dar un valor chico\n",
    "  (el nacional de este subsector ronda 56,000,000 por trimestre).\n", sep = "")
