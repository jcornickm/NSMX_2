# NSMX_C2: Nearshoring en México — Capítulo 2
## Plan de Trabajo

---

## 1. Contexto del capítulo

La Escuela de Gobierno y Transformación Pública del TEC de Monterrey está preparando una publicación *flagship* sobre nearshoring en México. El Capítulo 2, titulado **"Nearshoring en los datos"**, tiene como objetivo principal la construcción, descripción y visualización de las estadísticas relevantes. Aunque el énfasis es en estadística descriptiva, se incluirá un recuadro con los resultados de los estudios econométricos disponibles (ver Recuadro 1).

**Índice general de la publicación:**

1. Introducción al NS en México
2. NS: evidencia estadística y econométrica ← *este capítulo*
3. Perspectivas del sector privado (estudios de casos)
4. Agua y NS
5. Energía y NS
6. Sector de semiconductores
7. Crecimiento verde
8. IED China en México

---

## 2. Entorno de cómputo

### 2.1 Herramientas

- **IDE:** RStudio Desktop y Posit Cloud (proyectos con el mismo nombre: `NSMX_C2`)
- **Lenguaje:** R, con marco de trabajo tidyverse
- **Visualización:** `ggplot2` (gráficos), `gt` (tablas)
- **Formato de salida:** HTML y Word, renderizado desde Quarto, en Posit Cloud

### 2.2 Paquetes principales

```r
pacman::p_load(
  httr, jsonlite, forcats, zoo, tidyverse, readxl,
  here, janitor, stringr, gt
)
```

### 2.3 Funciones personalizadas

Las funciones personalizadas del archivo `.Rprofile` se documentan por separado, en un archivo dedicado al entorno de cómputo del proyecto. No se incluyen aquí.

---

## 3. Estructura de archivos del proyecto

| Archivo | Contenido |
|---|---|
| `01_datos.qmd` | Extracción, procesamiento y almacenamiento de datos en formato `.rds` |
| `02_visualizaciones.qmd` | Generación de visualizaciones (ggplot2) y tablas (gt); base para la redacción del capítulo |
| `NSMX_C2_Plan.md` | Este documento |
| *(archivo separado)* | Descripción del entorno de cómputo y funciones personalizadas |

### Convención de nombres para archivos `.rds`

```
datos_[fuente]_[descriptor].rds
```

Ejemplos: `datos_uscensus_importaciones.rds`, `datos_inegi_efet.rds`, `datos_se_ied.rds`

### Estructura de los objetos de datos

Cada base de datos se almacenará en un objeto de clase `list` con dos elementos:

```r
list(
  datos    = <tibble con los datos>,
  metadata = <lista o tibble con metadatos: fuente, fecha de descarga, URL, notas>
)
```

El elemento `datos` se puede guardar y recuperar de forma independiente como `.rds`.

---

## 4. Fuentes de datos y justificación

### 4.1 Importaciones de EUA por país de origen

- **Fuente principal:** `usatrade.census.gov` o `dataweb.usitc.gov`

### 4.2 Exportaciones de México a EUA

- **Fuente principal:** `usatrade.census.gov`
- **Fuente de contraste:** Base de Comercio con el Mundo (BCCM) de la Secretaría de Economía, accesible vía [Data México](https://www.economia.gob.mx/datamexico)

**Razón para preferir usatrade.census.gov:** En Data México, la suma de los datos desagregados (a cualquier nivel: Sección, Capítulo o Partida) difiere sustancialmente del dato del nivel agregado superior. Por ejemplo, la suma de exportaciones por Sección representa aproximadamente el 25 % del total de exportaciones reportado. Los datos de Data México se usarán únicamente como contraste.

### 4.3 Exportaciones por Entidad Federativa

- **Fuente:** Base de datos EFET del INEGI

**Tarea previa al inicio de la codificación:** Verificar si la base EFET usa el sistema de clasificación SA (Sistema Armonizado) o SCIAN. Esto determina la estrategia de cruce con las demás bases de datos.

### 4.4 Inversión Extranjera Directa (IED)

- **Fuente:** Censos Económicos del INEGI 2018 y 2023 (clasificación SCIAN)

### 4.5 Empleo en el régimen IMMEX

- **Fuente:** INEGI / Secretaría de Economía
- **Desagregación:** Sector y Entidad Federativa (Estados y Municipios)
- **Nota:** Se calcularán también los datos para la Zona Libre de la Frontera Norte (ZLFN).  
  ⚠️ **Dependencia pendiente:** El listado de municipios que integran la ZLFN será proporcionado posteriormente. La sección de empleo IMMEX no puede completarse hasta contar con ese listado.

---

## 5. Índice del capítulo y tareas de datos

### 5.1 Evolución de las importaciones de bienes de EUA, por país de origen (2010–2025)

**Fuente:** `usatrade.census.gov` o `dataweb.usitc.gov`

**Metodología para selección de orígenes:**
- Identificar los **20 países de origen más importantes**, medidos por **valor de importaciones**, usando datos de 2024 y 2025 en conjunto.
- Agrupar todos los demás orígenes bajo la categoría **"Otros"**.
- Como referencia o contraste, se puede consultar [oec.world](https://oec.world) para validar el ranking de orígenes en 2024.

---

### 5.2 Exportaciones de México a Estados Unidos

#### 5.2.1 Exportaciones totales

#### 5.2.2 Exportaciones por Sección del SA

Las secciones de interés principal son:

| Sección | Nombre corto |
|---|---|
| XVI | Maquinaria |
| XVII | Transporte |
| XVIII | Instrumentos |

*(Se utilizarán los nombres oficiales completos en el texto del capítulo; los nombres cortos son referencias de trabajo.)*

#### 5.2.3 Exportaciones por Capítulo del SA (Secciones XVI, XVII y XVIII)

#### 5.2.4 Exportaciones por Partida del SA

Solo se desagregarán a nivel de Partida los Capítulos de mayor peso dentro de sus respectivas Secciones. La selección de Capítulos se realizará una vez examinada la distribución de exportaciones por Capítulo.

---

### Recuadro 1: La evidencia econométrica

Se incluirá un recuadro que sintetice los resultados de los estudios econométricos disponibles sobre el impacto de los aranceles impuestos por EUA a las importaciones provenientes de China en 2018, y sus efectos sobre el nearshoring en México.

*Este recuadro es de contenido editorial (síntesis de literatura); no requiere tareas de extracción o procesamiento de datos propias.*

---

### 5.3 Dimensiones territoriales del NS en México

#### 5.3.1 Exportaciones por Entidad Federativa

**Fuente:** Base de datos EFET del INEGI

**Notas:**
- Usar el mayor nivel de desagregación disponible una vez examinada la base.
- ⚠️ **Tarea previa:** Determinar si EFET usa SA o SCIAN (ver sección 4.3).
- El total de exportaciones derivado de EFET deberá confrontarse con el total de importaciones provenientes de México según el US Census. Las discrepancias deberán explicarse en la medida de lo posible.

#### 5.3.2 Inversión Extranjera Directa por sector y Entidad Federativa

**Fuente:** Censos Económicos del INEGI 2018 y 2023 (clasificación SCIAN)

**Nota:** Se identificarán las agrupaciones SCIAN que más se aproximen a los Capítulos o Partidas de interés en el SA (Secciones XVI, XVII y XVIII).

#### 5.3.3 Empleo en el régimen IMMEX, por sector y Entidad Federativa

**Desagregación:** Estados y Municipios; incluye cálculo específico para la Zona Libre de la Frontera Norte.

⚠️ **Dependencia pendiente:** Requiere el listado de municipios de la ZLFN (por recibir).

---

## 6. Reglas de trabajo

1. Al descargar bases de datos, guardar tanto los datos como los metadatos en un objeto `list` (ver estructura en sección 3).
2. Los datos de cada base se almacenan en un archivo `.rds` con la convención de nombres definida en la sección 3.
3. Una vez completada la construcción de las bases de datos, se procederá a **normalizar** los datos (p. ej., listas maestras de entidades federativas, secciones del SA, etc., que son compartidas por múltiples bases).
4. Todo el trabajo se organiza en dos archivos `.qmd`: `01_datos.qmd` y `02_visualizaciones.qmd`.
5. El texto del capítulo se redactará a partir de `02_visualizaciones.qmd`.

---

## 7. Tareas previas al inicio de la codificación

- [ ] Decidir formato de salida del capítulo (PDF o Word desde Quarto).
- [ ] Examinar la base EFET del INEGI y determinar si usa SA o SCIAN.
- [ ] Recibir el listado de municipios de la Zona Libre de la Frontera Norte.
- [ ] Confirmar disponibilidad y estructura de los datos 2025 en `usatrade.census.gov`.
