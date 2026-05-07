# Compact tibble-like summary

Compact tibble-like summary

## Usage

``` r
# S3 method for class 'shewhart_chart'
summary(object, ...)
```

## Arguments

- object:

  A
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object.

- ...:

  Currently unused.

## Value

A list with elements `limits` and `violations`.

## Examples

``` r
fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
summary(fit)
#> 
#> ── Summary of <shewhart_chart>: i_mr ───────────────────────────────────────────
#> • n = 50, phase = "phase_1", sigma = 0.9298
#> • Rules: "nelson_1_beyond_3s" and "nelson_2_nine_same"
#> • Violations: 0
#> 
#> ── Limits ──
#> 
#> # A tibble: 6 × 3
#>   chart line     value
#>   <chr> <chr>    <dbl>
#> 1 I     CL    -0.00232
#> 2 I     UCL    2.79   
#> 3 I     LCL   -2.79   
#> 4 MR    CL     1.05   
#> 5 MR    UCL    3.43   
#> 6 MR    LCL    0      
```
