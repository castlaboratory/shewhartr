# np chart for the number of nonconforming items

Constructs an np chart from counts of nonconforming items in subgroups
of constant size `n`. For variable subgroup sizes, use
[`shewhart_p()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_p.md)
instead.

## Usage

``` r
shewhart_np(
  data,
  defects,
  n,
  index = NULL,
  rules = c("nelson_1_beyond_3s"),
  locale = getOption("shewhart.locale", "en"),
  verbose = NULL
)
```

## Arguments

- data:

  A data frame.

- defects:

  Tidy-eval column reference for the count of nonconforming items in
  each subgroup.

- n:

  Numeric scalar. The (constant) subgroup size.

- index:

  Optional tidy-eval column reference for the x-axis.

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
object of subclass `shewhart_np`.

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 7.2.2.

## Examples

``` r
set.seed(1)
df <- data.frame(
  day     = 1:30,
  defects = rbinom(30, size = 200, prob = 0.04)
)
fit <- shewhart_np(df, defects = defects, n = 200, index = day)
print(fit)
#> 
#> ── Shewhart chart np (number of nonconforming) ─────────────────────────────────
#> • Observations / subgroups: 30
#> • Phase: "phase_1"
#> • Sigma estimate ("binomial"): 2.799
#> 
#> ── Control limits ──
#> 
#> # A tibble: 3 × 3
#>   chart line  value
#>   <chr> <chr> <dbl>
#> 1 np    CL     8.17
#> 2 np    UCL   16.6 
#> 3 np    LCL    0   
#> ── Rule violations ──
#> 
#> ✔ No violations across 1 rule: "nelson_1_beyond_3s".
```
