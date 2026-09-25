# Estimate Average Run Length via Monte Carlo simulation

Simulates the run length of a Shewhart-type chart configuration under a
sequence of mean shifts. For each shift size, replicates draw normal
observations with mean `shift * sigma` (relative to the in-control
centre) and stop at the first observation where any of the supplied
rules fires. Returns a tibble with the average run length and a Monte
Carlo confidence interval.

## Usage

``` r
shewhart_arl(
  shift = seq(0, 3, by = 0.5),
  rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
  n_sim = 5000L,
  max_run = 1000L,
  sigma = 1,
  seed = NULL
)
```

## Arguments

- shift:

  Numeric vector of mean shifts to evaluate, in units of `sigma`.
  Default: `seq(0, 3, by = 0.5)`.

- rules:

  Character vector of rule keys (see
  [`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md)).

- n_sim:

  Integer. Number of simulation replicates per shift. Default: 5000.

- max_run:

  Integer. Maximum run length before truncation (a censored alarm).
  Default: 1000.

- sigma:

  Numeric. In-control sigma. Default: 1 (the relevant quantity is
  `shift / sigma`, so 1 is fine).

- seed:

  Optional integer seed for reproducibility.

## Value

A tibble with columns `shift`, `arl`, `arl_se`, `arl_lower`,
`arl_upper`, `n_truncated`. `n_truncated` counts how many replicates hit
`max_run` before alarming (a sign that `max_run` should be raised).

## Details

Computational note: for `n_sim = 1e4` and a moderate set of rules, a
single configuration takes a fraction of a second; a fine shift grid
(10-15 points) takes a few seconds. For tighter intervals or larger rule
sets, increase `n_sim` and/or set `parallel = TRUE` (currently a
placeholder for future implementation).

## References

Champ, C. W., & Woodall, W. H. (1987). Exact Results for Shewhart
Control Charts with Supplementary Runs Rules. *Technometrics*, 29(4),
393-399.
[doi:10.1080/00401706.1987.10488262](https://doi.org/10.1080/00401706.1987.10488262)

Wald, A. (1947). *Sequential Analysis*. Wiley.

## Examples

``` r
# \donttest{
# In-control ARL of Nelson 1 (closed-form ARL_0 ~= 370.4)
set.seed(1)
shewhart_arl(shift = 0, rules = "nelson_1_beyond_3s",
             n_sim = 2000, max_run = 2000)
#> # A tibble: 1 × 6
#>   shift   arl arl_se arl_lower arl_upper n_truncated
#>   <dbl> <dbl>  <dbl>     <dbl>     <dbl>       <int>
#> 1     0  385.   8.19      369.      401.          11

# Adding Nelson 2 sharpens detection but lowers ARL_0
shewhart_arl(shift = c(0, 0.5, 1, 1.5, 2),
             rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
             n_sim = 2000)
#> Simulating ARL ■■■■■■■                           20% | ETA:  6m
#> Simulating ARL ■■■■■■■■■■■■■                     40% | ETA:  2m
#> Simulating ARL ■■■■■■■■■■■■■■■■■■■               60% | ETA:  1m
#> Simulating ARL ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | ETA:  0s
#> # A tibble: 5 × 6
#>   shift    arl arl_se arl_lower arl_upper n_truncated
#>   <dbl>  <dbl>  <dbl>     <dbl>     <dbl>       <int>
#> 1   0   207.   4.37      199.      216.            18
#> 2   0.5  55.6  1.21       53.2      58.0            0
#> 3   1    17.0  0.301      16.4      17.6            0
#> 4   1.5   8.54 0.123       8.30      8.78           0
#> 5   2     5.15 0.0751      5.00      5.30           0
# }
```
