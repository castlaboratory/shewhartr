# u chart for nonconformities per unit, variable inspection size

Constructs a u chart from defect counts and a per-observation "exposure"
(inspection size: square metres of fabric, hours of operation, lines of
code, etc.). For constant exposure use
[`shewhart_c()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_c.md).

## Usage

``` r
shewhart_u(
  data,
  defects,
  exposure,
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

  Tidy-eval column reference for raw defect counts.

- exposure:

  Tidy-eval column reference for the inspection size (must be positive).

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
object of subclass `shewhart_u`.

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 7.3.2.

## Examples

``` r
set.seed(1)
df <- data.frame(
  roll     = 1:25,
  defects  = rpois(25, lambda = 4 * runif(25, 0.5, 1.5)),
  m2       = runif(25, 0.5, 1.5)    # variable inspection size
)
fit <- shewhart_u(df, defects = defects, exposure = m2, index = roll)
```
