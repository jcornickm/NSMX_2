
#| label: fig-trade-flows
#| eval: false
#| include: false

# Original slow code — kept for reproducibility
p <- ggplot(data, aes(...)) + ...
ggsave(here("plots", "fig_trade_flows.png"), plot = p, width = 8, height = 5, dpi = 150)




#| label: fig-trade-flows-display
#| echo: false
knitr::include_graphics(here("plots", "fig_trade_flows.png"))

