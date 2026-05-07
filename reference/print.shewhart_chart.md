# Print a Shewhart chart object

Concise summary including chart type, sample size, sigma estimate and
any rule violations. For full per-row results, use
[augment()](https://broom.tidymodels.org/reference/reexports.html); for
a tabular limit summary, use
[tidy()](https://broom.tidymodels.org/reference/reexports.html).

## Usage

``` r
# S3 method for class 'shewhart_chart'
print(x, ...)
```

## Arguments

- x:

  A
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object.

- ...:

  Currently unused.

## Value

Returns `x` invisibly (for chaining).

## Examples

``` r
set.seed(1)
fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
print(fit)
#> 
#> ── Shewhart chart I-MR (individuals & moving range) ────────────────────────────
#> • Observations / subgroups: 50
#> • Phase: "phase_1"
#> • Sigma estimate ("mr"): 0.8085
#> 
#> ── Control limits ──
#> 
#> # A tibble: 6 × 3
#>   chart line   value
#>   <chr> <chr>  <dbl>
#> 1 I     CL     0.100
#> 2 I     UCL    2.53 
#> 3 I     LCL   -2.32 
#> 4 MR    CL     0.912
#> 5 MR    UCL    2.98 
#> 6 MR    LCL    0    
#> ── Rule violations ──
#> 
#> ✔ No violations across 2 rules: "nelson_1_beyond_3s" and "nelson_2_nine_same".
```
