# Variables charts: I-MR, Xbar-R, Xbar-S

``` r

library(shewhartr)
library(dplyr)
library(ggplot2)
```

This vignette covers the three classical Shewhart charts for continuous
measurements (variables): I-MR for individual observations, Xbar-R for
small rational subgroups, and Xbar-S for larger or unequal-sized
subgroups. The choice between them depends entirely on the structure of
your data.

## When to use which

| Situation | Chart |
|----|----|
| Single measurements, no rational subgroup | [`shewhart_i_mr()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_i_mr.md) |
| Subgroups of size 2-10, equal sizes | [`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md) |
| Subgroups of size \> 10, or unequal sizes | [`shewhart_xbar_s()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_s.md) |

The reason for the cutoff at 10 is that for small subgroup sizes the
range estimator of sigma is more efficient (in the Fisher-information
sense) than the standard deviation estimator; from about $`n = 10`$
onwards the standard deviation overtakes (Montgomery 2019, Section
6.4.1).

## I-MR

`bottle_fill` is a 100-point series of fill volumes. The default
estimator of sigma is the moving range:

``` math
\hat{\sigma} = \frac{\overline{\mathrm{MR}}}{d_2(2)} = \frac{\overline{\mathrm{MR}}}{1.128}.
```

``` r

fit <- shewhart_i_mr(bottle_fill, value = ml, index = observation)
broom::glance(fit)
#> # A tibble: 1 × 8
#>   type      n phase   sigma_hat sigma_method n_violations n_rules pct_violations
#>   <chr> <int> <chr>       <dbl> <chr>               <int>   <int>          <dbl>
#> 1 i_mr    100 phase_1      1.18 mr                      0       2              0
```

``` r

autoplot(fit)
```

### Robust alternatives

The mean of the moving range is sensitive to outliers. Three robust
alternatives are built in:

``` r

fit_med <- shewhart_i_mr(bottle_fill, value = ml,
                         sigma_method = "median_mr")
fit_bw  <- shewhart_i_mr(bottle_fill, value = ml,
                         sigma_method = "biweight")
fit_sd  <- shewhart_i_mr(bottle_fill, value = ml,
                         sigma_method = "sd")

dplyr::bind_rows(
  broom::glance(fit)     |> mutate(method = "mr (default)"),
  broom::glance(fit_med) |> mutate(method = "median_mr"),
  broom::glance(fit_bw)  |> mutate(method = "biweight"),
  broom::glance(fit_sd)  |> mutate(method = "sd")
) |>
  select(method, sigma_hat, n_violations)
#> # A tibble: 4 × 3
#>   method       sigma_hat n_violations
#>   <chr>            <dbl>        <int>
#> 1 mr (default)      1.18            0
#> 2 median_mr         1.18            0
#> 3 biweight          1.23            0
#> 4 sd                1.22            0
```

The biweight is Tukey’s M-estimator with a redescending influence
function (Tukey 1977; Mosteller & Tukey 1977). Use it when you suspect a
small fraction of contaminated observations and don’t want them to
inflate sigma.

## Xbar-R

`tablet_weight` records 25 batches of 5 tablets each.

``` r

fit_xbar <- shewhart_xbar_r(tablet_weight,
                            value    = weight,
                            subgroup = subgroup)
broom::tidy(fit_xbar)
#> # A tibble: 6 × 3
#>   chart line   value
#>   <chr> <chr>  <dbl>
#> 1 Xbar  CL    250.  
#> 2 Xbar  UCL   253.  
#> 3 Xbar  LCL   248.  
#> 4 R     CL      3.53
#> 5 R     UCL     7.46
#> 6 R     LCL     0
```

The Xbar limits use the constant $`A_2(5) = 0.577`$; the R limits use
$`D_3(5) = 0`$ and $`D_4(5) = 2.114`$. These constants come from
Montgomery (2019), Appendix VI, and are exposed via
[`shewhart_constants()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_constants.md):

``` r

shewhart_constants(c(2, 5, 10, 25))
#>    n    A2    A3     c4    d2    d3    B3    B4    B5    B6    D3    D4
#> 1  2 1.880 2.659 0.7979 1.128 0.853 0.000 3.267 0.000 2.606 0.000 3.267
#> 2  5 0.577 1.427 0.9400 2.326 0.864 0.000 2.089 0.000 1.964 0.000 2.114
#> 3 10 0.308 0.975 0.9727 3.078 0.797 0.284 1.716 0.276 1.669 0.223 1.777
#> 4 25 0.153 0.606 0.9896 3.931 0.708 0.565 1.435 0.559 1.420 0.459 1.541
```

[`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md)
insists on equal subgroup sizes (otherwise the constants don’t apply
uniformly). For unequal sizes use
[`shewhart_xbar_s()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_s.md)
with `sigma_method = "pooled_sd"`.

## Xbar-S

The S chart uses the bias-corrected sample standard deviation. Sigma is
estimated as

``` math
\hat{\sigma} = \frac{\bar{S}}{c_4(n)}, \qquad c_4(n) = \sqrt{\frac{2}{n-1}} \cdot \frac{\Gamma(n/2)}{\Gamma((n-1)/2)}.
```

``` r

# Same data, but using S instead of R (preferred for n > 10)
n_per <- 5
df <- tablet_weight |>
  group_by(subgroup) |>
  filter(n() == n_per) |>     # in case of any incomplete batches
  ungroup()

fit_xbs <- shewhart_xbar_s(df, value = weight, subgroup = subgroup)
broom::glance(fit_xbs)
#> # A tibble: 1 × 8
#>   type       n phase  sigma_hat sigma_method n_violations n_rules pct_violations
#>   <chr>  <int> <chr>      <dbl> <chr>               <int>   <int>          <dbl>
#> 1 xbar_s    25 phase…      1.49 sbar                    2       2           0.08
```

For variable subgroup sizes:

``` r

fit_xbs_pooled <- shewhart_xbar_s(df, value = weight, subgroup = subgroup,
                                  sigma_method = "pooled_sd")
```

## Reading the results

Every variables chart returns a `shewhart_chart` object with the
following per-observation columns
([`broom::augment()`](https://generics.r-lib.org/reference/augment.html)):

- `.value` — the plotted statistic (individual, Xbar, etc.)
- `.center`, `.sigma`, `.upper`, `.lower` — control-line series
- For two-panel charts, additional `.mr*`, `.r*`, `.s*` columns for the
  lower panel
- `.flag_<rule>` and `.flag_any` — TRUE/FALSE for each runs rule
  configured

The `rules` argument controls which rules are flagged. By default,
Nelson 1 (point beyond 3 sigma) and Nelson 2 (9 points same side) are
checked, and we recommend keeping at least these two. Add more with:

``` r

fit_full <- shewhart_i_mr(bottle_fill, value = ml,
                          rules = c("nelson_1_beyond_3s",
                                    "nelson_2_nine_same",
                                    "nelson_3_six_trend",
                                    "nelson_5_two_of_three",
                                    "nelson_6_four_of_five"))
fit_full$violations
#> # A tibble: 0 × 5
#> # ℹ 5 variables: position <int>, rule <chr>, description <chr>, value <dbl>,
#> #   severity <chr>
```

Each additional rule increases the chart’s sensitivity at the cost of
shorter in-control ARL. See
[`vignette("arl-simulation")`](https://castlaboratory.github.io/shewhartr/articles/arl-simulation.md)
for how to quantify this trade-off.

## References

- Montgomery, D. C. (2019). *Introduction to Statistical Quality
  Control* (8th ed.). Wiley. Chapter 6.
- Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.
- Mosteller, F., & Tukey, J. W. (1977). *Data Analysis and Regression*.
  Addison-Wesley.
- Wheeler, D. J., & Chambers, D. S. (1992). *Understanding Statistical
  Process Control* (2nd ed.). SPC Press.
- Cryer, J. D., & Ryan, T. P. (1990). The Estimation of Sigma for an X
  Chart: $`\bar{MR}/d_2`$ or $`S/c_4`$? *Journal of Quality Technology*,
  22(3), 187-192.
