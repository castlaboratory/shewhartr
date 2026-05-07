# Package index

## Classical charts — variables

Classical Shewhart charts for measurements organised in rational
subgroups (or as individuals).

- [`shewhart_i_mr()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_i_mr.md)
  : Individuals and Moving Range (I-MR) control chart
- [`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md)
  : Xbar-R control chart for rational subgroups
- [`shewhart_xbar_s()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_s.md)
  : Xbar-S control chart for rational subgroups

## Classical charts — attributes

Charts for binary (defective/non-defective) and count (defects-per-unit)
attributes.

- [`shewhart_p()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_p.md)
  : p chart for the proportion of nonconforming items
- [`shewhart_np()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_np.md)
  : np chart for the number of nonconforming items
- [`shewhart_c()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_c.md)
  : c chart for the number of nonconformities
- [`shewhart_u()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_u.md)
  : u chart for nonconformities per unit, variable inspection size

## Regression-based chart

Control chart for trended processes, with optional automatic phase
detection and a flexible model menu (linear, log, log-log, Gompertz,
logistic, custom formula).

- [`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md)
  : Regression-based control chart for processes with trend

## Memory-based charts

Charts that accumulate information across observations and so detect
small persistent shifts faster than Shewhart-style charts.

- [`shewhart_ewma()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_ewma.md)
  : Exponentially Weighted Moving Average (EWMA) control chart
- [`shewhart_cusum()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_cusum.md)
  : Tabular CUSUM control chart

## Multivariate charts

Charts for jointly monitoring several correlated quality
characteristics; sensitive to shifts in the correlation structure that
univariate charts can miss.

- [`shewhart_hotelling()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_hotelling.md)
  : Hotelling T-squared multivariate control chart
- [`shewhart_mewma()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_mewma.md)
  : Multivariate EWMA control chart
- [`shewhart_mcusum()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_mcusum.md)
  : Multivariate CUSUM control chart (Crosier 1988)

## Phase I / Phase II workflow

Explicit calibration and monitoring step, following the Phase I / Phase
II framework articulated by Woodall (2000).

- [`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md)
  : Phase I calibration of a control chart
- [`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
  : Phase II monitoring against pre-calibrated limits

## Diagnostics & operating characteristics

Tools to evaluate and interpret a chart configuration: runs tests, ARL
by simulation, residual diagnostic panels, Box-Cox guidance.

- [`shewhart_runs()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_runs.md)
  : Apply runs tests to a chart object or to raw vectors
- [`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md)
  : List available runs rules
- [`shewhart_arl()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_arl.md)
  : Estimate Average Run Length via Monte Carlo simulation
- [`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md)
  : Tukey-style residual diagnostic panel
- [`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
  : Box-Cox profile log-likelihood

## Process capability

- [`shewhart_capability()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_capability.md)
  : Process capability indices Cp, Cpk, Pp, Ppk

## S3 methods (broom + ggplot2)

- [`print(`*`<shewhart_chart>`*`)`](https://castlaboratory.github.io/shewhartr/reference/print.shewhart_chart.md)
  : Print a Shewhart chart object
- [`summary(`*`<shewhart_chart>`*`)`](https://castlaboratory.github.io/shewhartr/reference/summary.shewhart_chart.md)
  : Compact tibble-like summary
- [`autoplot.shewhart_chart()`](https://castlaboratory.github.io/shewhartr/reference/autoplot.shewhart_chart.md)
  : Plot a Shewhart chart with ggplot2
- [`tidy(`*`<shewhart_chart>`*`)`](https://castlaboratory.github.io/shewhartr/reference/tidy.shewhart_chart.md)
  : Tidy the control limits of a Shewhart chart
- [`glance(`*`<shewhart_chart>`*`)`](https://castlaboratory.github.io/shewhartr/reference/glance.shewhart_chart.md)
  : Glance at a Shewhart chart's overall diagnostics
- [`augment(`*`<shewhart_chart>`*`)`](https://castlaboratory.github.io/shewhartr/reference/augment.shewhart_chart.md)
  : Augment new data with control-chart annotations

## Interactive plots

- [`as_plotly()`](https://castlaboratory.github.io/shewhartr/reference/as_plotly.md)
  : Convert a Shewhart chart to an interactive plotly figure

## Theme and palettes

Shared visual identity used by every
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
method. Pull these into your own ggplot layers when you want a chart
that matches the rest of the package.

- [`shewhart_theme()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_theme.md)
  :

  Editorial-style ggplot2 theme used by every `autoplot.shewhart_*`

- [`shewhart_palette()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_palette.md)
  : Access the package's named colour palettes

## Math helpers

- [`Gompertz()`](https://castlaboratory.github.io/shewhartr/reference/Gompertz.md)
  : Gompertz growth function

- [`SSgompertzDummy()`](https://castlaboratory.github.io/shewhartr/reference/SSgompertzDummy.md)
  : Self-starting Gompertz with an additive dummy term

- [`fit_gompertz_dummy()`](https://castlaboratory.github.io/shewhartr/reference/fit_gompertz_dummy.md)
  :

  Convenience wrapper to fit `SSgompertzDummy` to a data frame

- [`loglog()`](https://castlaboratory.github.io/shewhartr/reference/loglog.md)
  : Log-log transformation

- [`iloglog()`](https://castlaboratory.github.io/shewhartr/reference/iloglog.md)
  : Inverse log-log transformation

- [`box_cox()`](https://castlaboratory.github.io/shewhartr/reference/box_cox.md)
  : Apply / invert a Box-Cox power transformation

- [`inv_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/inv_box_cox.md)
  : Inverse Box-Cox transformation

- [`shewhart_constants()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_constants.md)
  : Look up Shewhart control chart constants

- [`rolling_sum()`](https://castlaboratory.github.io/shewhartr/reference/rolling_sum.md)
  : Rolling sum with a configurable window

- [`color_hue()`](https://castlaboratory.github.io/shewhartr/reference/color_hue.md)
  : Generate a qualitative HCL palette

## Datasets

- [`tablet_weight`](https://castlaboratory.github.io/shewhartr/reference/tablet_weight.md)
  : Pharmaceutical tablet weights
- [`bottle_fill`](https://castlaboratory.github.io/shewhartr/reference/bottle_fill.md)
  : Bottle filling volumes
- [`pcb_solder`](https://castlaboratory.github.io/shewhartr/reference/pcb_solder.md)
  : Solder defects on printed circuit boards
- [`claims_p`](https://castlaboratory.github.io/shewhartr/reference/claims_p.md)
  : Daily insurance claim error rates
- [`temperature_drift`](https://castlaboratory.github.io/shewhartr/reference/temperature_drift.md)
  : Curing oven temperature drift
- [`bacterial_growth`](https://castlaboratory.github.io/shewhartr/reference/bacterial_growth.md)
  : Bacterial growth curve (optical density)
- [`cvd_recife`](https://castlaboratory.github.io/shewhartr/reference/cvd_recife.md)
  : COVID-19 daily mortality, Recife, Brazil, 2020

## Class predicates

- [`is_shewhart_chart()`](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  : Shewhart chart S3 class
