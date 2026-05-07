# Changelog

## shewhartr 1.2.0 (development version)

This release closes the remaining items from `dev/ROADMAP.md §11` that
were left for after v1.1: a plotly bridge and external numerical
validation against the long-established `qcc` package.

### Interactive plots: `as_plotly()`

- New generic
  [`as_plotly()`](https://castlaboratory.github.io/shewhartr/reference/as_plotly.md)
  with a `shewhart_chart` method that converts any chart into an
  interactive plotly figure. For two-panel charts (I-MR, X̄-R, X̄-S) the
  helper produces a
  [`plotly::subplot()`](https://rdrr.io/pkg/plotly/man/subplot.html)
  with a synchronised x-axis. `plotly` is in `Suggests`, so it is only
  loaded on demand.
- The `tooltip` argument is forwarded to
  [`plotly::ggplotly()`](https://rdrr.io/pkg/plotly/man/ggplotly.html)
  for full control of what hover boxes display.

### Validation against qcc

- New `tests/testthat/test-vs-qcc.R` (skipped silently if `qcc` is not
  installed) compares the limits computed by `shewhartr` to the
  reference values from the `qcc` package on its canonical example
  datasets — `pistonrings` for the variables charts, `orangejuice` for p
  / np, `circuit` for c. Every centre line and 3-sigma limit agrees with
  `qcc` to within 1e-3 absolute tolerance.

### Test hygiene

- `test-monitor.R` no longer triggers the (correct) “small c_bar”
  cli_warn from `chart-c.R`: the test data uses `lambda = 12` so the
  normal approximation is well-behaved. The 1-warning warning in
  `devtools::test()` is gone; the suite is now FAIL 0 / WARN 0.

## shewhartr 1.1.0

This release closes most of the items left open in `dev/ROADMAP.md §11`.

### New chart family: multivariate

- [`shewhart_hotelling()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_hotelling.md)
  is the package’s first multivariate chart — a Hotelling `T²` chart for
  jointly monitoring `p > 1` correlated variables. Both individual
  observations (`subgroup = NULL`) and subgrouped data are supported,
  with the appropriate exact Phase I limits (Beta for individuals, F for
  subgroups) and the slightly wider Phase II limits as derived in Tracy,
  Young & Mason (1992) and Montgomery (2019, Chapter 11). The
  implementation follows Mason & Young (2002).
- The augmented tibble carries the `T²` statistic per row, its
  decomposition by variable (the contribution of each variable to the
  alarm — useful when `T²` signals but no univariate chart does), and a
  logical flag against the appropriate chart-level UCL.
- Vignette `multivariate-charts` walks through the standard worked
  example: a chemical process with three correlated quality
  characteristics, showing how the multivariate chart catches a
  correlation-breaking shift that any of the three univariate charts
  would miss.

### Phase II for EWMA and CUSUM

- [`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
  now dispatches to `monitor_ewma()` and `monitor_cusum()`
  (`R/calibrate.R`), so the `calibrate(..., chart = "ewma")` /
  `monitor(new_data, calib)` workflow now works uniformly across every
  chart in the package — not just the Shewhart-style ones.
- [`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md)
  accepts the new keys `"ewma"`, `"cusum"`, `"hotelling"`.

### Bug fixes

- `SSgompertzDummy` self-starter is more robust: starting values for
  `b2` and `b3` are now derived from the cumulative-mid-point heuristic
  rather than hard-coded constants, fixing the convergence failure with
  typical sample sizes that previously required `\dontrun{}` in the
  example.

## shewhartr 1.0.0

This release is a comprehensive reposition of the package. The original
(`v0.1.x`, distributed as `Shewhart`) was COVID-focused and provided a
single function family for regression-based control charts. `v1.0.0` is
a full general-purpose SPC toolkit while preserving the regression-chart
speciality that motivated the package.

**Rename.** As part of the reposition, the package has been renamed
`Shewhart` → `shewhartr` to follow modern lowercase R-package
conventions and to free the name “Shewhart” for the methodology in text
and documentation. Update existing code with
[`library(shewhartr)`](https://castlaboratory.github.io/shewhartr/)
(formerly [`library(Shewhart)`](https://rdrr.io/r/base/library.html)).

The API has been substantially redesigned. Existing scripts written
against `v0.1.x` will not run unchanged.

### Repositioning

- The package is now a general-purpose SPC toolkit. The COVID-19 use
  case is preserved as a vignette case study (`covid-recife`), not as
  the organising principle.
- The package competes in the same space as `qcc` and `qicharts2`, and
  emphasises five differentiators: tidyverse-native API, broom
  integration, regression-based charts as a first-class citizen,
  embedded methodology (ARL, Box-Cox, runs tests), and an explicit Phase
  I / Phase II workflow.

### New chart families

- Variables:
  [`shewhart_i_mr()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_i_mr.md),
  [`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md),
  [`shewhart_xbar_s()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_s.md).
- Attributes:
  [`shewhart_p()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_p.md),
  [`shewhart_np()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_np.md),
  [`shewhart_c()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_c.md),
  [`shewhart_u()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_u.md).
  The c and u charts accept `limits = "poisson"` for exact Poisson
  quantile limits rather than the normal approximation.
- The flagship
  [`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md)
  replaces the old `shewhart()` function with a cleaner API, an
  extensible model menu (`auto`, `linear`, `log`, `loglog`, `gompertz`,
  `logistic`, plus user formulas), automatic phase detection via
  configurable runs rules, and proper handling of irregular time grids.
- Memory-based charts:
  [`shewhart_ewma()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_ewma.md)
  (Roberts 1959) for the Exponentially Weighted Moving Average chart,
  with both time-varying and steady-state limits, and
  [`shewhart_cusum()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_cusum.md)
  (Page 1954) for the two-sided tabular CUSUM chart with configurable
  reference value `k` and decision interval `h`. Both fit in the same S3
  / broom / autoplot pipeline as the classical charts.

### New methodology

- [`shewhart_runs()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_runs.md)
  implements the eight Nelson rules (1984, 1985) plus a Western Electric
  “7 in a row” variant for backward compatibility. Rule sets are
  user-configurable on every chart.
- [`shewhart_arl()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_arl.md)
  performs Monte Carlo Average Run Length simulation for arbitrary rule
  combinations.
- [`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
  returns the profile log-likelihood, optimal lambda, and 95% CI in the
  Box & Cox (1964) tradition.
- [`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md)
  produces a five-panel Tukey-style residual diagnostic display.
- [`shewhart_capability()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_capability.md)
  computes Cp/Cpk/Pp/Ppk with bootstrap confidence intervals.
- [`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md)
  and
  [`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
  provide an explicit Phase I / Phase II workflow.

### S3 / broom integration

- All charts return an S3 object of class `shewhart_chart` with a
  specific subclass.
- [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html),
  `tidy()`, `glance()` and `augment()` methods are provided for every
  chart type.

### Internationalisation

- All user-facing chart functions accept a `locale` argument (`"en"`,
  `"pt"`, `"es"`, `"fr"`) that controls plot labels and informative
  messages. Validation errors remain in English to facilitate cross-user
  debugging.

### Developer-facing changes

- `Depends` collapsed: the package no longer depends on the entire
  tidyverse meta-package or on `tibbletime`/`pals`/`scales`. The new
  `Imports` are minimal and explicit.
- `plotly` moved to `Suggests` to avoid pulling a heavy dependency for
  users who don’t need interactive plots.
- All input validation uses
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html) /
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  with multi-line, informative messages.
- `.onAttach()` no longer prints a banner.
- New `data-raw/build_all.R` script generates six synthetic datasets
  (`tablet_weight`, `bottle_fill`, `pcb_solder`, `claims_p`,
  `temperature_drift`, `bacterial_growth`).
- New documentation site built with `pkgdown` at
  <https://castlaboratory.github.io/shewhartr/>. Ten topical articles,
  including a dedicated `memory-based-charts` vignette covering EWMA,
  CUSUM and the trade-offs versus Shewhart-style charts.

### Breaking changes (full list)

- `shewhart()` (the plotting function) has been removed. Use
  [`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md)
  followed by
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html).
- `shewhart_fit()` is no longer exported. Use
  [`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md).
- `shewhart_model()` is no longer exported. Use
  [`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md).
- `shewhart_7points()` is no longer exported. Use
  `shewhart_runs(rule = "we_seven_same")` for the same behaviour, or the
  recommended `shewhart_runs(rule = "nelson_2_nine_same")`.
- The default phase-detection rule is now Nelson 2 (9 points same side;
  ARL_0 ~ 256), not the legacy 7-points-same-side (ARL_0 ~ 64). Pass
  `phase_rule = "we_seven_same"` to recover the old behaviour.
- The package banner printed on `.onAttach()` has been removed.
- All output column names follow broom-style with a leading `.`
  (`.fitted`, `.upper`, `.lower`, `.flag_*`).
