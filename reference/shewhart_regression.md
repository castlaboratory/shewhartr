# Regression-based control chart for processes with trend

Fits a chosen model to the data (linear, log, log-log, Gompertz,
logistic, or a user-supplied formula), then constructs control limits
around the fitted curve using the moving-range estimator on the
residuals (Wheeler 1992). Optionally detects phase changes automatically
via runs tests on the residuals and re-fits each phase.

## Usage

``` r
shewhart_regression(
  data,
  value,
  index,
  model = c("auto", "linear", "log", "loglog", "gompertz", "logistic"),
  formula = NULL,
  dummy = NULL,
  start_base = 10L,
  phase_changes = NULL,
  phase_rule = "nelson_2_nine_same",
  rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
  sigma_method = c("mr", "median_mr", "biweight", "sd"),
  lower_bound = NA_real_,
  locale = getOption("shewhart.locale", "en"),
  verbose = NULL
)
```

## Arguments

- data:

  A data frame.

- value:

  Tidy-eval column reference for the response.

- index:

  Tidy-eval column reference for the predictor (typically time, but can
  be any continuous variable).

- model:

  Character. One of `"auto"` (Box-Cox guidance), `"linear"`, `"log"`
  (fits `log(y + 1) ~ N`), `"loglog"`, `"gompertz"`, `"logistic"`. For
  full control, supply `formula` instead.

- formula:

  Optional one-sided or two-sided formula referencing columns in `data`.
  If provided, overrides `model`.

- dummy:

  Optional tidy-eval column reference for an additive covariate (a
  "dummy" in the original v0.1 nomenclature; can be any factor or
  numeric covariate the user wants to adjust for, such as day-of-week
  effects or treatment indicators).

- start_base:

  Integer. Number of initial observations used to estimate the first
  phase. Defaults to 10.

- phase_changes:

  Optional vector of index positions or values at which to force a phase
  change. If `NULL`, phase changes are detected automatically using the
  supplied `phase_rule`.

- phase_rule:

  Character. Runs rule used to detect new phases. See
  [`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md).
  Default Nelson 2 (9 points same side; ARL_0 ~ 256). For backward
  compatibility with v0.1.x, use `"we_seven_same"` (7 points; ARL_0 ~
  64).

- rules:

  Character vector of rules to flag on the final chart.

- sigma_method:

  One of `"mr"` (default), `"median_mr"`, `"biweight"` (Tukey-style
  robust), or `"sd"`.

- lower_bound:

  Numeric scalar or `NA`. If non-`NA`, lower limit is clipped at this
  value (commonly 0 for counts). Default `NA` (no clipping).

- locale:

  Character. One of `"en"`, `"pt"`, `"es"`, `"fr"`.

- verbose:

  Logical. Print progress messages?

## Value

A
[shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
object of subclass `shewhart_regression`. The `fits` slot contains a
list of fitted model objects (one per phase).

## Details

This is the package's flagship chart, intended for trended or
non-stationary processes for which classical Shewhart charts give
systematically wrong limits. See the vignette `regression-charts` for a
thorough discussion and examples.

## References

Mandel, B. J. (1969). The Regression Control Chart. *Journal of Quality
Technology*, 1(1), 1-9.
[doi:10.1080/00224065.1969.11980341](https://doi.org/10.1080/00224065.1969.11980341)

Wheeler, D. J., & Chambers, D. S. (1992). *Understanding Statistical
Process Control* (2nd ed.). SPC Press.

Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
*Journal of the Royal Statistical Society, Series B*, 26(2), 211-252.
[doi:10.1111/j.2517-6161.1964.tb00553.x](https://doi.org/10.1111/j.2517-6161.1964.tb00553.x)

## Examples

``` r
# \donttest{
set.seed(1)
df <- data.frame(
  t = 1:60,
  y = c(1:30 * 0.5 + rnorm(30, sd = 0.5),    # phase 1: linear trend
        15 + 1:30 * 0.1 + rnorm(30, sd = 0.5)) # phase 2: shift + slowdown
)
fit <- shewhart_regression(df, value = y, index = t, model = "linear")
print(fit)
#> 
#> ── Shewhart chart regression-based ─────────────────────────────────────────────
#> • Observations / subgroups: 60
#> • Phase: "phase_1"
#> • Sigma estimate ("mr"): 0.4142
#> 
#> ── Control limits ──
#> 
#> # A tibble: 4 × 7
#>   .phase cl_first ucl_first lcl_first cl_last ucl_last lcl_last
#>    <int>    <dbl>     <dbl>     <dbl>   <dbl>    <dbl>    <dbl>
#> 1      0    0.443      1.82    -0.936    5.19     6.57     3.81
#> 2      1    5.59       7.34     3.84     9.05    10.8      7.30
#> 3      2   10.4       11.6      9.16    16.4     17.6     15.2 
#> 4      3   15.9       17.2     14.7     18.1     19.3     16.8 
#> ── Rule violations ──
#> 
#> ! 1 violation across 2 rules.
#> nelson_1_beyond_3s: 1 hit.
ggplot2::autoplot(fit)

# }
```
