# p chart for the proportion of nonconforming items

Constructs a p chart from counts of nonconforming items in subgroups of
size `n`. Subgroup sizes may vary; in that case, control limits are
computed per observation.

## Usage

``` r
shewhart_p(
  data,
  defects,
  n,
  index = NULL,
  limits = c("3sigma", "binomial"),
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

  Tidy-eval column reference for the subgroup size.

- index:

  Optional tidy-eval column reference for the x-axis.

- limits:

  One of `"3sigma"` (default; classical normal approximation) or
  `"binomial"` (exact 0.00135 / 0.99865 binomial quantiles, equivalent
  to the standard 3-sigma rate when n is large).

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
object of subclass `shewhart_p`.

## Details

Standard 3-sigma limits use the normal approximation to the binomial:
\$\$\bar p \pm 3 \sqrt{\bar p (1 - \bar p) / n_i}.\$\$ For very small
`n_i` or very small / very large `p_bar`, the approximation deteriorates
and exact binomial limits should be preferred (`limits = "binomial"`).

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Chapter 7.

## Examples

``` r
set.seed(1)
df <- data.frame(
  day     = 1:30,
  defects = rbinom(30, size = 100, prob = 0.05),
  n       = 100
)
fit <- shewhart_p(df, defects = defects, n = n, index = day)
print(fit)
#> 
#> ── Shewhart chart p (proportion of nonconforming) ──────────────────────────────
#> • Observations / subgroups: 30
#> • Phase: "phase_1"
#> • Sigma estimate ("3sigma"): NA
#> 
#> ── Control limits ──
#> 
#> # A tibble: 3 × 4
#>   chart line   value note 
#>   <chr> <chr>  <dbl> <chr>
#> 1 p     CL    0.0517 ""   
#> 2 p     UCL   0.118  ""   
#> 3 p     LCL   0      ""   
#> ── Rule violations ──
#> 
#> ✔ No violations across 1 rule: "nelson_1_beyond_3s".
```
