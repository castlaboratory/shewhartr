# Xbar-S control chart for rational subgroups

Like
[`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md),
but uses the subgroup standard deviation (S) instead of the range.
Recommended for subgroup sizes greater than 10, or when subgroup sizes
differ.

## Usage

``` r
shewhart_xbar_s(
  data,
  value,
  subgroup,
  sigma_method = c("sbar", "pooled_sd"),
  rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
  locale = getOption("shewhart.locale", "en"),
  verbose = NULL
)
```

## Arguments

- data:

  A data frame.

- value:

  Tidy-eval column reference for the measurement.

- subgroup:

  Tidy-eval column reference identifying the subgroup (e.g. shift,
  batch, hour). All subgroups must have equal size.

- sigma_method:

  One of `"sbar"` (default; classical S-bar / c4(n)) or `"pooled_sd"`
  (pooled within-subgroup SD; preferred when subgroups have different
  sizes).

- rules:

  Character vector of rule keys to apply. See
  [`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md).
  Default applies Nelson 1 and 2.

- locale:

  One of `"en"`, `"pt"`, `"es"`, `"fr"`. Affects plot labels and
  informative messages.

- verbose:

  Logical. Print progress messages? Defaults to the `shewhart.verbose`
  option.

## Value

A
[shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
object of subclass `shewhart_xbar_s`.

## Details

Xbar-chart limits use `A3(n)`; S-chart limits use `B3(n)` and `B4(n)`.
When `sigma_method = "pooled_sd"`, sigma is estimated as the pooled
within-subgroup standard deviation.

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 6.4.

## Examples

``` r
set.seed(1)
df <- data.frame(
  batch = rep(1:30, each = 12),
  y     = rnorm(360, mean = 80, sd = 0.6)
)
fit <- shewhart_xbar_s(df, value = y, subgroup = batch)
print(fit)
#> 
#> ── Shewhart chart Xbar-S ───────────────────────────────────────────────────────
#> • Observations / subgroups: 30
#> • Phase: "phase_1"
#> • Sigma estimate ("sbar"): 0.5802
#> 
#> ── Control limits ──
#> 
#> # A tibble: 6 × 3
#>   chart line   value
#>   <chr> <chr>  <dbl>
#> 1 Xbar  CL    80.0  
#> 2 Xbar  UCL   80.5  
#> 3 Xbar  LCL   79.5  
#> 4 S     CL     0.567
#> 5 S     UCL    0.934
#> 6 S     LCL    0.201
#> ── Rule violations ──
#> 
#> ✔ No violations across 2 rules: "nelson_1_beyond_3s" and "nelson_2_nine_same".
```
