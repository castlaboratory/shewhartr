# Solder defects on printed circuit boards

A synthetic Poisson dataset: number of defective solder joints on each
of 50 inspected printed circuit boards. The mean is 6, ideal for either
the 3-sigma c chart or its more honest cousin with exact Poisson limits.

## Usage

``` r
pcb_solder
```

## Format

A tibble with 50 rows and 2 columns:

- board:

  Integer board identifier.

- defects:

  Integer count of defective joints.

## Source

Synthetic. See `data-raw/build_all.R`.

## See also

[`shewhart_c()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_c.md).

## Examples

``` r
fit       <- shewhart_c(pcb_solder, defects = defects, index = board)
#> Warning: c_bar = 5.76 is small; the normal approximation is poor.
#> ℹ Consider `limits = "poisson"` for exact limits.
fit_exact <- shewhart_c(pcb_solder, defects = defects, index = board,
                        limits = "poisson")
```
