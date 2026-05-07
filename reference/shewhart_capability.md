# Process capability indices Cp, Cpk, Pp, Ppk

Computes the four classical capability indices for a Shewhart chart or a
raw vector. Optionally returns bootstrap confidence intervals.

## Usage

``` r
shewhart_capability(
  data,
  lsl = NA_real_,
  usl = NA_real_,
  target = NA_real_,
  ci_level = 0.95,
  n_boot = 2000L,
  seed = NULL
)
```

## Arguments

- data:

  A
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object or a numeric vector.

- lsl, usl:

  Numeric scalars. Lower and upper specification limits. At least one
  must be supplied.

- target:

  Numeric scalar. Optional process target. If missing, defaults to the
  midpoint of `(lsl, usl)`.

- ci_level:

  Numeric. Confidence level for bootstrap intervals. Default `0.95`. Set
  to `NA` to skip bootstrap.

- n_boot:

  Integer. Number of bootstrap replicates. Default 2000.

- seed:

  Optional integer for reproducibility.

## Value

A list of class `shewhart_capability` with point estimates and
(optionally) bootstrap CIs.

## Details

For a `shewhart_chart` of type `i_mr`, `xbar_r`, or `xbar_s`, the
within-subgroup sigma stored on the chart object is used for Cp/Cpk; the
overall standard deviation of the raw data is used for Pp/Ppk. For a
numeric vector `data`, a single sigma is used for both pairs (so Cp = Pp
and Cpk = Ppk).

Capability indices are only meaningful when the process is in
statistical control (Phase I). The function emits a warning if the
supplied chart has any rule violations.

## References

Kotz, S., & Lovelace, C. R. (1998). *Process Capability Indices in
Theory and Practice*. Arnold.

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 8.

Pearn, W. L., & Kotz, S. (2006). *Encyclopedia and Handbook of Process
Capability Indices*. World Scientific.

## Examples

``` r
# \donttest{
set.seed(1)
df <- data.frame(y = rnorm(100, mean = 50, sd = 0.8))
fit <- shewhart_i_mr(df, value = y)
cap <- shewhart_capability(fit, lsl = 47, usl = 53, target = 50)
print(cap)
#> 
#> ── Process capability ──────────────────────────────────────────────────────────
#> • n = 100, mean = 50.0871
#> • Sigma within = 0.73, sigma overall = 0.7186
#> • LSL = 47, USL = 53, target = 50
#> 
#> ── Indices ──
#> 
#> # A tibble: 4 × 4
#>   index value lower upper
#>   <chr> <dbl> <dbl> <dbl>
#> 1 Cp     1.37  1.23  1.63
#> 2 Cpk    1.33  1.18  1.58
#> 3 Pp     1.39  1.23  1.63
#> 4 Ppk    1.35  1.18  1.58
# }
```
