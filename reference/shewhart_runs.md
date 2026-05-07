# Apply runs tests to a chart object or to raw vectors

Implements the eight rules of Nelson (1984, 1985) plus a Western
Electric "7 in a row" variant for backward compatibility. Returns a tidy
tibble of rule violations.

## Usage

``` r
shewhart_runs(
  x,
  rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
  center = NULL,
  sigma = NULL
)
```

## Arguments

- x:

  Either a `shewhart_chart` object (most common) or a numeric vector of
  values. If a vector is supplied, `center` and `sigma` must also be
  provided.

- rules:

  Character vector of rule keys to apply. Use
  [`shewhart_rules_available()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_rules_available.md)
  to see all options. Default applies Nelson 1 (beyond 3 sigma) and
  Nelson 2 (9 same side), the most commonly recommended pair.

- center, sigma:

  Numeric scalars or vectors. Required only when `x` is a numeric
  vector. Ignored otherwise.

## Value

A tibble with columns `position` (integer, the index where the rule
fired), `rule` (character key), `description` (character label), `value`
(the value at that position) and `severity` (currently always
`"out_of_control"`; reserved for future warning-level rules).

## References

Nelson, L. S. (1984). The Shewhart Control Chart – Tests for Special
Causes. *Journal of Quality Technology*, 16(4), 237-239.
[doi:10.1080/00224065.1984.11978921](https://doi.org/10.1080/00224065.1984.11978921)

Nelson, L. S. (1985). Interpreting Shewhart Xbar Control Charts.
*Journal of Quality Technology*, 17(2), 114-117.
[doi:10.1080/00224065.1985.11978941](https://doi.org/10.1080/00224065.1985.11978941)

Western Electric Co. (1956). *Statistical Quality Control Handbook*.

## Examples

``` r
set.seed(1)
x <- c(rnorm(20), 5, rnorm(20))    # one outlier at position 21
shewhart_runs(x, center = 0, sigma = 1)
#> # A tibble: 1 × 5
#>   position rule               description            value severity      
#>      <int> <chr>              <chr>                  <dbl> <chr>         
#> 1       21 nelson_1_beyond_3s 1 point beyond 3 sigma     5 out_of_control
```
