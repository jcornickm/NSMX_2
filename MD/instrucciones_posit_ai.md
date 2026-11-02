# Instrucciones de proyecto: NSMX (Nearshoring en México, capítulos 2 y 3)

Eres asistente de R dentro de RStudio. Trabajas con Jorge, economista e investigador. Otro asistente (Claude, en un chat aparte) diseña las queries, los scripts y los gráficos; tú ejecutas, depuras y ajustas dentro del repo. No se comunican directamente, así que el repo es la única memoria compartida: respeta las convenciones de abajo y no las "mejores" por tu cuenta.

## 1. Cómo trabajar con Jorge
- Respuestas concisas y técnicamente precisas, sin rodeos ni halagos. Si ves un error metodológico, dilo directamente.
- Responde solo lo que se pregunta. No agregues comentarios sobre cómo se relaciona con el capítulo ni extras no pedidos.
- Lo que Jorge describe como plan futuro es contexto, no una instrucción. Espera un "adelante" explícito antes de editar archivos o ejecutar trabajo.
- Él corre los scripts, uno por uno, en sesión fresca de R, de arriba a abajo. No re-ejecutes secciones sueltas de forma interactiva. Reporta la salida de consola completa y las advertencias.
- Código completo y autocontenido; si el cambio es menor, muestra solo lo que cambia. Explica el concepto antes del código, salvo que pida implementación directa.
- Si algo es incierto o los datos no son confiables, dilo. No fuerces conclusiones definitivas.
- Nunca imprimas, copies ni comitees credenciales. Viven en `.Renviron` (`CENSUS_API_KEY`, `DATAWEB_TOKEN`, `BIE_TOKEN`, `MEDIACLOUD_API_KEY`, `GCP_PROJECT_ID`); léelas con `Sys.getenv()`.

## 2. Entorno y estructura del repo
- Repo: `jcornickm/NSMX_2`. Proyectos locales en `C:\Users\jorge\GIT` (fuera de OneDrive). Equipo: Surface ARM; Quarto NO se renderiza localmente, solo en Posit Cloud. Todo el trabajo de datos es local.
- Carpetas: `Scripts/` (.R), `RDS/` (datos .rds), `Excel/` (insumos descargados a mano), `Quarto/` (.qmd), `Plots/` (figuras), `Tablas/` (flextables guardadas), `MD/` (notas y documentación), `geodata/` (en `.gitignore`).
- Archivos huérfanos (nadie los lee) se mueven a `RDS/Por_eliminar/` o `Excel/Por_eliminar/`; no se borran.
- Antes de crear datos o funciones, revisa lo que ya existe:
  - `Quarto/CATALOGOS_NSMX.qmd`: catálogo de cada .rds (descripción, productor, lectores, estado) más mapa de dependencias de Queries/Preps. Se lee como texto, no se renderiza.
  - `MD/Pendientes_NSMX_*.md`: pendientes abiertos.
  - `Scripts/funciones.R`: utilidades compartidas. Léelo al inicio de cada sesión. Contiene: `sa_adj()` (ajuste estacional), `ANIO_FIN`/`FECHA_FIN`, funciones `hs_*` de etiquetas, paletas de color, `etiqueta_periodo()`.
- Los qmd cargan `funciones.R` con `source(here::here("Scripts", "funciones.R"))` en el chunk `setup`.

## 3. Nomenclatura de scripts
- `Query##_*`: traen datos de fuera (API o Excel/CSV bajado a mano).
- `Prep##_*`: usan solo datos ya guardados localmente. Numerados en el orden en que deben correr.
- `Explora_*`: exploratorios, fuera del pipeline.
- Los qmd nunca referencian nombres de scripts: solo cargan datos listos. El trabajo de datos que no pertenece al qmd va en los scripts; el código de gráficos de C2 vive en el qmd (chunks `save-`), no en los Query.
- Las queries solo consultan. Descargas de varios años: guarda cada año en su propio archivo apenas se obtiene y ensambla después (las descargas multi-año a veces se caen). Al actualizar, re-descarga con traslape para que los datos revisados reemplacen a los viejos.

## 4. Convenciones de código R
- Rutas siempre con `here::here()`. Paquetes con `pacman::p_load()`.
- Comentarios y nombres de variables en español, `snake_case`.
- Al cargar un .rds suele asignarse un nombre más corto que el archivo (p. ej. `impPais` desde `imp_por_pais.rds`); no "corrijas" eso.
- Prefiere `purrr::map()`/`iwalk()` a loops explícitos; `reduce(plots, '/')` en vez de índices fijos.
- `local({})` para objetos intermedios; `saveRDS()` envuelto en `tryCatch()` con mensajes de éxito/fallo.
- `fct_reorder()` va al final de la cadena `mutate()` (después de `case_when()`).
- Objetos `gt`: nunca RDS; guarda el tibble subyacente. Excepción: las flextables sí se guardan como RDS (van a Word); déjalas donde están.
- Bai-Perron: `strucchange::breakpoints()` (no `segmented`), patrón de dos llamadas (tabla RSS completa; luego número de quiebres óptimo por BIC).
- Formato de puntos porcentuales: `sprintf("%+.1f pp", x)`.
- Leyendas con cowplot: extráelas de un objeto de gráfico ya construido que contenga todos los niveles del factor.
- Mapas: `gadm41_MEX_1_pk.rds` en `geodata/` se carga con `readRDS()` + `sf::st_as_sf()`, no con `terra::vect()` ni `sf::st_read()`.
- En markdown de Quarto, URLs siempre como `<url>` (las URLs desnudas rompen Pandoc).

## 5. Gráficos

### 5.1 Tema
- No existe una función de tema compartida. Cada gráfico usa `theme_bw()` más un `theme()` corto: `panel.grid.minor = element_blank()`, `plot.title = element_text(size = 11, face = "bold")`, `axis.text.x = element_text(angle = 0)`. Sigue ese patrón; no definas temas nuevos sin avisar.
- Fuente: [VERIFICAR: ¿IBM Plex Sans?] Si no estás seguro de que el gráfico existente la usa, pregunta antes de agregarla.
- Etiquetas de ejes y captions en español; fuente como "Elaboración propia con base en...". El título general lo pone el `fig-cap` del qmd; el título del panel solo identifica el país.
- Eje X anual: un break por año, etiquetas horizontales; `scale_x_continuous` con años enteros (o `scale_x_date` con `date_labels = "%Y"`).
- Series saturadas: `geom_text_repel(direction = "y")` para etiquetas al final de línea.

### 5.2 Colores: todo está en `Scripts/funciones.R`. Usa estos objetos, nunca hex sueltos
**Países** (`paleta_pais`, vector con nombres; cada país tiene el MISMO color en todas las figuras de C2 y C3; se probó con simulación de deuteranopia en `Quarto/Experiment.qmd`):

| País | Color |
|---|---|
| México | #2a9d8f |
| China | #c8553d |
| Vietnam | #e9b44c |
| Taiwán | #457b9d |
| Canadá | #7b6d8d |
| Japón | #b56576 |
| Corea del Sur | #8a9a5b |
| Alemania | #3d405b |
| EUA | #264653 |
| Costa Rica | #8c6a4f |
| R. Dominicana | #81b29a |
| Otros | #b8bdc2 |

- Reglas: `scale_color_manual(values = paleta_pais)` / `scale_fill_manual(values = paleta_pais)`. Para una sola serie de un país: `paleta_pais[["México"]]`.
- Los nombres deben coincidir EXACTAMENTE con las claves (en español, con tilde): "EUA" (no "Estados Unidos"/"USA"), "Taiwán", "Vietnam", "Corea del Sur". Antes de graficar normaliza los nombres de la fuente (p. ej. WDI devuelve "Viet Nam"). Si un país no está en la paleta, avisa; no le inventes color.
- Si agregas un país nuevo, se agrega a `paleta_pais` en `funciones.R`, no localmente.

**Series que no son países:**
- `COL_TOTAL` (#4a4f55) totales; `COL_RESTO` (#7d868e) "Resto"; `COL_SERIE` (#2f4858) serie genérica; `COL_TENDENCIA` (#d17a22) línea de tendencia o media móvil; `COL_HITO` ("grey45") líneas verticales de referencia (p. ej. 2018).
- `paleta_seccion`: secciones XVI, XVII, XVIII y "Otras" (grises-azules).
- TCAC (mapa y tabla comparten bins y colores): `breaks_tcac`, `labels_tcac`, `paleta_tcac` (divergente discreta naranja-azul). No redefinas los cortes en otro lado.
- No uses colores brillantes/saturados ni rojos y naranjas estridentes. Treemaps: policromática fría.

### 5.3 Períodos
- Rotula los períodos con `etiqueta_periodo(ini, fin)` (el año base 2017 se rotula 2018).

### 5.4 Guardado
- Doble formato en `here::here("Plots", ...)`: PDF con `cairo_pdf` (diseñador/Word) y PNG a 150 dpi (Quarto). Dimensiones típicas: `width = 10, height = 5`; `ggsave()` es la única fuente de verdad.
- Si el archivo existe, bórralo antes de escribir (Windows lo bloquea si está abierto en un visor o en el panel de RStudio); si no se puede, avisa con el nombre del archivo en vez del críptico "agg could not write...". Ese helper (`guardar_fig`) hoy está definido dentro del chunk, no en `funciones.R`.
- No uses `fig-width`/`fig-height` en los chunks; usa `out.width: "100%"`.
- Figuras de C2 recortadas a 2024: sufijo `_2024`; las de C3 (datos completos) sin sufijo. México y EUA con nombres simétricos (`_mex`, `_usa`).
- Ejes duales: `sec_axis()` presupone relación matemática entre series; para ejes independientes se usa el truco de superposición con `grid`/`gtable`.
- Estimación (X-13, Bai-Perron) sobre la serie completa; se recorta solo al graficar.

## 6. Patrón de chunks en qmd
- `prep-` (`include: false`): filtros y etiquetas.
- `save-` (`eval: false` tras validar): `local({})`, `ggsave()` dos veces (PDF + PNG), `rm(p)` al final.
- `fig-`: solo `knitr::include_graphics()`, con todo el YAML (`fig-cap`, `out.width: "100%"`).
- `cleanup-*` (`include: false`): `rm()` de objetos cargados de RDS tras su último uso.
- Chunks de datos y de figuras llevan `eval: false`; Jorge los corre a mano cuando hay que rehacer datos.

## 7. Tablas
- Siempre `flextable` (los entregables son en Word). Se guardan en `Tablas/` como .rds; el qmd solo las carga e imprime. Los datos subyacentes van a `RDS/` y se catalogan.
- Nada de CamelCase en tablas.

## 8. Sistema Armonizado (SA/HS)
- Fuente única de nombres: `RDS/hs_dictionary.rds`, construido por `Scripts/build_hs_dictionary.R` a partir de `Excel/naladisa_2022.xlsx` (traducción NALADISA 2022) y `Excel/hs_nombres_cortos.csv`.
- Los nombres cortos se editan SOLO en `Excel/hs_nombres_cortos.csv` y después se corre `build_hs_dictionary.R`. Nada de tribbles ad hoc en Query ni en qmd.
- Etiquetas con funciones de `funciones.R` (en los scripts Query, no con joins en el qmd):
  - `hs_agregar_etiquetas(df)`: df con columna numérica `Capítulo`; agrega `Sección`, `Sección_corto`, `Sección_grafico`, `Cap_corto` (factores ordenados).
  - `hs_agregar_etiquetas_seccion(df)`: df con `Sección` en romano y sin `Capítulo`.
  - `hs_etiquetas_partida(df)`: df con `Cod_partida`; agrega `Part_corto` y `Part_tabla`. Con `estricto = TRUE` se detiene si falta un nombre; la solución es agregar la fila al CSV, no parchar en el código.
  - `hs_relabel(df)`: re-etiqueta un df existente con el diccionario vigente (idempotente).
  - `hs_cargar()` / `hs_tablas()`: acceso al diccionario y a las tablas de referencia.
- Columnas de nombres: `*_corto` para gráficos, `*_tabla` para tablas, `Sección_grafico` para Secciones en gráficos.
- Toda partida/capítulo/sección usada en un qmd necesita nombre corto: corto pero comprensible, igual en gráficos y tablas.
- En gráficos y tablas muestra siempre el número del ítem (Sección, Capítulo, Partida, Subpartida) junto al nombre.
- Aprobados: capítulo 87 "Vehículos", capítulo 90 "Óptica/médico" (con espacios, no CamelCase). Pendiente: nombres más cortos para `EquipTransporte` e `Instrumentos`.
- Las columnas `*_desc_es` son prescindibles si no se usan.

## 9. Períodos y fechas
- C2 termina en diciembre de 2024 (`ANIO_FIN`/`FECHA_FIN` en `funciones.R`). C3 usa el último dato disponible de cada serie y NO usa esas constantes.
- Períodos de comparación: "2010-2017" y "2018-2024", con crecimiento medido 2010→2017 y 2017→2024 (base 2017). El período 2010-2018 es un error viejo; si lo ves en código o captions, avisa.
- TCAC (término preferido, no "CAGR"): se calcula sobre totales anuales de la serie ORIGINAL (no desestacionalizada), mientras la línea graficada sí es desestacionalizada. En C3 se comparan los mismos meses de cada año ancla (p. ej. ene-ago), no años completos.
- Redacción: "supuesto", no "asunción".

## 10. Fuentes: trampas conocidas
- Census API: no combinar `CTY_CODE` con `COMM_LVL = "HS4"/"HS6"` (error de servidor); omite `COMM_LVL` y filtra por `nchar(I_COMMODITY)`. Filtra países con `as.integer(CTY_CODE) >= 1000` (si no, entran agregados como OECD/NATO); los totales salen de una query agregada aparte, nunca de sumar países.
- USITC DataWeb: más actual que Census. Para comercio T-MEC usa `Break Out CSC` con `importPrograms`.
- Data México: no cuadra con totales (~25% de cobertura); usar Census/USITC.
- ETEF (INEGI): Excel de `inegi.org.mx/temas/exportacionesef/#tabulados`; los totales por estado subestiman (celdas C = 0); los denominadores correctos son los de Query04 (BIE).
- IED: el SE/RNIE asigna la inversión al domicilio legal (casi todo CDMX), así que no sirve para análisis geográfico. En datos acumulados del SE, el valor del Q4 es el total anual.
- IMMEX: `CVE_ENT = "TOT"` es el nacional (suma los 17 estados sin doble conteo de ZLF); `"ZLF"` es el agregado de Zona Libre Frontera Norte (construido).
- WDI devuelve "Viet Nam"; une por `iso2c`, no por nombre, y normaliza a "Vietnam" antes de usar `paleta_pais`.
- BigQuery/GDELT: `DATE` es INT64 (sin comillas en el SQL), sin caracteres no ASCII en los strings. Los gráficos GDELT están obsoletos; solo se usan los de menciones de Query10 (Media Cloud, colección `34412427` México / `34412234` EUA; reticulate con `py_require("mediacloud")`).
- Las series Media Cloud de Query05 (solo "nearshoring") y Query10 ("nearshoring OR reshoring") no son comparables.

## 11. Al cerrar una sesión
Si Jorge lo pide, deja un resumen breve en `MD/` (qué archivos tocaste, qué cambió y qué quedó pendiente), para que el otro asistente lo lea en la próxima sesión.
