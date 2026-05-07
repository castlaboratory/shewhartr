# Convenience wrapper to fit `SSgompertzDummy` to a data frame

Convenience wrapper to fit `SSgompertzDummy` to a data frame

## Usage

``` r
fit_gompertz_dummy(data, x, y, dummy, start = NULL, ...)
```

## Arguments

- data:

  A data frame with the columns referenced by `x`, `y`, `dummy`.

- x, y, dummy:

  Tidy-eval column references.

- start:

  Optional named list of starting values (`Asym`, `b2`, `b3`, `Beta`).
  If `NULL`, the self-starting initialiser is used.

- ...:

  Additional arguments passed to
  [`stats::nls()`](https://rdrr.io/r/stats/nls.html).

## Value

An object of class `nls`.

## Examples

``` r
# \donttest{
set.seed(42)
df <- data.frame(
  x = seq(1, 10, length.out = 50),
  d = rep(c(0, 1), each = 25)
)
df$y <- 100 * exp(-2 * exp(-0.3 * df$x)) + 20 * df$d + rnorm(50, 0, 3)
fit <- fit_gompertz_dummy(df, x = x, y = y, dummy = d)
coef(fit)
#>        Asym          b2          b3        Beta 
#> 103.9420206   1.8648478   0.2661911  19.3328517 
# }
```
