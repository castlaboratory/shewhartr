# Tidy the control limits of a Shewhart chart

Returns a tibble of the chart's control limits in tall format. Each row
corresponds to one line of one chart panel (CL / UCL / LCL).

## Usage

``` r
# S3 method for class 'shewhart_chart'
tidy(x, ...)
```

## Arguments

- x:

  A
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object.

- ...:

  Currently unused.

## Value

A tibble with at least columns `chart`, `line`, `value`.

## Examples

``` r
fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
broom::tidy(fit)
#> # A tibble: 6 × 3
#>   chart line   value
#>   <chr> <chr>  <dbl>
#> 1 I     CL    -0.255
#> 2 I     UCL    3.26 
#> 3 I     LCL   -3.77 
#> 4 MR    CL     1.32 
#> 5 MR    UCL    4.32 
#> 6 MR    LCL    0    
```
