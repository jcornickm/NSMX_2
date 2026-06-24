Here is the updated Entorno file. I cleaned up a few things along the way (the stale YAML header, the garbled first line, the unconfirmed Census variable name which is now confirmed as `CENSUS_API_KEY`, the typo in the date), and added Section 8 as we discussed:

---

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
  sf, geodata, cowplot, treemapify
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

El nombre del archivo de figura coincide con el label del chunk de display, sustituyendo el prefijo `fig-` por snake_case:

```
chunk label:  fig-imp-china-mexico
archivo PDF:  Figuras/imp_china_mexico.pdf
archivo PNG:  Figuras/imp_china_mexico.png
```

### Carpeta `Figuras/`

Contiene únicamente archivos finales validados (`.pdf` + `.png` por figura). No se guardan borradores ni versiones intermedias en esta carpeta.

---

*Actualizado: mayo 2026*