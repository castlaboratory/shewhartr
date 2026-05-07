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
  https://castlaboratory.github.io/shewhartr/.

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
