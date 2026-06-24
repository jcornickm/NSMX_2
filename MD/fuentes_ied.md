# Fuentes de datos: Exportaciones por Entidad Federativa e IED
## Proyecto NSMX_C2 — Capítulo 2

---

## A. Exportaciones por Entidad Federativa y Sector

### Fuente: INEGI — Exportaciones Trimestrales por Entidad Federativa (ETEF)

**URL principal:** https://www.inegi.org.mx/temas/exportacionesef/

**Nombre completo del proyecto estadístico:**
Exportaciones Trimestrales por Entidad Federativa (ETEF). Anteriormente llamado
Estadística de Exportaciones por Entidad Federativa (EEF) cuando sólo tenía
frecuencia anual.

**Clasificación sectorial:** SCIAN (no SA).
La desagregación sectorial usa el Sistema de Clasificación Industrial de América
del Norte (SCIAN 2007 en las series históricas; SCIAN 2018 en series recientes).
**No hay una correspondencia directa con los Capítulos del SA**, por lo que será
necesario construir una tabla de concordancia aproximada entre los subsectores
SCIAN relevantes y las Secciones XVI, XVII y XVIII del SA.

**Desagregación disponible (tabulados públicos):**
- 32 entidades federativas
- 26 subsectores SCIAN:
  - 3 subsectores de Agricultura, cría y explotación de animales, etc.
    (disponibles solo desde Q1 2018)
  - 2 subsectores de Minería
  - 21 subsectores de Industrias Manufactureras
- Frecuencia: trimestral y anual
- Unidad: miles de dólares estadounidenses

**Cobertura temporal:**
- Serie anual: 2007 en adelante
- Serie trimestral: Q1 2007 en adelante (datos agropecuarios desde Q1 2018)
- Datos más recientes disponibles: Q3 2025 (publicados diciembre 2025)

**Acceso a los datos:**
- **Tabulados interactivos y descarga:** disponibles en el sitio del proyecto
  (https://www.inegi.org.mx/temas/exportacionesef/) y en el Banco de Información
  Económica (BIE) del INEGI.
  > ⚠️ A partir del 30 de septiembre de 2025, la información desagregada por
  > sector y subsector SCIAN está disponible **únicamente** en los tabulados
  > interactivos y en el BIE — ya no se distribuye en archivos de descarga masiva
  > directa en el formato anterior.
- **Microdatos:** confidenciales; no están disponibles al público.

**Metodología (resumen):**
La ETEF vincula registros aduanales de la Balanza Comercial con información de
Censos Económicos, Encuestas Manufactureras, la estadística IMMEX, y registros
de la CNH/Pemex, usando el RENEM como eje de unión. Las exportaciones se asignan
a la entidad de **origen de la producción**, no al punto de salida aduanal.

**Repositorio de metadatos (INEGI RNM):**
https://www.inegi.org.mx/rnm/index.php/catalog/1108  (Q3 2025, más reciente)

---

## B. IED por Entidad Federativa y Sector: el problema de las fuentes disponibles

### El sesgo de domicilio en los datos de la SE/RNIE

La fuente estándar para IED en México — el Registro Nacional de Inversiones
Extranjeras (RNIE) de la Secretaría de Economía — **no es adecuada para
analizar la distribución geográfica real de la inversión**. Las empresas
registran su inversión en la entidad donde tienen su domicilio fiscal o legal,
que en la gran mayoría de los casos es Ciudad de México. En consecuencia, CDMX
absorbe sistemáticamente entre el 44% y el 56% del total nacional registrado,
independientemente de dónde se ubique la planta productiva. Este sesgo es
ampliamente reconocido en la literatura y en los análisis oficiales.

Los datos de la SE/RNIE siguen siendo útiles para:
- Evolución temporal de los flujos nacionales de IED
- Composición por tipo de inversión (nuevas inversiones, reinversión, cuentas entre compañías)
- Distribución por país de origen
- Composición sectorial a nivel nacional

Pero **no deben usarse** para inferir dónde ocurrió efectivamente la inversión
en términos geográficos.

---

### Fuentes alternativas para aproximar la distribución geográfica real

No existe una fuente oficial única que resuelva completamente el problema.
Las mejores aproximaciones disponibles son:

#### 1. Censos Económicos del INEGI (fuente principal recomendada)

**URL:** https://www.inegi.org.mx/app/saic/

**Censos relevantes:**
| Censo | Levantamiento | Año de referencia |
|---|---|---|
| Censos Económicos 2019 | 2019 | 2018 |
| Censos Económicos 2024 | 2024 | 2023 |

**Qué reportan:** Los CE capturan información estructural de todos los
establecimientos del país, desagregada por entidad federativa, municipio y
clase de actividad SCIAN. Las variables más útiles para este capítulo son:
- Valor agregado censal bruto
- Activos fijos
- Personal ocupado
- Remuneraciones
- **Participación de capital extranjero** (variable captada a nivel de
  establecimiento, que permite distinguir establecimientos con IED de los
  puramente domésticos)

**Estrategia propuesta:** Comparar el valor agregado, los activos fijos y el
empleo en los subsectores SCIAN relevantes (331–339) entre CE 2019 y CE 2024,
a nivel de entidad federativa. La variación entre ambos censos es la mejor
aproximación oficial disponible para identificar dónde creció efectivamente la
capacidad productiva manufacturera — y por extensión, dónde se materializó la
IED vinculada al NS. Filtrar adicionalmente por "participación de capital
extranjero" agrega precisión.

**Limitación:** Los CE tienen periodicidad quinquenal. No permiten seguimiento
anual. El CE 2024 (año de referencia 2023) es el más reciente, lo que deja
fuera los desarrollos de 2024–2025.

**Acceso:**
- Tabulados interactivos (SAIC): https://www.inegi.org.mx/app/saic/
- Descarga masiva disponible desde la misma interfaz.

---

#### 2. Estadística IMMEX — INEGI/SE (fuente complementaria)

El empleo en el régimen de la Industria Manufacturera, Maquiladora y de
Servicios de Exportación (IMMEX) por entidad federativa y subsector es un
proxy sólido de la manufactura de exportación con participación extranjera.
Ya está contemplado en la sección 5.3.3 del plan del capítulo.

---

#### 3. Datos de bienes raíces industriales (referencia cualitativa)

Firmas como CBRE, JLL y la Asociación Mexicana de Parques Industriales
Privados (AMPIP) publican datos de absorción y ocupación de espacio industrial
por mercado/ciudad, con periodicidad trimestral. No son datos de IED como tal,
pero son geográficamente precisos y capturan la materialización física de las
decisiones de inversión. Pueden servir como referencia de validación o como
insumo para una sección cualitativa del capítulo.

---

### Conclusión sobre la estrategia de datos para IED territorial

La aproximación más rigurosa disponible dentro de fuentes oficiales es la
**comparación de indicadores censales entre CE 2019 y CE 2024**, focalizando
en los subsectores SCIAN 331–339 (manufactura relevante para NS) y filtrando
por participación de capital extranjero. Esta estrategia refleja inversión
efectivamente materializada, en la ubicación real de los establecimientos,
con cobertura prácticamente universal del sector manufacturero formal.

El capítulo debe documentar explícitamente la limitación del dato de la SE/RNIE
y justificar el uso de los Censos Económicos como fuente alternativa.

---

## C. Nota sobre la concordancia SCIAN ↔ SA

Tanto la ETEF como los Censos Económicos usan SCIAN; el resto del capítulo
(importaciones de EUA) usa el SA. La siguiente tabla de equivalencias
aproximadas cubre los sectores más relevantes para el NS:

| Sección SA | Descripción SA | Subsector SCIAN aprox. |
|---|---|---|
| XVI — Cap. 84 | Maquinaria no eléctrica | 333 Fabricación de maquinaria y equipo |
| XVI — Cap. 85 | Equipo eléctrico y electrónico | 334 Fabricación de equipo de computación y electrónico; 335 Fabricación de equipo de generación eléctrica |
| XVII — Cap. 87 | Vehículos y autopartes | 336 Fabricación de equipo de transporte |
| XVIII — Cap. 90 | Instrumentos de óptica y médicos | 3345 Fabricación de instrumentos de medición (parte del subsector 334) |

Para el análisis de la ETEF y los Censos Económicos, los subsectores 331–339
de Industrias Manufactureras son los más relevantes en su conjunto.

---

*Documento generado: abril 2026. Actualizar si cambian las URLs o la
disponibilidad de datos.*