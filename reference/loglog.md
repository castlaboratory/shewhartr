# Log-log transformation

Applies the stabilising transformation \$\$y =
\log\\\bigl(\log\bigl(x/\alpha + 1\bigr) + 1\bigr).\$\$ Useful for very
right-skewed non-negative data, particularly count processes with heavy
tails. The +1 inside each log makes the transformation well-defined at
zero.

## Usage

``` r
loglog(x, alpha = 1)
```

## Arguments

- x:

  Numeric vector. Values must satisfy `x / alpha > -1`.

- alpha:

  Positive scaling parameter. Default: 1.

## Value

A numeric vector of transformed values.

## See also

[`iloglog()`](https://castlaboratory.github.io/shewhartr/reference/iloglog.md)
for the inverse,
[`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
for a data-driven transformation choice.

## Examples

``` r
x <- c(0, 1, 5, 10, 100, 1000)
loglog(x)
#> [1] 0.000000 0.526589 1.026672 1.223156 1.725463 2.067970
```
