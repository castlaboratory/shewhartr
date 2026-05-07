# Glance at a Shewhart chart's overall diagnostics

Returns a one-row tibble with overall chart-level diagnostics suitable
for filling a row in a comparison table.

## Usage

``` r
# S3 method for class 'shewhart_chart'
glance(x, ...)
```

## Arguments

- x:

  A
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object.

- ...:

  Currently unused.

## Value

A one-row tibble with columns `type`, `n`, `phase`, `sigma_hat`,
`sigma_method`, `n_violations`, `n_rules`, `pct_violations`.

## Examples

``` r
fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
broom::glance(fit)
#> # A tibble: 1 × 8
#>   type      n phase   sigma_hat sigma_method n_violations n_rules pct_violations
#>   <chr> <int> <chr>       <dbl> <chr>               <int>   <int>          <dbl>
#> 1 i_mr     50 phase_1     0.880 mr                      1       2           0.02
```
