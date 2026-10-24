# Pendientes NSMX (nota del 2026-10-24)

Nota para retomar la reorganización en unos días. Contexto: el catálogo
`Quarto/CATALOGOS_NSMX.qmd` quedó escrito y se dejó "tal cual". Esta lista
recoge lo que quedó abierto. Marcar con `[x]` al cerrar cada punto.

## A. Antes de dar por cerrado el catálogo

- [ ] Renderizar `Quarto/CATALOGOS_NSMX.qmd` a Word (no se probó) y revisar
      que las tablas anchas se vean bien con `reference-doc.docx`.
- [ ] Correr el chunk `inventario-rds` del Apéndice (está en `eval: false`)
      y pasar al catálogo las filas, columnas y rangos de fechas reales
      (no se re-verificaron tras el repull y los siete Preps).
- [ ] Revisar los `.qmd` de `Productos intermedios/`: no se leyeron. Puede
      que alguno cargue RDS, sobre todo `aranceles_autos_autopartes_mensual.rds`.
      Usar `buscar_en_repo("readRDS", ext = "\\.qmd$")` o leerlos.
- [ ] Decidir si `tabla_partidas_competencia.rds` se queda en el catálogo
      (se incluyó porque C3 la carga; antes se había dicho que no iba).

## B. Archivos movidos a `Por_eliminar/` (24-oct-2026)

- [ ] Al terminar C2 y C3: si ninguno de estos archivos hizo falta, borrar
      `RDS/Por_eliminar/` y `Excel/Por_eliminar/`. El borrado requiere habilitar
      el permiso de borrado de la conexión al disco (se dejó pendiente).
- [ ] Aprovechar para unificar `Excel/_to_delete/` (anterior) con
      `Excel/Por_eliminar/`.
- [ ] Decidir si se archivan también los intermedios que ningún qmd carga y
      que regenera un Prep: `imp_mex_hs6`, `imp_mex_hs4_84858790`,
      `imp_mex_hs6_84858790`, `imp_mex_top_hs4`, `impMex_caps_2025`,
      `listas_finales_NS_mex_vnm_twn`, `tabla_competencia_mex_vnm_twn`,
      `tabla_overlap_mex_vnm_twn`, `ied_flujos_tipo`,
      `aranceles_autos_autopartes_mensual`, `top_partidas_periodos`,
      `top_partidas_competidores_periodos`. Si se quieren dejar de producir,
      hay que cambiar el Prep que los escribe, no moverlos.
- [ ] Comprobar si quedó una carpeta `Plots/PLOTS` o `PLOTS/` suelta (el
      `infografias_aranceles.qmd` ya guarda en `Plots/`).

## C. Scripts por decidir (archivar o conservar)

- [ ] `Query05_Media.R` (GDELT y Media Cloud-API): obsoleto; sus RDS ya están
      en `Por_eliminar/`. Correrlo los recrea. Probable candidato a `Scripts/old/`.
- [ ] `top_hs4_Pendiente.R`: parece redundante con el chunk `prep-tablas-cap`
      de C2.
- [ ] `Rec_Diverging_Bars.R`, `retryloop.R`, `percents.R`, `plot_save_load.R`
      y `Scripts/old/`: heredados.
- [ ] `ied_plots_fbcf.R`: nunca se corrió (no hay `Plots/ied_fbcf_*`). Decidir
      si las figuras de FBCF entran en C2 o C3. Los `zafra-*.png` ya cubren
      parte de ese tema.
- [ ] `Query07_X_estado_sector.R`: sigue calculando `etef_valor_accounting`
      (ya sin referencia en `meta_etef`) y no lo usa; se puede borrar ese bloque.

## D. Datos sin productor o con metadatos viejos

- [ ] `datos_847150_hs6.rds` (lo carga C3, figura "EXPLORATORIO"): no hay
      script que lo cree. Escribir un Prep o un bloque en Query02/Prep02 que lo
      genere desde `raw_df_mex_vnm_twn.rds`, o quitar la figura de C3.
- [ ] `fbcf_inegi.rds`: se hizo a mano desde un Excel de un colega. Si C2 o C3
      lo usan, conviene dejar el procedimiento escrito.
- [ ] `meta_etef.rds` y `meta_query11.rds` en disco conservan texto viejo
      (la referencia a `etef_valor_accounting.rds`, y "Query03 y Query04
      derivan..."). Se corrigen solos al volver a correr Query07 y Query02.
- [ ] `Excel/2025_4T_Flujos_PTI_ACT_3_.xlsx`: estaba para una revisión
      "vieja vs. nueva" de la IED (prevista el 23-oct). Si ya se hizo, mover a
      `Por_eliminar/`.
- [ ] `MD/Catalogo_RDS.md` (catálogo anterior, 19-oct) queda superado por el
      nuevo documento; decidir si se archiva.

## E. Siguiente documento

- [x] Protocolo de verificaciones posteriores a una descarga: escrito el
      24-oct-2026 en `Quarto/Protocolo_verificacion_descargas.qmd` (genérico,
      no NSMX) con las funciones en `Scripts/funciones_verificacion.R`.
- [ ] Probar `funciones_verificacion.R` en RStudio (no se corrió: no hubo R
      disponible al escribirlo). Probar cada `chk_*` con un caso malo
      (fila duplicada, mes faltante, valor x1000) y ver que se detiene.
- [ ] Renderizar el protocolo en Posit Cloud y revisar tablas.
- [ ] Revisar el Apéndice A del protocolo (casos NSMX): se reconstruyó desde
      resúmenes, sobre todo A.3 (IMMEX) y A.7.
- [ ] Decidir si se incorporan los `chk_*` en los Query01-10 (hoy cada uno
      tiene sus verificaciones propias en el script).
