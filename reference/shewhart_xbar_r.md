# Xbar-R control chart for rational subgroups

Constructs a paired Xbar (subgroup mean) and R (subgroup range) chart
for measurements organised in rational subgroups of size 2 to 10. Sigma
is estimated from the average within-subgroup range.

## Usage

``` r
shewhart_xbar_r(
  data,
  value,
  subgroup,
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
object of subclass `shewhart_xbar_r`.

## Details

Xbar-chart limits use `A2(n)`; R-chart limits use `D3(n)` and `D4(n)`.
See
[`shewhart_constants()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_constants.md)
for the tabulated values.

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 6.

Shewhart, W. A. (1931). *Economic Control of Quality of Manufactured
Product*. D. Van Nostrand.

## Examples

``` r
set.seed(1)
df <- data.frame(
  batch = rep(1:25, each = 5),
  y     = rnorm(125, mean = 50, sd = 1.5)
)
fit <- shewhart_xbar_r(df, value = y, subgroup = batch)
print(fit)
#> 
#> ── Shewhart chart Xbar-R ───────────────────────────────────────────────────────
#> • Observations / subgroups: 25
#> • Phase: "phase_1"
#> • Sigma estimate ("range"): 1.328
#> 
#> ── Control limits ──
#> 
#> # A tibble: 6 × 3
#>   chart line  value
#>   <chr> <chr> <dbl>
#> 1 Xbar  CL    50.2 
#> 2 Xbar  UCL   51.9 
#> 3 Xbar  LCL   48.4 
#> 4 R     CL     3.09
#> 5 R     UCL    6.53
#> 6 R     LCL    0   
#> ── Rule violations ──
#> 
#> ✔ No violations across 2 rules: "nelson_1_beyond_3s" and "nelson_2_nine_same".
```
