# Entorno de Cómputo — NSMX_C2

## Nearshoring en México, Capítulo 2

---

## 1. Hardware

| Atributo | Detalle |
|---|---|
| Equipo | Microsoft Surface Laptop |
| Procesador | Snapdragon X12-core X1E80100 @ 3.4 GHz (arquitectura ARM) |
| GPU | Qualcomm Adreno X1-85, 128 MB |
| RAM | 64 GB |
| Almacenamiento | 954 GB |

> ⚠️ **Nota ARM:** El chip Snapdragon usa arquitectura ARM. La mayoría de los paquetes de R funcionan sin problema, pero ocasionalmente es necesario instalar binarios desde la Consola o Terminal. Documentar aquí si algún paquete del proyecto requiere instalación especial.

---

## 2. Software

| Componente | Versión / Detalle |
|---|---|
| Sistema operativo | Windows (ARM) |
| R | 4.5.2 |
| RStudio Desktop | 2026.01.1 Build 403 |
| Posit Cloud | Espejo del proyecto vía GitHub |
| Quarto | Integrado en RStudio; renderiza correctamente en Desktop y en Posit Cloud |

---

## 3. Flujo de trabajo y control de versiones

El trabajo se realiza exclusivamente en Posit Cloud. El proyecto en Cloud está sincronizado con RStudio Desktop, pero esto sirve fundamentalmente para tener una copia local de todos los documentos. Ambos entornos comparten el mismo nombre (`NSMX_C2`).

---

## 4. Documentos y scripts

- Todo el trabajo se organiza en documentos **Quarto** (`.qmd`), integrando código y narrativa.
- Los **scripts** (`.R`) se usan únicamente para experimentar con código antes de incorporarlo a los documentos.
- No se usa `renv` para este proyecto. Para proyectos individuales y de alcance definido, la complejidad adicional no está justificada. *Revisar esta decisión si el proyecto escala o incorpora colaboradores.*

---

## 5. Paquetes principales

```r
pacman::p_load(
  httr, jsonlite, forcats, zoo, tidyverse, readxl,
  here, janitor, stringr, gt, seasonal, glue,
  sf, geodata, cowplot, treemapify, patchwork, WDI
)
```

`pacman::p_load()` instala el paquete si no está disponible y lo carga; elimina la necesidad de llamadas separadas a `install.packages()` y `library()`.

---

## 6. Credenciales y tokens de acceso

| Servicio | Almacenamiento | Variable en `.Renviron` |
|---|---|---|
| US Census API | `.Renviron` | `CENSUS_API_KEY` |
| USITC DataWeb | `.Renviron` | `DATAWEB_TOKEN` |
| INEGI BIE | `.Renviron` | `BIE_TOKEN` |
| GitHub PAT | `gitcreds` (gestor de credenciales del sistema Windows) | — |

**Recuperar el token de GitHub en cualquier momento:**

```r
gitcreds::gitcreds_get()
```

**Verificar tokens de API:**

```r
Sys.getenv("CENSUS_API_KEY")
Sys.getenv("DATAWEB_TOKEN")
Sys.getenv("BIE_TOKEN")
```

> 🔒 **Regla:** ningún token se escribe directamente en código. Siempre se accede vía `Sys.getenv()` o `gitcreds`.

---

## 7. Herramientas de IA y referencias

| Herramienta | Uso |
|---|---|
| Claude Pro | Asistencia principal de código y redacción |
| Gemini Pro | Consultas adicionales |
| Microsoft Copilot | Consultas adicionales |
| Elicit (versión gratuita) | Búsqueda y síntesis de literatura académica |
| Zotero (desktop + web) | Gestión de referencias bibliográficas |

---

## 8. Flujo de salida: figuras y entrega editorial

Este proyecto produce figuras para una publicación académica con cadena editorial tradicional: autor → editor de texto → diseñador gráfico.

### Formatos de salida por destinatario

| Destinatario | Formato | Razón |
|---|---|---|
| Documento Quarto (HTML) | `.png`, 150 dpi | Los navegadores no renderizan PDF inline |
| Diseñador gráfico | `.pdf` (`cairo_pdf`) | Vector: escala sin pérdida de calidad, sin decisión de DPI |
| Editor de texto | Solo narrativa | No recibe archivos de datos ni código |

### Convención de nombres de archivo

El nombre del archivo de figura coincide con el label del chunk de display:

```
chunk label:  fig-imp-china-mexico
archivo PDF:  Plots/fig-imp-china-mexico.pdf
archivo PNG:  Plots/fig-imp-china-mexico.png
```

### Carpeta `Plots/`

Contiene únicamente archivos finales validados (`.pdf` + `.png` por figura). No se guardan borradores ni versiones intermedias en esta carpeta.

> ⚠️ **Nota:** La carpeta de salida es `Plots/`, no `Figuras/` ni `Images/`. Todas las llamadas a `ggsave()` y `knitr::include_graphics()` deben usar `here::here("Plots", ...)`.

---

## 9. Convenciones de figura: tamaño y control de dimensiones

### Fuente de verdad para dimensiones

En el patrón `prep-` / `save-` / `fig-`, la **única fuente de verdad para el tamaño físico** de una figura es el chunk `save-` (los argumentos `width` y `height` de `ggsave()`). Las opciones `fig-width` y `fig-height` en el chunk `fig-` no tienen efecto sobre un `knitr::include_graphics()` — son ignoradas silenciosamente.

**Regla práctica:** el chunk `fig-` solo necesita `out.width: "100%"` para forzar ancho completo. Nunca agregar `fig-width` o `fig-height` ahí.

```r
#| label: fig-nombre
#| echo: false
#| fig-cap: "Título de la figura"
#| fig-cap-location: top
#| out.width: "100%"

knitr::include_graphics(here::here("Plots", "fig-nombre.png"))
```

### Labels de chunk duplicados

Si una figura aparece estrecha aunque `ggsave()` usa las dimensiones correctas, verificar que no existan **dos chunks con el mismo label** en el documento. Quarto se comporta de forma impredecible con labels duplicados — puede ejecutar opciones YAML del chunk incorrecto. Solución: renombrar o eliminar el chunk legacy.

### Convención de escala del eje X

**Norma de proyecto:** mostrar todos los años disponibles en el eje X, impresos horizontalmente.

```r
scale_x_continuous(breaks = seq(año_inicio, año_fin, by = 1)) +
theme(axis.text.x = element_text(angle = 0))
```

---

## 10. Estructuras de datos clave

### `imp_mex_top_hs4` — Importaciones EUA desde México, top partidas

- **Origen:** pipeline Query04; filtrado al 80% del valor por capítulo (top partidas que acumulan el 80%)
- **Consecuencia del filtro:** el 20% restante de cada capítulo queda excluido. Al construir tablas de partidas, agregar siempre una fila "Resto" que represente ese 20%.
- **Total de referencia:** el escalar `total_gral_2025` proviene de `impMex` (todas las secciones), **no** de `imp_mex_top_hs4`.
- **Fórmula de `pct_total`** para partidas: `(total_cap_2025 / total_gral_2025) * pct_cap`, donde `total_cap_2025` es el total del capítulo en `impMex` y `pct_cap` es la participación de la partida dentro de su capítulo.

### `ied_por_actividad` — IED por sector económico (SCIAN)

- Datos trimestrales; agregar con `sum()` por año para obtener totales anuales.
- El sector manufacturero "31-33" aparece en el Excel como "31-33 Industrias manufactureras". El parser de Query13 aplica `str_extract(actividad, "^\\d+")`, extrayendo `"31"` con `nchar == 2` → `nivel = "sector"`. Filtro correcto: `codigo_scian == "31" & nivel == "sector"`.
- IED negativa (desinversión) es posible. En gráficos de participación porcentual, truncar con `pmax(ied_mdd, 0)` antes de calcular proporciones y documentarlo explícitamente en el `fig-cap`.

### RDS de IED

Los cinco RDS producidos por `Query13_IED.R`:

| Archivo | Contenido |
|---|---|
| `ied_por_origen.rds` | IED trimestral por país de origen |
| `ied_por_actividad.rds` | IED trimestral por sector SCIAN |
| `ied_pib.rds` | IED como % del PIB (anual y trimestral) |
| `ied_fbkf.rds` | IED como % de la FBKF (anual y trimestral) |
| `meta_ied.rds` | Metadatos del bloque IED |

`ied_flujos_tipo.rds` existe pero no se usa en la versión actual del documento.

---

## 11. Quarto: problemas conocidos y soluciones

### URLs en texto narrativo

Las URLs desnudas en texto narrativo Quarto pueden causar crash del renderizador (error de Pandoc en el parser de autolinks). **Solución:** usar siempre corchetes angulares:

```markdown
<https://ejemplo.com/ruta/larga>
```

No usar URL desnuda ni el truco de envolverla en `*cursiva*`.

### YAML de autor con afiliaciones

Los campos `affiliations:` y `corresponding:` en el bloque `author:` del YAML son características del pipeline de manuscritos de Quarto. En salida HTML estándar pueden causar crash silencioso del renderizador. Para HTML, usar solo `name:` y `email:` en el bloque `author:`, y poner afiliaciones en un subtítulo o párrafo introductorio.

### Tablas `gt()` en Posit Cloud Viewer

Agregar a `.Rprofile`:
```r
options(viewer = NULL)
```
Y activar "Chunk Output in Console" para evitar que el Viewer pane se expanda y cubra la interfaz al renderizar tablas `gt()`.

---

## 12. Convenciones de estilo de figuras

### Tema base

`theme_bw()` para todos los gráficos. Excepciones justificadas: `theme_minimal()` o `theme_void()` para mapas y treemaps.

### Escala de ejes X: norma

Todos los años disponibles, texto horizontal:
```r
scale_x_continuous(breaks = seq(año_inicio, año_fin, by = 1)) +
theme(axis.text.x = element_text(angle = 0))
```

### Arreglos multipanel

Usar `patchwork` para arreglos verticales u horizontales:
```r
p1 / p2          # arreglo 2×1 (vertical)
p1 | p2          # arreglo 1×2 (horizontal)
p1 / p2 + plot_layout(heights = c(1, 1))  # con control de proporciones
```

El objeto `p` que se pasa a `ggsave()` es el resultado de `p1 / p2`, no de `local({})` — el `local({})` devuelve el arreglo completo como última expresión.

### Barras apiladas al 100%

- Usar `position = "stack"` (no `"fill"`) para que `geom_text` con `position_stack(vjust = 0.5)` centre las etiquetas correctamente.
- Calcular `pct` manualmente antes del ggplot para tener control sobre el formato de etiquetas.
- Si hay valores negativos, truncar con `pmax(valor, 0)` antes de calcular proporciones y documentarlo en `fig-cap`.

### Tablas `gt()`: estilo preferido

El estilo de tabla preferido para el documento es **minimalista**, consistente con el estilo de las tablas de metadatos:
- Sin rellenos de color de fondo
- Jerarquía expresada mediante `cell_text()`: negrita para totales/secciones, cursiva gris para subtotales
- Separadores sutiles (`grey70` / `grey85`, 1–1.5 px)
- Striping suave: `opt_row_striping()` con `#f8f8f8`
- Header blanco, bordes `hidden` arriba y abajo
- `opt_table_font(font = google_font("IBM Plex Sans"))`

---

*Actualizado: 21 de mayo de 2026*