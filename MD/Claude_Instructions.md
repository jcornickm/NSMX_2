Here is the complete updated Instructions document with the new section added (Section 9 — I left all existing sections intact and numbered the new one to follow Section 8):

---

# Instrucciones de trabajo — NSMX_C2

## Nearshoring en México, Capítulo 2

*Creado: mayo 2026. Actualizar cuando se adopten nuevas convenciones.*

---

## 1. Estructura de los documentos Quarto

Todo el trabajo narrativo y analítico vive en documentos `.qmd`. Los scripts `.R` se usan únicamente para experimentar antes de incorporar código a los documentos.

### YAML del documento

```yaml
---
title: "Título del documento"
author: "Jorge Cornick y Carlos Zafra, mes año"
format:
  html:
    embed-resources: true
lang: es
toc: true
toc-depth: 3
editor: source
editor_options:
  chunk_output_type: console
---
```

### Chunks de setup

El documento abre siempre con dos chunks fijos, en este orden:

```r
#| label: loadlibs
#| code-fold: true
#| code-summary: "Carga de bibliotecas"

pacman::p_load(tidyverse, here, ...)
```

```r
#| label: setup
#| include: false

source(here::here("Scripts", "funciones.R"))
```

---

## 2. Convenciones de code chunks

### Opciones obligatorias

Todo chunk visible debe tener:

```r
#| label: nombre-descriptivo   # obligatorio; usar kebab-case
#| code-fold: true             # obligatorio por defecto
#| code-summary: "Descripción breve en español"
```

### Chunks de figura

Los títulos y subtítulos van en el YAML del chunk, **no** en el código `ggplot` (`labs(title = ...)`). Esto garantiza que Quarto los renderice como captions numerados y referenciables con `@fig-`.

```r
#| label: fig-nombre-figura    # debe empezar con fig-
#| code-fold: true
#| code-summary: "Descripción"
#| fig-cap: |
#|   Título principal de la figura
#|   Subtítulo o unidad si aplica
#| fig-cap-location: top
#| fig-width: 10
#| fig-height: 6
```

### Chunks de carga de datos

Envolver en un callout colapsable para mantener el documento limpio:

```r
::: {.callout-note collapse="true" title="Carga de datos: nombre del objeto"}
```{r}
#| label: load-nombre-objeto
#| echo: false

objeto <- readRDS(here::here("RDS", "nombre.rds"))
gt_meta(meta_objeto, titulo = "Metadatos: descripción")
```
:::
```

### Chunks invisibles (limpieza, setup)

```r
#| label: nombre
#| include: false   # no aparece en el documento renderizado
```

---

## 3. Manejo de objetos temporales

### 3.1 Objetos temporales en chunks de gráficas

Los chunks que producen únicamente una figura suelen crear objetos intermedios (colores, funciones auxiliares, tibbles de etiquetas) que no se necesitan después. Envolverlos en `local({})` los destruye automáticamente al cerrar el bloque sin necesidad de `rm()` explícito.

**Patrón estándar — chunk que solo produce una figura:**

```r
local({
  col_a  <- "#457b9d"
  col_b  <- "#e63946"
  etiquetas <- tibble(...)

  p <- datos |>
    ggplot(...) +
    ...

  print(p)   # dentro de local(), ggplot requiere print() explícito
})
```

**Patrón cuando un objeto debe sobrevivir al chunk:**

```r
objeto_keeper <- local({
  # ... toda la preparación temporal ...
  objeto_keeper   # última expresión = valor de retorno
})
# Solo objeto_keeper existe en el entorno global; todo lo demás desapareció
```

### 3.2 Liberación de RDS cargados por sección

Un RDS que se carga al inicio de una sección y no se usa en el resto del documento debe liberarse explícitamente. Añadir un chunk de limpieza **después del último chunk que usa ese objeto**:

```r
#| label: cleanup-nombre-objeto
#| include: false

rm(nombre_objeto)
```

La etiqueta `cleanup-*` hace evidente el propósito. `include: false` lo mantiene invisible en el documento renderizado.

---

## 4. Tablas

### Estándar: `gt()`

Todas las tablas del proyecto usan el paquete `gt`. No usar `kable()`, `knitr::kable()` ni tablas de Markdown plano salvo para tablas muy simples en texto corrido.

**Estructura mínima:**

```r
datos |>
  gt() |>
  tab_header(
    title    = "Título de la tabla",
    subtitle = "Subtítulo o unidad"
  ) |>
  tab_source_note("Elaboración propia con base en Fuente.")
```

### Metadatos: `gt_meta()`

La función `gt_meta()` (definida en `Scripts/funciones.R`) renderiza los metadatos de un RDS como tabla `gt` dentro del callout de carga de datos. Siempre incluirla al cargar un RDS documentado:

```r
gt_meta(meta_objeto, titulo = "Metadatos: descripción del objeto")
```

---

## 5. Estilo visual

### Tema base

`theme_bw()` es el tema preferido para todos los gráficos. Se puede sustituir por `theme_minimal()` o `theme_void()` cuando la naturaleza del gráfico lo justifique (mapas, treemaps).

Ajustes habituales sobre `theme_bw()`:

```r
theme_bw() +
theme(
  legend.position  = "bottom",
  panel.grid.minor = element_blank(),
  axis.text.x      = element_text(angle = 90, vjust = 0.5)
)
```

### Paletas de color

| Situación | Paleta preferida | Código |
|---|---|---|
| Variable discreta (categorías) | Spectral | `colorRampPalette(brewer.pal(11, "Spectral"))(n)` |
| Variable discreta, sesgo frío | Opción B manual (ver abajo) | — |
| Variable continua, escala azul | Blues (distiller) | `scale_fill_distiller(palette = "Blues", direction = 1)` |
| Dos series contrastantes | Default ggplot2 o manual | `col_a <- "#00BFC4"; col_b <- "#F8766D"` |

**Paleta fría policroma (cuando Spectral tiene demasiado rojo):**

```r
mi_paleta <- colorRampPalette(c(
  "#3d405b", "#81b29a", "#f2cc8f", "#457b9d", "#2a9d8f",
  "#264653", "#e9c46a", "#a8dadc", "#6a4c93", "#48cae4"
))(n_categorias)
```

### Treemaps

- Paquete: `treemapify`
- Layout: `"squarified"`
- Separador de tiles: `color = "white", size = 0.6` (no `linewidth` — treemapify no ha adoptado el renombre de ggplot2)
- Etiquetas: `colour = "black"` para legibilidad sobre cualquier fondo
- Umbral de visibilidad: suprimir etiquetas cuando `pct < 1.8` (ajustar según densidad del gráfico)
- Facetado: `facet_wrap(~ año, nrow = 2, ncol = 2)` para series de cuatro años

### Mapas

- Paquetes: `sf`, `geodata`, `cowplot`
- Geometría base: `geodata::gadm("Mexico", level = 1, path = tempdir())`
- Proyección: dejar la proyección por defecto de GADM salvo necesidad explícita

---

## 6. Convenciones de nombres

### Objetos en R

| Tipo | Convención | Ejemplo |
|---|---|---|
| Data frame principal de una fuente | `snake_case`, sustantivo descriptivo | `imp_por_pais`, `x_ef` |
| Versión filtrada/transformada | sufijo descriptivo | `imp_chn_mex`, `xmex_pct` |
| Objeto de metadatos | prefijo `meta_` | `meta_imp_pais` |
| Paleta de colores | `mi_paleta` o nombre descriptivo | `mi_paleta`, `paleta_discreta` |
| Colores individuales | prefijo con el referente | `col_chn`, `col_mex` |

### Archivos RDS

`snake_case`, nombre descriptivo del contenido, sin año salvo que el año sea parte esencial del identificador:

```
imp_por_pais.rds
xmex_total_ef.rds
raw_all_2024.rds        ← año en el nombre solo cuando hay un archivo por año
```

### Labels de chunks

| Tipo de chunk | Prefijo | Ejemplo |
|---|---|---|
| Figura (display) | `fig-` | `fig-imp-china-mexico` |
| Guardado de figura | `save-` | `save-fig-imp-china-mexico` |
| Preparación de figura | `prep-` | `prep-fig-imp-china-mexico` |
| Carga de datos | `load-` | `load-imp-pais` |
| Limpieza de memoria | `cleanup-` | `cleanup-imp-pais` |
| Cálculo/tabla | nombre libre | `origAnualPerc` |
| Setup invisible | nombre libre | `setup`, `loadlibs` |

---

## 7. Credenciales y seguridad

Ningún token, clave de API ni contraseña se escribe directamente en el código. Toda credencial se almacena en `.Renviron` y se recupera con `Sys.getenv()`.

```r
# Al inicio de cualquier script o chunk que use APIs:
census_key  <- Sys.getenv("CENSUS_API_KEY")
dataweb_tok <- Sys.getenv("DATAWEB_TOKEN")

stopifnot("CENSUS_API_KEY no encontrado"  = nchar(census_key)  > 0)
stopifnot("DATAWEB_TOKEN no encontrado"   = nchar(dataweb_tok) > 0)
```

Para editar `.Renviron`:

```r
usethis::edit_r_environ()   # agregar KEY=valor y reiniciar R
```

| Credencial | Variable en `.Renviron` |
|---|---|
| US Census API | `CENSUS_API_KEY` |
| USITC DataWeb | `DATAWEB_TOKEN` |
| GitHub PAT | gestionado por `gitcreds` (no en `.Renviron`) |

---

## 8. Estructura de carpetas del proyecto

```
NSMX_C2/
├── Scripts/          # Scripts .R de experimentación y funciones auxiliares
│   └── funciones.R   # Funciones compartidas (gt_meta, etc.)
├── RDS/              # Datos serializados
│   ├── raw/          # Descargas crudas sin procesar
│   └── *.rds         # Objetos limpios listos para análisis
├── Quarto/           # Documentos .qmd (narrativa + análisis)
├── Figuras/          # Gráficos exportados (.pdf para diseñador, .png para Quarto)
└── Excel/            # Archivos .xlsx de fuentes externas
```

---

## 9. Separación de preparación y visualización

### Principio fundamental

El documento Quarto **no calcula ni transforma datos**: solo carga objetos pre-computados y los muestra. Esta separación es obligatoria a todos los niveles.

| Responsabilidad | Dónde vive |
|---|---|
| Descarga, limpieza, transformación, cálculos | Script `.R` → guarda `.rds` |
| Preparación específica de una figura (paletas, etiquetas, filtros finales) | Chunk `prep-` en el `.qmd`, con `#| include: false` |
| Renderizado del gráfico y `ggsave()` | Chunk `save-`, con `#| eval: false` una vez validado |
| Visualización en el documento | Chunk `fig-` con `knitr::include_graphics()` |

### Patrón estándar para cada figura

```r
# 1. Chunk de prep — filtra, construye etiquetas, define colores
#| label: prep-fig-nombre
#| include: false

datos_fig <- objeto_rds |> filter(...) |> mutate(...)
col_a     <- "#457b9d"
```

```r
# 2. Chunk de guardado — eval: false una vez que la figura está validada
#| label: save-fig-nombre
#| eval: false

p <- datos_fig |>
  ggplot(...) + ...

ggsave(here::here("Figuras", "nombre.pdf"), plot = p,
       width = 10, height = 6, device = cairo_pdf)
ggsave(here::here("Figuras", "nombre.png"), plot = p,
       width = 10, height = 6, dpi = 150)
```

```r
# 3. Chunk de display — lo único que Quarto ejecuta en cada render
#| label: fig-nombre
#| echo: false
#| fig-cap: "Título de la figura"
#| fig-cap-location: top

knitr::include_graphics(here::here("Figuras", "nombre.png"))
```

### Guardado en dos formatos

Cada figura se guarda siempre en dos formatos:

| Formato | Destinatario | Razón |
|---|---|---|
| `.pdf` (`cairo_pdf`) | Diseñador gráfico | Vector: escala sin pérdida, sin decisión de DPI |
| `.png` (150 dpi) | Documento Quarto (HTML) | Los navegadores no renderizan PDF inline |

**Sobre `cairo_pdf`:** usar siempre como `device` al guardar PDF. El dispositivo PDF por defecto puede maltratar caracteres especiales (tildes, ñ) y algunas fuentes de ggplot2.

### Secuencia de trabajo por figura

1. Confirmar que los datos necesarios existen como `.rds`
2. Escribir el chunk `prep-` y verificar que el objeto resultante es correcto
3. Escribir el chunk `save-` y renderizar para validar la figura visualmente
4. Ejecutar `ggsave()` para guardar `.pdf` y `.png`
5. Establecer `#| eval: false` en el chunk `save-`
6. Agregar el chunk `fig-` con `knitr::include_graphics()`
7. Renderizar el documento completo para confirmar que todo encaja

---

*Actualizado: mayo 2026*