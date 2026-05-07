# Inverse log-log transformation

Inverts
[`loglog()`](https://castlaboratory.github.io/shewhartr/reference/loglog.md):
\$\$x = \alpha \\\[\exp(\exp(y) - 1) - 1\].\$\$

## Usage

``` r
iloglog(x, alpha = 1)
```

## Arguments

- x:

  Numeric vector previously transformed via
  [`loglog()`](https://castlaboratory.github.io/shewhartr/reference/loglog.md).

- alpha:

  Same `alpha` used in
  [`loglog()`](https://castlaboratory.github.io/shewhartr/reference/loglog.md).
  Default: 1.

## Value

A numeric vector on the original scale.

## Examples

``` r
original <- c(0, 1, 5, 10, 100, 1000)
all.equal(original, iloglog(loglog(original)))
#> [1] TRUE
```
