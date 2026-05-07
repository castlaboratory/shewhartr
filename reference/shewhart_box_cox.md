# Box-Cox profile log-likelihood

Computes the profile log-likelihood for the Box-Cox power parameter
lambda, applied to a single positive numeric series (regression to a
constant) or to the residuals of a linear model.

## Usage

``` r
shewhart_box_cox(data, value = NULL, lambda_grid = seq(-2, 2, by = 0.05))
```

## Arguments

- data:

  A data frame, or a numeric vector. If a data frame, `value` must be
  supplied.

- value:

  Tidy-eval column reference for the response (only when `data` is a
  data frame).

- lambda_grid:

  Numeric vector of lambda values to evaluate. Default: a fine grid from
  -2 to 2.

## Value

An object of class `shewhart_box_cox` with components `profile` (tibble
of lambda vs. log-likelihood), `lambda_hat` (the maximiser), `ci` (95%
CI). The object has its own
[`print()`](https://rdrr.io/r/base/print.html) method.

## Details

Reports the lambda that maximises the profile likelihood and a 95%
confidence interval based on the chi-square approximation to twice the
log-likelihood drop (Box & Cox 1964, eq. 9).

## References

Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
*Journal of the Royal Statistical Society, Series B*, 26(2), 211-252.
[doi:10.1111/j.2517-6161.1964.tb00553.x](https://doi.org/10.1111/j.2517-6161.1964.tb00553.x)

## Examples

``` r
set.seed(1)
bc <- shewhart_box_cox(rlnorm(200, meanlog = 0, sdlog = 0.5))
bc$lambda_hat   # should be near 0 (log-normal data)
#> [1] -0.15
```
