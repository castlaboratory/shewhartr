# shewhartr 1.3.0 (development version)

## New chart family

* `shewhart_mewma()` — Multivariate Exponentially Weighted Moving
  Average chart (Lowry, Woodall, Champ & Rigdon 1992). Joint
  monitoring of `p > 1` correlated variables for *small persistent*
  shifts in the vector mean — the multivariate analogue of
  `shewhart_ewma()`. Supports both time-varying and steady-state
  covariance, decision interval `h` calibrated by lookup in the
  Prabhu & Runger (1997) table for `ARL_0 ~ 200`, and the same
  `calibrate()` / `monitor()` Phase I / Phase II workflow as the
  rest of the package.

## Visual identity

* Every `autoplot()` method now uses `shewhart_palette()` and
  `shewhart_theme()`, so plots from any chart family share the
  same editorial look (off-white surface, single horizontal grid,
  bold left-aligned title, sequential phase palette, hollow firebrick
  rings on out-of-control points). Out-of-control marks
  centralised in a new internal `violation_layers()` helper, sized
  at halo 1.7 / ring 1.4 / stroke 0.7.
* Regression chart legend title is now plural and bold ("Phases" /
  "Fases") and uses localised `Phase 0`, `Phase 1`, … labels via
  the `phase_n` and new `legend_phases` locale entries.
* The `arl-simulation` vignette's hand-rolled chart was using
  `theme_minimal()` with default ggplot2 colours; now uses
  `shewhart_theme()` and the package palette so it matches the rest.

## Bug fixes / hygiene

* Three U+2014 em-dash characters in `R/autoplot.R` (two comments,
  one string literal) replaced with ASCII alternatives or the
  `—` escape so `R CMD check` no longer warns about non-ASCII
  source.

# shewhartr 1.2.0

This release closes the remaining items from `dev/ROADMAP.md §11`
that were left for after v1.1: a plotly bridge and external numerical
validation against the long-established `qcc` package.

## Interactive plots: `as_plotly()`

* New generic `as_plotly()` with a `shewhart_chart` method that
  converts any chart into an interactive plotly figure. For
  two-panel charts (I-MR, X̄-R, X̄-S) the helper produces a
  `plotly::subplot()` with a synchronised x-axis. `plotly` is in
  `Suggests`, so it is only loaded on demand.
* The `tooltip` argument is forwarded to `plotly::ggplotly()` for
  full control of what hover boxes display.

## Validation against qcc

* New `tests/testthat/test-vs-qcc.R` (skipped silently if `qcc` is
  not installed) compares the limits computed by `shewhartr` to the
  reference values from the `qcc` package on its canonical example
  datasets — `pistonrings` for the variables charts, `orangejuice`
  for p / np, `circuit` for c. Every centre line and 3-sigma limit
  agrees with `qcc` to within 1e-3 absolute tolerance.

## Test hygiene

* `test-monitor.R` no longer triggers the (correct) "small c_bar"
  cli_warn from `chart-c.R`: the test data uses `lambda = 12` so
  the normal approximation is well-behaved. The 1-warning warning
  in `devtools::test()` is gone; the suite is now FAIL 0 / WARN 0.

# shewhartr 1.1.0

This release closes most of the items left open in `dev/ROADMAP.md §11`.

## New chart family: multivariate

* `shewhart_hotelling()` is the package's first multivariate chart —
  a Hotelling `T²` chart for jointly monitoring `p > 1` correlated
  variables. Both individual observations (`subgroup = NULL`) and
  subgrouped data are supported, with the appropriate exact Phase I
  limits (Beta for individuals, F for subgroups) and the slightly
  wider Phase II limits as derived in Tracy, Young & Mason (1992)
  and Montgomery (2019, Chapter 11). The implementation follows
  Mason & Young (2002).
* The augmented tibble carries the `T²` statistic per row, its
  decomposition by variable (the contribution of each variable to
  the alarm — useful when `T²` signals but no univariate chart does),
  and a logical flag against the appropriate chart-level UCL.
* Vignette `multivariate-charts` walks through the standard worked
  example: a chemical process with three correlated quality
  characteristics, showing how the multivariate chart catches a
  correlation-breaking shift that any of the three univariate charts
  would miss.

## Phase II for EWMA and CUSUM

* `monitor()` now dispatches to `monitor_ewma()` and `monitor_cusum()`
  (`R/calibrate.R`), so the `calibrate(..., chart = "ewma")` /
  `monitor(new_data, calib)` workflow now works uniformly across
  every chart in the package — not just the Shewhart-style ones.
* `calibrate()` accepts the new keys `"ewma"`, `"cusum"`, `"hotelling"`.

## Bug fixes

* `SSgompertzDummy` self-starter is more robust: starting values for
  `b2` and `b3` are now derived from the cumulative-mid-point heuristic
  rather than hard-coded constants, fixing the convergence failure
  with typical sample sizes that previously required `\dontrun{}` in
  the example.

# shewhartr 1.0.0

This release is a comprehensive reposition of the package. The original
(`v0.1.x`, distributed as `Shewhart`) was COVID-focused and provided a
single function family for regression-based control charts. `v1.0.0`
is a full general-purpose SPC toolkit while preserving the
regression-chart speciality that motivated the package.

**Rename.** As part of the reposition, the package has been renamed
`Shewhart` → `shewhartr` to follow modern lowercase R-package
conventions and to free the name "Shewhart" for the methodology in
text and documentation. Update existing code with
`library(shewhartr)` (formerly `library(Shewhart)`).

The API has been substantially redesigned. Existing scripts written
against `v0.1.x` will not run unchanged.

## Repositioning

* The package is now a general-purpose SPC toolkit. The COVID-19 use
  case is preserved as a vignette case study (`covid-recife`), not as
  the organising principle.
* The package competes in the same space as `qcc` and `qicharts2`, and
  emphasises five differentiators: tidyverse-native API, broom
  integration, regression-based charts as a first-class citizen,
  embedded methodology (ARL, Box-Cox, runs tests), and an explicit
  Phase I / Phase II workflow.

## New chart families

* Variables: `shewhart_i_mr()`, `shewhart_xbar_r()`, `shewhart_xbar_s()`.
* Attributes: `shewhart_p()`, `shewhart_np()`, `shewhart_c()`,
  `shewhart_u()`. The c and u charts accept `limits = "poisson"` for
  exact Poisson quantile limits rather than the normal approximation.
* The flagship `shewhart_regression()` replaces the old `shewhart()`
  function with a cleaner API, an extensible model menu (`auto`,
  `linear`, `log`, `loglog`, `gompertz`, `logistic`, plus user
  formulas), automatic phase detection via configurable runs rules,
  and proper handling of irregular time grids.
* Memory-based charts: `shewhart_ewma()` (Roberts 1959) for the
  Exponentially Weighted Moving Average chart, with both time-varying
  and steady-state limits, and `shewhart_cusum()` (Page 1954) for the
  two-sided tabular CUSUM chart with configurable reference value `k`
  and decision interval `h`. Both fit in the same S3 / broom / autoplot
  pipeline as the classical charts.

## New methodology

* `shewhart_runs()` implements the eight Nelson rules (1984, 1985)
  plus a Western Electric "7 in a row" variant for backward
  compatibility. Rule sets are user-configurable on every chart.
* `shewhart_arl()` performs Monte Carlo Average Run Length simulation
  for arbitrary rule combinations.
* `shewhart_box_cox()` returns the profile log-likelihood, optimal
  lambda, and 95% CI in the Box & Cox (1964) tradition.
* `shewhart_diagnostics()` produces a five-panel Tukey-style residual
  diagnostic display.
* `shewhart_capability()` computes Cp/Cpk/Pp/Ppk with bootstrap
  confidence intervals.
* `calibrate()` and `monitor()` provide an explicit Phase I / Phase II
  workflow.

## S3 / broom integration

* All charts return an S3 object of class `shewhart_chart` with a
  specific subclass.
* `print()`, `summary()`, `autoplot()`, `tidy()`, `glance()` and
  `augment()` methods are provided for every chart type.

## Internationalisation

* All user-facing chart functions accept a `locale` argument
  (`"en"`, `"pt"`, `"es"`, `"fr"`) that controls plot labels and
  informative messages. Validation errors remain in English to
  facilitate cross-user debugging.

## Developer-facing changes

* `Depends` collapsed: the package no longer depends on the entire
  tidyverse meta-package or on `tibbletime`/`pals`/`scales`. The new
  `Imports` are minimal and explicit.
* `plotly` moved to `Suggests` to avoid pulling a heavy dependency
  for users who don't need interactive plots.
* All input validation uses `cli::cli_abort()` / `cli::cli_warn()`
  with multi-line, informative messages.
* `.onAttach()` no longer prints a banner.
* New `data-raw/build_all.R` script generates six synthetic datasets
  (`tablet_weight`, `bottle_fill`, `pcb_solder`, `claims_p`,
  `temperature_drift`, `bacterial_growth`).
* New documentation site built with `pkgdown` at
  https://castlaboratory.github.io/shewhartr/. Ten topical articles,
  including a dedicated `memory-based-charts` vignette covering
  EWMA, CUSUM and the trade-offs versus Shewhart-style charts.

## Breaking changes (full list)

* `shewhart()` (the plotting function) has been removed. Use
  `shewhart_regression()` followed by `autoplot()`.
* `shewhart_fit()` is no longer exported. Use `shewhart_regression()`.
* `shewhart_model()` is no longer exported. Use `shewhart_regression()`.
* `shewhart_7points()` is no longer exported. Use
  `shewhart_runs(rule = "we_seven_same")` for the same behaviour, or
  the recommended `shewhart_runs(rule = "nelson_2_nine_same")`.
* The default phase-detection rule is now Nelson 2 (9 points same
  side; ARL_0 ~ 256), not the legacy 7-points-same-side
  (ARL_0 ~ 64). Pass `phase_rule = "we_seven_same"` to recover the
  old behaviour.
* The package banner printed on `.onAttach()` has been removed.
* All output column names follow broom-style with a leading `.`
  (`.fitted`, `.upper`, `.lower`, `.flag_*`).
