# Frases de C2 que citan tasas o cambios del cálculo por períodos (revisar tras re-correr)

Contexto: períodos 2010-2017 y 2018-2024, segundo bloque medido desde 2017 (TCAC n=7 y n=7).
Líneas del qmd `C2_Revised_October_2026_v3.qmd` al 2026-10-31. Solo se cambió mecánicamente "2010-2018" por "2010-2017"; las cifras y los juicios quedan para revisión.

| Línea | Qué revisar | Inicio del texto |
|---|---|---|
| 290 | Resumen: TCAC China vs. México "entre 2018 y 2024" | - Las cosas cambiaron de manera drástica entre 2018 y 2024: aunque las exportaciones chinas alcanzaron su nive |
| 292 | Liberalización "hasta 2018" (¿hasta 2017?) | Una primera impresión, entonces, es que México se ha beneficiado tanto de la tendencia a la liberalización del |
| 553 | Cambios de participación por país: 7.7 pp, ganadores/perdedores, Taiwán "entre 2010 y 2017" | - En el período siguiente, China es por mucho el gran perdedor: 7.7 puntos porcentuales. Los ganadores son, de |
| 555 | Cifras del primer período por país (revisar si existen) | Vale la pena comparar directamente el desempeño de las exportaciones de México, Vietnam y Taiwán, no sólo por  |
| 557 | Cambio de Taiwán/Vietnam "a partir de 2018" (el hito se mantiene) | La @fig-ImpEUA-shares muestra el comportamiento de las exportaciones de estos tres países entre 2010 y 2024. E |
| 771 | Sección XVII y V: "casi 10 pp" (primer período) | - Entre 2010 y 2017, Las exportaciones de la Sección XVII, Material de transporte, ganan casi 10 puntos porcen |
| 773 | Segundo período por secciones (cifras) | - La dinámica cambia en el período siguiente: el crecimiento en participación porcentual es liderado por la Se |
| 1086 | 16 partidas que aceleran: el número cambia; nota "4" pegada a 2010-20174 (¿llamada a pie de página?) | En las tablas se destacan en amarillo las 16 partidas que crecieron más rápidamente en 2018-2024 que en 2010-2 |
| 1105 | Aceleración por secciones | Se trata, pues, de un período en el que si bien la aceleración del crecimiento de las exportaciones se concent |
| 1110 | Partida 8473: 1.9% y 27.3% | - La tasa de crecimiento de la partida 8473, partes y accesorios para equipos de oficina, pasa de 1.9% en 2010 |
| 1111 | Partidas que aceleran | - Todas las demás partidas cuya tasa de crecimiento se acelera en 2018-2024 representan montos modestos en 202 |
| 1126 | 8504 y 8516 | - Dos partidas exhiben un crecimiento particularmente acelerado en 2018-2024: 8504, transformadores, y 8516, c |
| 1127 | 8517: -0.1% | - Únicamente una partida, 8517, teléfonos, muestra una tasa de crecimiento negativa en 2018-2024: teléfonos, p |
| 1138 | Capítulo 87 | El panorama es muy distinto para el **Capitulo 87**. Las partidas 8704, 8708 y 8703, caminoes, autopartes y au |
| 1152 | 9019 y 9032: 11.x% y 1.0% | - Únicamente esa partida, la 9019, apartaod de terapia, y la 9032, reguladores, crecen más rápidamente en 2018 |
| 1249 | Mapa estados, primer período (listas de estados y tasas) | Período 2010 - 2017: |
| 1255 | Mapa estados, segundo período (listas de estados y tasas) | En contraste, entre 2018 y 2024: |
| 1262 | Estados con TCAC >= 7.5% en ambos períodos | Debe notarse que solo hay cuatro estados que crecen a una tasa del 7.5% o superior en ambos períodos: Coahuila |
| 1767 | IMMEX: TCAC 5.1% -> 1.3%, ZLFN nulo, resto 2% | La desaceleración en el segundo período es manifiesta: la TCAC pasa de 5.1% en el período anterior a apenas 1. |
| 2238 | "crecimiento de exportaciones a partir de 2018" (hito) | Da la impresión de que existe una incongruencia entre las oportunidades puestas en evidencia por el crecimient |
| 2923 | Quiebres "en o poco después de 2018" (hito; no cambia) | La figura pone en evidencia que prácticamente en todos los casos hubo un punto de quiebre de tendencia en o po |
| 2925 | Valor duplicado "entre 2018 y 2025" (verificar base) | - El valor de las exportaciones de las partidas 8415 (equipo de climatización), 8418 (equipo de refrigeración) |

## Para re-correr (en este orden, sesión limpia de R)
1. `Scripts/Prep02_USA_imp_Mex_all_HS.R` (genera `TCAC_1017`, `TCAC_1724`).
2. `Scripts/Prep06_tcac_estados.R` (genera `tcac_2010_2017`, `tcac_2017_2024`).
3. Prep05 y Prep08 leen `TCAC_y_shares_84858790.rds`: re-correr tras Prep02.
4. Chunks `save-` de C2, uno por uno: fig-ImpEUA-CHN-MEX, fig-imp-cambio-pais, fig-imp-cambio-sec-mex, mapa_xmex_2periodos_tcac, fig-immex-empleo, mapa_immex_2periodos. Las tablas de partidas y de estados se calculan al renderizar.
5. Revisar a ojo las etiquetas de TCAC en los gráficos de línea (cambió la altura `y_pos`: ahora se ancla en 2017).

## Pendiente fuera de C2 (resuelto 2026-10-31)
Movidos a `Por_eliminar/` sin actualizar a base 2017 (se eliminan si C2 y C3 no los necesitan):
- `Scripts/Por_eliminar/top_hs4_Pendiente.R` (usaba `tcr_1824`).
- `Scripts/Por_eliminar/Rec_Diverging_Bars.R` (receta con `c(2010, 2018)` y `c(2018, 2024)`).
- `RMD/Por_eliminar/NSMX_C2_Plots_julio_2026 Claude.Rmd` (usaba `TCAC_1018/1824`).
