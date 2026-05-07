# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this is

`shewhartr` is an R package (version 1.0.0, lifecycle: experimental) for
Statistical Process Control. It is a comprehensive rewrite of an older
COVID-focused package (`Shewhart` v0.1.x); the COVID use case now lives
in a single vignette (`covid-recife`) rather than driving the
architecture. Read `dev/ROADMAP.md` for the design rationale behind the
v1.0.0 reposition — it documents which v0.1.x decisions were rejected
and why.

The theoretical lineage of the package — Shewhart (1926, 1939),
Perla/Provost et al. (2020), Ferraz et al. (2020) — is summarised in
`references/REFERENCIAL-TEORICO.md` (Portuguese), with each reference
mapped to specific files/functions. Read it before making methodological
design choices. The `references/` directory is excluded from the CRAN
tarball via `.Rbuildignore` (the regex is `^references$` — do not add an
inline comment, since `.Rbuildignore` does not support comments and the
inline form silently breaks the rule).

The package targets the same niche as `qcc` and `qicharts2`, with five
differentiators: tidyverse-native API, broom integration,
regression-based charts as first-class citizens, embedded methodology
(ARL by simulation, Box-Cox, Nelson runs tests), and an explicit Phase I
/ Phase II workflow.

## Development workflow

Common commands are run from R (preferred over `R CMD ...` for everyday
work):

``` r

devtools::document()        # regenerate NAMESPACE and man/*.Rd from roxygen
devtools::load_all()        # load the package into the R session
devtools::test()            # run the testthat suite (testthat edition 3)
devtools::check()           # full R CMD check — must pass before pushing
pkgdown::build_site()       # rebuild the documentation site under docs/
```

A single test file: `devtools::test(filter = "i-mr")` (matches
`tests/testthat/test-i-mr.R`). A single test by name:
`testthat::test_file("tests/testthat/test-i-mr.R")`.

`source("quickstart.R")` runs document → rebuild data → document → test
→ optional pkgdown, in order. Use it after a fresh checkout or after
editing `data-raw/`.

`source("data-raw/build_all.R")` regenerates the synthetic datasets
shipped under `data/` (`tablet_weight`, `bottle_fill`, etc.) plus the
COVID dataset. Always re-run `devtools::document()` afterwards because
the dataset roxygen needs to pick up the new `.rda` files.

CI runs `R-CMD-check` on macOS, Windows, and Ubuntu
(devel/release/oldrel-1) via `.github/workflows/R-CMD-check.yaml` —
match its expectations locally with `devtools::check()`.

## Architecture

### The `shewhart_chart` S3 hierarchy

Every public chart constructor (`shewhart_i_mr`, `shewhart_xbar_r`,
`shewhart_xbar_s`, `shewhart_p`, `shewhart_np`, `shewhart_c`,
`shewhart_u`, `shewhart_regression`) returns an object that inherits
from `shewhart_chart` with a more specific subclass like
`shewhart_i_mr`. The constructor lives in `R/chart-base.R`
(`new_shewhart_chart()`) and defines the canonical slot layout — read
its file header for the anatomy. Subclasses may add extra slots without
breaking shared methods.

Method dispatch follows the subclass: `print.shewhart_i_mr`,
`autoplot.shewhart_xbar_r`, `tidy.shewhart_chart`,
`glance.shewhart_chart`, `augment.shewhart_chart`, etc. Plotting lives
in `R/autoplot.R`; broom methods in `R/broom.R`; print/summary in
`R/print.R`.

When adding a new chart family, follow the existing pattern: a
constructor file `R/chart-<name>.R` that builds the augmented tibble +
limits tibble + violations and finishes by calling
`new_shewhart_chart()`, plus a corresponding `monitor_<name>()` function
in the same file (used by
[`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
in `R/calibrate.R`).

### Phase I / Phase II split

`calibrate(data, ..., chart = "...")` and `monitor(new_data, calib)` in
`R/calibrate.R` enforce the Woodall (2000) distinction.
[`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md)
is a thin wrapper that builds a chart and tags `$phase = "phase_1"`,
optionally trimming out-of-control points iteratively (Montgomery 2019
§6.2.3).
[`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
dispatches on `chart$type` to chart-specific `monitor_*()` helpers that
reuse the *stored* limits — they never re-estimate. New chart types must
register both a `shewhart_<name>()` constructor and a `monitor_<name>()`
helper, then add their key to the
[`switch()`](https://rdrr.io/r/base/switch.html) in
[`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
and the `arg_match()` in
[`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md).

### Runs tests as pluggable rules

`R/runs-tests.R` implements the eight Nelson rules as pure functions
`rule_n1`..`rule_n8` over `(value, center, sigma)` returning a logical
vector.
[`shewhart_runs()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_runs.md)
orchestrates them;
[`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md)
returns the catalog. Each chart constructor accepts a `rules =`
character vector and forwards it to `flag_rules()`, which calls the
individual rule functions and assembles the violations tibble. To add a
new rule: add a `rule_<key>()` function, register it in the rules
registry, and document its in-control ARL in the file header.

### Constants and validation utilities

`R/utils-constants.R` ships the Montgomery (2019) Appendix VI table for
`n = 2..25` and computes constants in closed form for larger `n`.
Validation helpers (`check_data`, `check_column`, `check_numeric`, …)
live in `R/utils-validation.R` and use
[`rlang::caller_arg()`](https://rlang.r-lib.org/reference/caller_arg.html)
/ [`rlang::caller_env()`](https://rlang.r-lib.org/reference/stack.html)
plus
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html) so
error messages point at the user’s call site, not the helper. Use these
helpers for new validation; do not roll your own
[`stop()`](https://rdrr.io/r/base/stop.html) calls.

### Localisation

`R/utils-locale.R` holds a translation table for `"en"`, `"pt"`, `"es"`,
`"fr"`. `tr(key, locale)` looks up plot labels and informative messages;
missing translations fall back to English, missing keys fall back to the
literal key. Validation errors (anything via
[`cli::cli_abort`](https://cli.r-lib.org/reference/cli_abort.html))
intentionally stay in English to keep error messages diffable across
users — only user-facing plot text and informational messages are
localised. The `locale =` argument on chart constructors threads through
to the augmented tibble metadata so plotting picks it up.

### Regression chart specifics

`R/chart-regression.R` is the package’s flagship and the most complex
chart. It supports a model menu (`auto`, `linear`, `log`, `loglog`,
`gompertz`, `logistic`, plus user-supplied formulas), automatic phase
detection via configurable runs rules, and irregular time grids (do not
assume daily spacing — the v0.1.x code had a bug here documented in the
roadmap). Growth-curve definitions live in `R/models-growth.R` and
transformations in `R/transforms.R`; keep them callable in isolation so
they remain testable.

## Conventions specific to this codebase

- File headers: most `R/*.R` files start with a multi-line block comment
  explaining the math, the references, and any non-obvious design
  choices. Maintain this style when editing — the headers are how the
  author hands context to future maintainers.
- Errors with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html),
  warnings with
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html),
  info with
  [`cli::cli_alert_info()`](https://cli.r-lib.org/reference/cli_alert.html).
  Do not use base `stop`/`warning`/`message`.
- Tidy-eval: chart constructors take `data` first and use
  [`rlang::enquo()`](https://rlang.r-lib.org/reference/enquo.html) +
  [`rlang::as_name()`](https://rlang.r-lib.org/reference/as_name.html)
  for column references. Validate the resulting column name with
  `check_column()`.
- The package is renamed from `Shewhart` to `shewhartr` for the v1.0.0
  release (lowercase R-package convention). Use `shewhartr` everywhere;
  do not reintroduce
  [`library(Shewhart)`](https://rdrr.io/r/base/library.html).
- `.onAttach` is intentionally absent — do not add a startup banner.
  CRAN dislikes them and the roadmap explicitly removed the old one.
