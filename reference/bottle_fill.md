# Bottle filling volumes

A synthetic dataset of 100 individual fill volumes (in millilitres).
Process target is 500 ml with sigma 1.2 ml. A linear drift begins around
observation 65, simulating a slowly miscalibrating filler.

## Usage

``` r
bottle_fill
```

## Format

A tibble with 100 rows and 2 columns:

- observation:

  Integer observation index.

- ml:

  Numeric volume in millilitres.

## Source

Synthetic. See `data-raw/build_all.R`.

## See also

[`shewhart_i_mr()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_i_mr.md).

## Examples

``` r
fit <- shewhart_i_mr(bottle_fill, value = ml, index = observation)
# \donttest{
ggplot2::autoplot(fit)
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`geom_line()`).
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`geom_point()`).

# }
```
