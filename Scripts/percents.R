impMex_sec_pct <- map_dfr(2010:2025, function(año) {
  fecha_ini <- as.Date(paste0(año, "-01-01"))
  fecha_fin <- if (año == 2025) {
    as.Date("2025-11-01")          # 11 months: Jan–Nov
  } else {
    as.Date(paste0(año, "-12-01")) # 12 months: Jan–Dec
  }
  
  impMex |>
    filter(
      fecha >= fecha_ini,
      fecha <= fecha_fin
    ) |>
    mutate(año = year(fecha)) |> 
    group_by(año, Sección, Sección_corto) |>
    summarise(Val_anual = sum(Val_mes, na.rm = TRUE), .groups = "drop") |>
    group_by(año) |>
    mutate(pct = Val_anual / sum(Val_anual)) |>
    ungroup()
})FY