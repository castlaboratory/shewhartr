# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`shewhartr` is an R package (version 1.4.0, lifecycle: experimental; 1.3.0 is on CRAN, 1.4.0 submitted 2026-09-25) for Statistical Process Control. It is a comprehensive rewrite of an older COVID-focused package (`Shewhart` v0.1.x); the COVID use case now lives in the case-study vignettes (`covid-recife`, `article-charts`, `prospective-replay`) rather than driving the architecture. Read `dev/ROADMAP.md` for the design rationale behind the v1.0.0 reposition — it documents which v0.1.x decisions were rejected and why.

The theoretical lineage of the package — Shewhart (1926, 1939), Perla/Provost et al. (2020), Ferraz et al. (2020) — is summarised in `references/REFERENCIAL-TEORICO.md` (Portuguese), with each reference mapped to specific files/functions. Read it before making methodological design choices. The two Ferraz et al. (2020) papers are the SBPO proceedings PDF (`galoa-*.pdf`) and the Revista Brasileira de Estatística article (`rbe-78-245-2020.pdf`, whole issue, pp. 23-41); neither contains a Monte Carlo study — their "simulação" is the prospective replay of the seven-point rule. `references/` is gitignored (local only, so a fresh clone lacks it) and additionally excluded from the CRAN tarball via `.Rbuildignore` (the regex is `^references$` — do not add an inline comment, since `.Rbuildignore` does not support comments and the inline form silently breaks the rule).

The package targets the same niche as `qcc` and `qicharts2`, with five differentiators: tidyverse-native API, broom integration, regression-based charts as first-class citizens, embedded methodology (ARL by simulation, Box-Cox, Nelson runs tests), and an explicit Phase I / Phase II workflow.

## Development workflow

Common commands are run from R (preferred over `R CMD ...` for everyday work):

```r
devtools::document()        # regenerate NAMESPACE and man/*.Rd from roxygen
devtools::load_all()        # load the package into the R session
devtools::test()            # run the testthat suite (testthat edition 3)
devtools::check()           # full R CMD check — must pass before pushing
source("dev/build_site.R")  # rebuild the pkgdown site under docs/ (gitignored) and strip the orphan CLAUDE.* pages
```

A single test file: `devtools::test(filter = "i-mr")` (matches `tests/testthat/test-i-mr.R`). A single test by name: `testthat::test_file("tests/testthat/test-i-mr.R")`.

`source("quickstart.R")` runs document → rebuild data → document → test → optional pkgdown, in order. Use it after a fresh checkout or after editing `data-raw/`.

`source("data-raw/build_all.R")` regenerates the synthetic datasets shipped under `data/` (`tablet_weight`, `bottle_fill`, etc.) plus the COVID datasets (`cvd_recife` from `inst/extdata/cvd_recife_raw.rds`; `cvd_brazil` from `inst/extdata/cvd_states_raw.rds`, a wcota/covid19br snapshot of daily deaths for BR/PE/SP that keeps a real -37 bulletin correction on 2020-09-03). Always re-run `devtools::document()` afterwards because the dataset roxygen needs to pick up the new `.rda` files.

CI runs `R-CMD-check` on macOS, Windows, and Ubuntu (devel/release/oldrel-1) via `.github/workflows/R-CMD-check.yaml` — match its expectations locally with `devtools::check()`. Before a CRAN release run `devtools::check(cran = TRUE, remote = TRUE, manual = TRUE)`, `urlchecker::url_check()` and time every vignette (all must stay under ~10 s; `prospective-replay` is the slowest at ~8 s). The local roxygen2 is 8.0.0, which rewrites `Config/roxygen2/version` in DESCRIPTION and two unrelated Rd files on every `document()`; that drift is harmless and is committed. The Monte Carlo tests that verify the MEWMA/MCUSUM tables are `skip_on_cran()`.

The release cycle the maintainer expects after any non-trivial change: `document()` → full `test()` (must end `FAIL 0 | WARN 0`) → regenerate `man/figures/README-regression-cvd.png` if autoplot or the palette changed → `source("dev/build_site.R")` → commit with a long message that records the test count and check status → push. `dev/AUDIT-2026-09-25.md` is the record of the four-agent bug audit that produced 1.4.0; read it before touching capability, trimming, the h tables or the regression Phase II code.

## Architecture

### The `shewhart_chart` S3 hierarchy

Every public chart constructor (`shewhart_i_mr`, `shewhart_xbar_r`, `shewhart_xbar_s`, `shewhart_p`, `shewhart_np`, `shewhart_c`, `shewhart_u`, `shewhart_ewma`, `shewhart_cusum`, `shewhart_hotelling`, `shewhart_mewma`, `shewhart_mcusum`, `shewhart_regression`) returns an object that inherits from `shewhart_chart` with a more specific subclass like `shewhart_i_mr`. The constructor lives in `R/chart-base.R` (`new_shewhart_chart()`) and defines the canonical slot layout — read its file header for the anatomy. Subclasses may add extra slots without breaking shared methods.

Method dispatch follows the subclass: `print.shewhart_i_mr`, `autoplot.shewhart_xbar_r`, `tidy.shewhart_chart`, `glance.shewhart_chart`, `augment.shewhart_chart`, etc. Plotting lives in `R/autoplot.R`; broom methods in `R/broom.R`; print/summary in `R/print.R`.

When adding a new chart family, follow the existing pattern: a constructor file `R/chart-<name>.R` that builds the augmented tibble + limits tibble + violations and finishes by calling `new_shewhart_chart()`, plus a corresponding `monitor_<name>()` function in the same file (used by `monitor()` in `R/calibrate.R`).

### Phase I / Phase II split

`calibrate(data, ..., chart = "...")` and `monitor(new_data, calib)` in `R/calibrate.R` enforce the Woodall (2000) distinction. `calibrate()` is a thin wrapper that builds a chart and tags `$phase = "phase_1"`, optionally trimming out-of-control points iteratively (Montgomery 2019 §6.2.3). `monitor()` dispatches on `chart$type` to chart-specific `monitor_*()` helpers that reuse the *stored* limits — they never re-estimate. New chart types must register both a `shewhart_<name>()` constructor and a `monitor_<name>()` helper, then add their key to the `switch()` in `monitor()` and the `arg_match()` in `calibrate()`. Invariants that the 2026-09 audit found broken and that tests now enforce: a `monitor_*()` helper must emit the same augmented columns as its constructor (I-MR needs the `.mr*` columns); memory charts persist their state (`metadata$last_S` for MCUSUM, `last_Z`/`t_elapsed` for MEWMA) so chained `monitor()` calls continue; `trim_outliers` works on a running copy of the data and drops whole subgroups; subgroups are ordered by first appearance, never lexicographically.

### Runs tests as pluggable rules

`R/runs-tests.R` implements the eight Nelson rules as pure functions `rule_n1`..`rule_n8` over `(value, center, sigma)` returning a logical vector. `shewhart_runs()` orchestrates them; `shewhart_rules_available()` returns the catalog. Each chart constructor accepts a `rules =` character vector and forwards it to `flag_rules()`, which calls the individual rule functions and assembles the violations tibble. To add a new rule: add a `rule_<key>()` function, register it in the rules registry, and document its in-control ARL in the file header. A window containing NA never fires. The ARL_0 of a k-points-same-side rule under independence is 2^k - 1 (127 for seven, 511 for nine), not the inverse window probability (64/256), which older text repeated. Charts with exact Poisson/binomial limits evaluate rule 1 against the drawn `.lower`/`.upper`, not against 3 sigma; EWMA charts pass `sigma_eq = L * se / 3` so rule 1 matches the plotted limits.

### Constants and validation utilities

`R/utils-constants.R` ships the Montgomery (2019) Appendix VI table for `n = 2..25` and computes constants in closed form for larger `n`. Validation helpers (`check_data`, `check_column`, `check_numeric`, …) live in `R/utils-validation.R` and use `rlang::caller_arg()` / `rlang::caller_env()` plus `cli::cli_abort()` so error messages point at the user's call site, not the helper. Use these helpers for new validation; do not roll your own `stop()` calls.

### Localisation

`R/utils-locale.R` holds a translation table for `"en"`, `"pt"`, `"es"`, `"fr"`. `tr(key, locale)` looks up plot labels and informative messages; missing translations fall back to English, missing keys fall back to the literal key. Validation errors (anything via `cli::cli_abort`) intentionally stay in English to keep error messages diffable across users — only user-facing plot text and informational messages are localised. The `locale = ` argument on chart constructors threads through to the augmented tibble metadata so plotting picks it up.

### Regression chart specifics

`R/chart-regression.R` is the package's flagship and the most complex chart. It supports a model menu (`auto`, `linear`, `log`, `loglog`, `gompertz`, `logistic`, plus user-supplied formulas), automatic phase detection via configurable runs rules, and `limits_scale = c("original", "model")` ("model" computes sigma on the transformed scale and back-transforms the band, which is what Ferraz et al. (2020) did; bands become multiplicative and very wide in short phases with zero-count days, and the vignettes clip the y axis with `coord_cartesian()` instead of hiding that). The menu models regress on `.N`, the position within the phase (a deliberate roadmap choice, not the calendar index), and `monitor_regression()` continues `.N` from `metadata$phase_n_end` and uses the last phase's sigma from `metadata$phase_sigma`; do not reset either. Phase detection refits each phase on all its data once the next cut is known, so it does not reproduce a strictly prospective replay (see `vignettes/prospective-replay.Rmd`); `phase_changes = integer(0)` fits a single phase for such replays. `.phase_label` carries the phase end date when the index is a Date, and `autoplot()` wraps the phase legend in rows of five (issue #1). Growth-curve definitions live in `R/models-growth.R` and transformations in `R/transforms.R`; keep them callable in isolation so they remain testable.

## Conventions specific to this codebase

- File headers: most `R/*.R` files start with a multi-line block comment explaining the math, the references, and any non-obvious design choices. Maintain this style when editing — the headers are how the author hands context to future maintainers.
- Errors with `cli::cli_abort()`, warnings with `cli::cli_warn()`, info with `cli::cli_alert_info()`. Do not use base `stop`/`warning`/`message`.
- Tidy-eval: chart constructors take `data` first and use `rlang::enquo()` + `rlang::as_name()` for column references. Validate the resulting column name with `check_column()`.
- The package is renamed from `Shewhart` to `shewhartr` for the v1.0.0 release (lowercase R-package convention). Use `shewhartr` everywhere; do not reintroduce `library(Shewhart)`.
- `.onAttach` is intentionally absent — do not add a startup banner. CRAN dislikes them and the roadmap explicitly removed the old one.
- ASCII only in `R/*.R` (no em-dashes, no `T²` in code comments); non-ASCII is fine in vignettes and roxygen text.
- The MEWMA and MCUSUM decision-interval tables were re-derived by simulation (`dev/calibrate-h-tables.R`, 20 000 paths per cell, ARL_0 = 200); MEWMA has one table per covariance mode (`steady_state`). The EWMA default is `L = 2.86` (ARL_0 ~ 370 at lambda = 0.2). CUSUM and EWMA reject NA input. Change any of these only with a new simulation and a NEWS entry.
- The Portuguese label for the projected last phase is "Monitoramento" (the articles' word), not "Monitorando".
- Every issue fix carries a regression test that fails on the old code; when a fix changes a default, say so in NEWS with the finding or issue number.
