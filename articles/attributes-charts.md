# Attributes charts: p, np, c, u

``` r

library(shewhartr)
```

When the quality characteristic is binary (defective / non-defective) or
a count of defects per unit, classical variables charts are the wrong
tool. Counts and proportions live on bounded supports and follow
Binomial / Poisson distributions; pretending they are normal makes the
chart limits wrong, sometimes badly.

| Data | Distribution | Chart |
|----|----|----|
| Proportion defective (variable n) | Binomial | [`shewhart_p()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_p.md) |
| Number defective (constant n) | Binomial | [`shewhart_np()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_np.md) |
| Defect count per unit (constant exposure) | Poisson | [`shewhart_c()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_c.md) |
| Defect count per unit (variable exposure) | Poisson | [`shewhart_u()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_u.md) |

## p chart with variable n

`claims_p` records 30 days of insurance-claim quality control. Each day,
a variable number of claims (`n`) is processed and a count of errors
(`defects`) is observed.

``` r

fit <- shewhart_p(claims_p, defects = defects, n = n, index = day)
broom::tidy(fit)
#> # A tibble: 3 × 4
#>   chart line    value note           
#>   <chr> <chr>   <dbl> <chr>          
#> 1 p     CL     0.0601 ""             
#> 2 p     UCL   NA      "varies with n"
#> 3 p     LCL   NA      "varies with n"
```

Because `n` varies day-to-day, the limits also vary day-to-day:

``` r

broom::augment(fit) |> head(10)
#> # A tibble: 10 × 11
#>      day  .obs .defects    .n .value .center .sigma .upper .lower
#>    <int> <int>    <int> <int>  <dbl>   <dbl>  <dbl>  <dbl>  <dbl>
#>  1     1     1        7   134 0.0522  0.0601 0.0205  0.122      0
#>  2     2     2        8   140 0.0571  0.0601 0.0201  0.120      0
#>  3     3     3        6   129 0.0465  0.0601 0.0209  0.123      0
#>  4     4     4        3   100 0.03    0.0601 0.0238  0.131      0
#>  5     5     5        6   105 0.0571  0.0601 0.0232  0.130      0
#>  6     6     6        6   109 0.0550  0.0601 0.0228  0.128      0
#>  7     7     7        4    82 0.0488  0.0601 0.0262  0.139      0
#>  8     8     8        3   138 0.0217  0.0601 0.0202  0.121      0
#>  9     9     9        6    90 0.0667  0.0601 0.0251  0.135      0
#> 10    10    10        6   125 0.048   0.0601 0.0213  0.124      0
#> # ℹ 2 more variables: .flag_nelson_1_beyond_3s <lgl>, .flag_any <lgl>
```

The default `limits = "3sigma"` uses the normal approximation
$`\bar p \pm 3\sqrt{\bar p (1 - \bar p)/n_i}`$. This is fine when
$`n_i \bar p \gtrsim 5`$ and $`n_i (1-\bar p) \gtrsim 5`$. For small
$`n`$ or extreme $`\bar p`$, switch to exact binomial limits:

``` r

shewhart_p(claims_p, defects = defects, n = n, index = day,
           limits = "binomial")
```

## c chart and Poisson honesty

`pcb_solder` has 50 PCBs and a mean defect count of about 6. The default
3-sigma c-chart works fine here:

``` r

fit_c <- shewhart_c(pcb_solder, defects = defects, index = board)
#> Warning: c_bar = 5.76 is small; the normal approximation is poor.
#> ℹ Consider `limits = "poisson"` for exact limits.
broom::tidy(fit_c)
#> # A tibble: 3 × 3
#>   chart line  value
#>   <chr> <chr> <dbl>
#> 1 c     CL     5.76
#> 2 c     UCL   13.0 
#> 3 c     LCL    0
```

But if `c_bar` were small (say 2 or 3), the lower limit under the normal
approximation would be negative — which makes no sense for a count. The
package warns when this is likely:

``` r

small_means <- data.frame(unit = 1:50, defects = rpois(50, lambda = 2))
suppressWarnings(
  fit_low <- shewhart_c(small_means, defects = defects, index = unit)
)
broom::tidy(fit_low)
#> # A tibble: 3 × 3
#>   chart line  value
#>   <chr> <chr> <dbl>
#> 1 c     CL     2.02
#> 2 c     UCL    6.28
#> 3 c     LCL    0
```

For low-mean Poisson processes, use exact quantile limits:

``` r

fit_low_exact <- shewhart_c(small_means, defects = defects, index = unit,
                            limits = "poisson")
broom::tidy(fit_low_exact)
#> # A tibble: 3 × 3
#>   chart line  value
#>   <chr> <chr> <dbl>
#> 1 c     CL     2.02
#> 2 c     UCL    7   
#> 3 c     LCL    0
```

George Box’s advice — *don’t transform if you can model the right
distribution* — applies. The exact Poisson limits use $`q(0.99865)`$ and
$`q(0.00135)`$ of $`\mathrm{Poisson}(\bar c)`$, the same coverage
probability as classical 3-sigma limits but without the normal
approximation.

## np chart for constant n

When subgroup size is constant, the np chart plots the *count* rather
than the proportion. Useful for direct interpretation when n is a round
number:

``` r

fit_np <- shewhart_np(
  data.frame(day = 1:30, defects = rbinom(30, size = 200, prob = 0.04)),
  defects = defects,
  n       = 200,
  index   = day
)
broom::tidy(fit_np)
#> # A tibble: 3 × 3
#>   chart line  value
#>   <chr> <chr> <dbl>
#> 1 np    CL      7.4
#> 2 np    UCL    15.4
#> 3 np    LCL     0
```

## u chart for variable exposure

When the inspection size differs (e.g. fabric rolls of different length,
machine-hours of different duration), the right chart is u — defects per
unit of exposure:

``` r

set.seed(1)
df_u <- data.frame(
  roll    = 1:25,
  defects = rpois(25, lambda = 4 * runif(25, 0.5, 1.5)),
  m2      = runif(25, 0.5, 1.5)
)
fit_u <- shewhart_u(df_u, defects = defects, exposure = m2, index = roll)
broom::tidy(fit_u)
#> # A tibble: 3 × 4
#>   chart line  value note                  
#>   <chr> <chr> <dbl> <chr>                 
#> 1 u     CL     4.33 ""                    
#> 2 u     UCL   NA    "varies with exposure"
#> 3 u     LCL    0    ""
```

## References

- Montgomery, D. C. (2019). *Introduction to Statistical Quality
  Control* (8th ed.). Wiley. Chapter 7.
- Ryan, T. P. (2011). *Statistical Methods for Quality Improvement* (3rd
  ed.). Wiley. (On the inadequacy of 3-sigma limits for low-mean Poisson
  counts.)
- Box, G. E. P., Hunter, W. G., & Hunter, J. S. (2005). *Statistics for
  Experimenters* (2nd ed.). Wiley.
