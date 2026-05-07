# Bacterial growth curve (optical density)

A synthetic dataset of optical density (OD) measurements from a
bacterial culture, sampled at 80 evenly spaced time points across a
24-hour incubation. The true mean follows a Gompertz growth curve with
asymptote 1.2.

## Usage

``` r
bacterial_growth
```

## Format

A tibble with 80 rows and 2 columns:

- hour:

  Numeric time in hours since inoculation.

- od:

  Numeric optical density at 600 nm.

## Source

Synthetic. See `data-raw/build_all.R`.

## See also

[`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md)
with `model = "gompertz"`,
[`Gompertz()`](https://castlaboratory.github.io/shewhartr/reference/Gompertz.md).

## Examples

``` r
# \donttest{
fit <- shewhart_regression(bacterial_growth,
                           value = od, index = hour,
                           model = "gompertz")
ggplot2::autoplot(fit)

# }
```
