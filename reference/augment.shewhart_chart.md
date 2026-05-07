# Augment new data with control-chart annotations

Returns the per-observation augmented tibble, optionally re-aligned
against fresh data passed via `newdata` (Phase II monitoring). When
`newdata` is `NULL`, returns the in-sample augmented tibble.

## Usage

``` r
# S3 method for class 'shewhart_chart'
augment(x, newdata = NULL, ...)
```

## Arguments

- x:

  A
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object.

- newdata:

  Optional data frame with the same columns as the data used to fit `x`.
  If supplied, control limits are propagated to the new rows (Phase II
  monitoring) and rule violations are re-evaluated.

- ...:

  Currently unused.

## Value

A tibble. When `newdata = NULL`, the chart's augmented tibble; otherwise
the same shape but for `newdata`.

## Examples

``` r
set.seed(1)
df <- data.frame(y = rnorm(50))
fit <- shewhart_i_mr(df, value = y)
broom::augment(fit)
#> # A tibble: 50 × 14
#>    index  .obs .value .center .sigma .upper .lower    .mr .mr_center .mr_upper
#>    <int> <int>  <dbl>   <dbl>  <dbl>  <dbl>  <dbl>  <dbl>      <dbl>     <dbl>
#>  1     1     1 -0.626   0.100  0.808   2.53  -2.32 NA          0.912      2.98
#>  2     2     2  0.184   0.100  0.808   2.53  -2.32  0.810      0.912      2.98
#>  3     3     3 -0.836   0.100  0.808   2.53  -2.32  1.02       0.912      2.98
#>  4     4     4  1.60    0.100  0.808   2.53  -2.32  2.43       0.912      2.98
#>  5     5     5  0.330   0.100  0.808   2.53  -2.32  1.27       0.912      2.98
#>  6     6     6 -0.820   0.100  0.808   2.53  -2.32  1.15       0.912      2.98
#>  7     7     7  0.487   0.100  0.808   2.53  -2.32  1.31       0.912      2.98
#>  8     8     8  0.738   0.100  0.808   2.53  -2.32  0.251      0.912      2.98
#>  9     9     9  0.576   0.100  0.808   2.53  -2.32  0.163      0.912      2.98
#> 10    10    10 -0.305   0.100  0.808   2.53  -2.32  0.881      0.912      2.98
#> # ℹ 40 more rows
#> # ℹ 4 more variables: .mr_lower <dbl>, .flag_nelson_1_beyond_3s <lgl>,
#> #   .flag_nelson_2_nine_same <lgl>, .flag_any <lgl>
```
