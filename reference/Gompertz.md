# Gompertz growth function

Computes the value of the Gompertz curve parameterised in terms of
starting value, asymptote, growth rate and lag: \$\$G(x) = y_0 +
(y\_{\max} - y_0)\\ \exp\\\left\[-\exp\\\left(\frac{k(\mathrm{lag} -
x)}{y\_{\max} - y_0} + 1\right)\right\].\$\$

## Usage

``` r
Gompertz(x, y0, ymax, k, lag)
```

## Arguments

- x:

  Numeric vector. The independent variable (e.g. time).

- y0:

  Lower asymptote.

- ymax:

  Upper asymptote.

- k:

  Maximum specific growth rate.

- lag:

  Lag time.

## Value

A numeric vector the same length as `x`.

## Details

This parameterisation, often called the "Zwietering Gompertz" form after
Zwietering et al. (1990), gives directly interpretable parameters: `y0`
is the lower asymptote, `ymax` the upper asymptote, `k` the maximum
specific growth rate, and `lag` the lag time before exponential growth.

## References

Gompertz, B. (1825). On the Nature of the Function Expressive of the Law
of Human Mortality. *Philosophical Transactions of the Royal Society of
London*, 115, 513-583.

Zwietering, M. H., Jongenburger, I., Rombouts, F. M., & van 't Riet, K.
(1990). Modeling of the Bacterial Growth Curve. *Applied and
Environmental Microbiology*, 56(6), 1875-1881.
[doi:10.1128/aem.56.6.1875-1881.1990](https://doi.org/10.1128/aem.56.6.1875-1881.1990)

## See also

[`SSgompertzDummy()`](https://castlaboratory.github.io/shewhartr/reference/SSgompertzDummy.md)
for an `nls`-friendly self-starting variant that allows a covariate
shift.

## Examples

``` r
x <- seq(0, 30, by = 0.5)
y <- Gompertz(x, y0 = 0, ymax = 100, k = 5, lag = 5)
plot(x, y, type = "l", main = "Gompertz growth curve")

```
