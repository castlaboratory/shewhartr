# shewhartr: Statistical Process Control with Tidyverse-Native Workflows

The `shewhartr` package brings classical Statistical Process Control
(SPC) methodology into a modern, tidy-friendly R workflow. It implements
the full family of classical Shewhart control charts (I-MR, Xbar-R,
Xbar-S, p, np, c, u), regression-based charts for processes with trend,
runs tests (Nelson 1-8), Average Run Length (ARL) simulation, process
capability indices, Box-Cox guidance, and an explicit Phase I / Phase II
workflow.

## Design principles

- Tidyverse-native:

  All constructors take `data` as the first argument, support tidy
  evaluation for column references via `{{ }}`, and accept a `.by`
  argument where group-aware behaviour makes sense.

- Object-oriented:

  Every chart returns an S3 object of class `shewhart_chart` (with a
  specific subclass like `shewhart_i_mr`) supporting
  [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html),
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html),
  `tidy()`, `glance()` and `augment()`.

- Diagnostic-rich:

  Every chart can be passed through
  [`shewhart_runs()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_runs.md)
  (configurable rule sets),
  [`shewhart_arl()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_arl.md)
  (Monte Carlo ARL),
  [`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md)
  (Tukey-style residual panel) and
  [`shewhart_capability()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_capability.md)
  (Cp, Cpk, Pp, Ppk with bootstrap CI).

- Statistically honest:

  Counts are charted with exact Poisson limits when requested
  (`limits = "poisson"`), per Box's advice to model the right
  distribution rather than transform.

- Robust alternatives:

  Most charts accept `sigma_method = "biweight"` for Tukey-style robust
  scale estimation as an alternative to the classical moving range.

- Internationalisation:

  Plot labels and informative messages accept a `locale` argument
  (`"en"`, `"pt"`, `"es"`, `"fr"`).

## The four families of functions

- Classical charts (variables):

  [`shewhart_i_mr()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_i_mr.md),
  [`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md),
  [`shewhart_xbar_s()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_s.md).

- Classical charts (attributes):

  [`shewhart_p()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_p.md),
  [`shewhart_np()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_np.md),
  [`shewhart_c()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_c.md),
  [`shewhart_u()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_u.md).

- Regression-based chart:

  [`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md)
  for trended processes, with optional automatic phase detection via the
  runs test.

- Diagnostics & methodology:

  [`shewhart_runs()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_runs.md),
  [`shewhart_arl()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_arl.md),
  [`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md),
  [`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md),
  [`shewhart_capability()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_capability.md),
  [`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md),
  [`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md).

## Recommended starting points

New users should start with
[`vignette("getting-started", package = "shewhartr")`](https://castlaboratory.github.io/shewhartr/articles/getting-started.md)
for a 5-minute overview, then move to the chart family that matches
their data type. The vignette `"phase1-phase2"` explains the central
distinction between estimation and monitoring, and `"arl-simulation"`
shows how to evaluate the operating characteristics of any chart
configuration.

## References

Shewhart, W. A. (1931). *Economic Control of Quality of Manufactured
Product*. D. Van Nostrand.

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. ISBN: 978-1-119-39930-8.

Nelson, L. S. (1984). The Shewhart Control Chart - Tests for Special
Causes. *Journal of Quality Technology*, 16(4), 237-239.
[doi:10.1080/00224065.1984.11978921](https://doi.org/10.1080/00224065.1984.11978921)

Woodall, W. H. (2000). Controversies and Contradictions in Statistical
Process Control. *Journal of Quality Technology*, 32(4), 341-350.
[doi:10.1080/00224065.2000.11980013](https://doi.org/10.1080/00224065.2000.11980013)

Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
*Journal of the Royal Statistical Society, Series B*, 26(2), 211-252.
[doi:10.1111/j.2517-6161.1964.tb00553.x](https://doi.org/10.1111/j.2517-6161.1964.tb00553.x)

Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.

Wheeler, D. J., & Chambers, D. S. (1992). *Understanding Statistical
Process Control* (2nd ed.). SPC Press.

## See also

Useful links:

- <https://castlaboratory.github.io/shewhartr/>

- <https://github.com/castlaboratory/shewhartr>

- Report bugs at <https://github.com/castlaboratory/shewhartr/issues>

## Author

**Maintainer**: André Leite <leite@castlab.org>

Authors:

- Hugo Vasconcelos <hugo.vasconcelos@ufpe.br>

- Raydonal Ospina <raydonal@castlab.org>

- Cristiano Ferraz <cferraz@castlab.org>

Other contributors:

- Castlab \[copyright holder, funder\]
