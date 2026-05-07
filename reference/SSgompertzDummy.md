# Self-starting Gompertz with an additive dummy term

Extends the classical Gompertz form by adding a linear contribution from
a dummy covariate: \$\$y = \mathrm{Asym}\\\exp(-b_2\\\exp(-b_3 x)) +
\beta\\d.\$\$ Designed for use inside
[`stats::nls()`](https://rdrr.io/r/stats/nls.html): starting values for
the four parameters are computed automatically from the data, and the
analytic gradient is supplied for faster, more reliable convergence.

## Usage

``` r
SSgompertzDummy(x, dummy, Asym, b2, b3, Beta)
```

## Arguments

- x:

  Numeric vector. Independent variable.

- dummy:

  Numeric (typically 0/1) vector of the same length as `x`.

- Asym:

  Upper asymptote.

- b2:

  Curvature parameter.

- b3:

  Rate parameter.

- Beta:

  Dummy effect size.

## Value

A numeric vector of fitted values, with attributes for self-starting and
an analytic gradient.

## References

Same as
[`Gompertz()`](https://castlaboratory.github.io/shewhartr/reference/Gompertz.md).

## See also

[`stats::SSgompertz()`](https://rdrr.io/r/stats/SSgompertz.html) for the
standard self-starting Gompertz without a dummy term,
[`fit_gompertz_dummy()`](https://castlaboratory.github.io/shewhartr/reference/fit_gompertz_dummy.md)
for a convenience wrapper.

## Examples

``` r
# \donttest{
set.seed(42)
n <- 50
x <- seq(1, 10, length.out = n)
d <- rep(c(0, 1), each = n / 2)
y <- 100 * exp(-2 * exp(-0.3 * x)) + 20 * d + rnorm(n, 0, 3)
df <- data.frame(x = x, y = y, dummy = d)

fit <- nls(y ~ SSgompertzDummy(x, dummy, Asym, b2, b3, Beta), data = df)
summary(fit)
#> 
#> Formula: y ~ SSgompertzDummy(x, dummy, Asym, b2, b3, Beta)
#> 
#> Parameters:
#>       Estimate Std. Error t value Pr(>|t|)    
#> Asym 103.94202    5.56568   18.68  < 2e-16 ***
#> b2     1.86485    0.09362   19.92  < 2e-16 ***
#> b3     0.26619    0.02420   11.00 1.81e-14 ***
#> Beta  19.33285    2.08111    9.29 4.02e-12 ***
#> ---
#> Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#> 
#> Residual standard error: 3.419 on 46 degrees of freedom
#> 
#> Number of iterations to convergence: 6 
#> Achieved convergence tolerance: 1.35e-07
#> 
# }
```
