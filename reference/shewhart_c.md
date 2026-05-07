# c chart for the number of nonconformities

Constructs a c chart for counts of nonconformities (defects) per
inspection unit, where the unit (area, length, time, etc.) is constant
across observations. For variable inspection size use
[`shewhart_u()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_u.md).

## Usage

``` r
shewhart_c(
  data,
  defects,
  index = NULL,
  limits = c("3sigma", "poisson"),
  rules = c("nelson_1_beyond_3s"),
  locale = getOption("shewhart.locale", "en"),
  verbose = NULL
)
```

## Arguments

- data:

  A data frame.

- defects:

  Tidy-eval column reference for the count of nonconformities per
  inspection unit.

- index:

  Optional tidy-eval column reference for the x-axis.

- limits:

  One of `"3sigma"` (default; classical normal approximation) or
  `"poisson"` (exact Poisson 0.00135 / 0.99865 quantiles, recommended
  when `c_bar < 10`).

- rules:

  Character vector of rule keys to apply. See
  [`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md).
  Default applies Nelson 1 and 2.

- locale:

  One of `"en"`, `"pt"`, `"es"`, `"fr"`. Affects plot labels and
  informative messages.

- verbose:

  Logical. Print progress messages? Defaults to the `shewhart.verbose`
  option.

## Value

A
[shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
object of subclass `shewhart_c`.

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 7.3.

Ryan, T. P. (2011). *Statistical Methods for Quality Improvement* (3rd
ed.). Wiley. Chapter 6 (on the inadequacy of 3-sigma limits for low-mean
Poisson counts).

## Examples

``` r
set.seed(1)
df <- data.frame(
  unit    = 1:40,
  defects = rpois(40, lambda = 6)
)
fit <- shewhart_c(df, defects = defects, index = unit)
#> Warning: c_bar = 6.08 is small; the normal approximation is poor.
#> ℹ Consider `limits = "poisson"` for exact limits.
fit_exact <- shewhart_c(df, defects = defects, index = unit,
                        limits = "poisson")
```
