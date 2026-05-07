# Phase I calibration of a control chart

Convenience wrapper that fits a control chart and tags its phase as
`"phase_1"` (the default for any chart constructor). The intent is to
make Phase I usage *explicit* in code: the practitioner acknowledges
that limits are being estimated.

## Usage

``` r
calibrate(data, ..., chart = "i_mr", trim_outliers = FALSE, max_trim_iter = 5L)
```

## Arguments

- data:

  A data frame.

- ...:

  Arguments passed to a chart constructor.

- chart:

  A character key naming the chart constructor: `"i_mr"` (default),
  `"xbar_r"`, `"xbar_s"`, `"p"`, `"np"`, `"c"`, `"u"`, `"regression"`,
  `"ewma"`, `"cusum"`, `"hotelling"`, `"mewma"`.

- trim_outliers:

  Logical. If `TRUE`, iteratively drop observations that violate the
  rules and re-estimate limits (Montgomery 2019, Section 6.2.3).

- max_trim_iter:

  Integer. Maximum trimming iterations.

## Value

A
[shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
object with `$phase = "phase_1"`.

## Details

Optionally drops violations from the in-control estimate ("trimmed"
calibration), per the iterative procedure described in Montgomery (2019)
Section 6.2.3: if any observation falls outside the limits, it is
removed and the limits are recomputed; iterate until either all
remaining points are in control or no further trimming is possible.

## References

Woodall, W. H. (2000). Controversies and Contradictions in Statistical
Process Control. *Journal of Quality Technology*, 32(4), 341-350.
[doi:10.1080/00224065.2000.11980013](https://doi.org/10.1080/00224065.2000.11980013)

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Section 6.2.3.

## Examples

``` r
set.seed(1)
df <- data.frame(y = c(rnorm(40, mean = 100, sd = 2), 110, rnorm(20, 100, 2)))
calib <- calibrate(df, value = y, chart = "i_mr", trim_outliers = TRUE)
#> ℹ Trim iteration 1: dropping 1 observation.
calib$n          # 60 if trim was avoided, fewer if outliers were removed
#> [1] 60
```
