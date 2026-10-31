# Diagnóstico de un .docx que Word no abre.
# Revisa: (1) XML bien formado en cada parte, (2) caracteres inválidos en XML 1.0,
# (3) IDs duplicados de bookmarks y de drawings (docPr), (4) relaciones rotas,
# (5) tablas sin tblGrid / sin filas.

pacman::p_load(xml2, here, stringr, purrr, dplyr)

docx <- here::here("Quarto", "C3_Tiempos_turbulentos_v2.docx")
tmp  <- file.path(tempdir(), "docx_check")
unlink(tmp, recursive = TRUE)
unzip(docx, exdir = tmp)

partes <- list.files(tmp, pattern = "\\.(xml|rels)$", recursive = TRUE,
                     full.names = TRUE, all.files = TRUE)

# 1-2. Bien formado + caracteres ilegales
chequeo <- map_dfr(partes, function(f) {
  raw <- readBin(f, "raw", file.size(f))
  txt <- rawToChar(raw)
  ilegales <- str_count(txt, "[\\x01-\\x08\\x0B\\x0C\\x0E-\\x1F]")
  ok <- tryCatch({ read_xml(f); "ok" }, error = function(e) conditionMessage(e))
  tibble(parte = sub(paste0(tmp, "/"), "", f, fixed = TRUE),
         xml = ok, ilegales = ilegales)
})
cat("\n== Partes con problemas de XML o caracteres ilegales ==\n")
print(filter(chequeo, xml != "ok" | ilegales > 0))

# 3. IDs duplicados
doc <- read_xml(file.path(tmp, "word", "document.xml"))
ns  <- xml_ns(doc)

bm <- xml_find_all(doc, "//w:bookmarkStart", ns)
bm_tbl <- tibble(id = xml_attr(bm, "id"), name = xml_attr(bm, "name"))
cat("\n== Bookmarks con id o nombre duplicado ==\n")
print(bm_tbl |> filter(duplicated(id) | duplicated(id, fromLast = TRUE) |
                       duplicated(name) | duplicated(name, fromLast = TRUE)))

dp <- xml_find_all(doc, "//wp:docPr", ns)
dp_tbl <- tibble(id = xml_attr(dp, "id"), name = xml_attr(dp, "name"))
cat("\n== docPr (dibujos) con id duplicado ==\n")
print(dp_tbl |> filter(duplicated(id) | duplicated(id, fromLast = TRUE)))

# 4. Relaciones rotas (r:embed / r:id sin entrada en document.xml.rels)
rels <- read_xml(file.path(tmp, "word", "_rels", "document.xml.rels"))
rel_ids <- xml_attr(xml_find_all(rels, "//*[local-name()='Relationship']"), "Id")
usados <- c(xml_attr(xml_find_all(doc, "//@r:embed", ns), "embed"),
            xml_attr(xml_find_all(doc, "//@r:id",    ns), "id"))
cat("\n== r:id/r:embed sin relación ==\n")
print(setdiff(na.omit(usados), rel_ids))

# 5. Tablas
tb <- xml_find_all(doc, "//w:tbl", ns)
cat("\n== Tablas:", length(tb), "==\n")
walk2(tb, seq_along(tb), function(t, i) {
  cat(sprintf("tabla %d: tblGrid=%d, filas=%d\n", i,
              length(xml_find_all(t, "./w:tblGrid", ns)),
              length(xml_find_all(t, "./w:tr", ns))))
})

# 6. Footnotes: ids referenciados vs definidos
fn_def <- tryCatch({
  fn <- read_xml(file.path(tmp, "word", "footnotes.xml"))
  xml_attr(xml_find_all(fn, "//w:footnote", xml_ns(fn)), "id")
}, error = function(e) character())
fn_ref <- xml_attr(xml_find_all(doc, "//w:footnoteReference", ns), "id")
cat("\n== Footnotes referenciadas sin definición ==\n")
print(setdiff(fn_ref, fn_def))
