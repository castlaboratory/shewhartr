# Phase I and Phase II

``` r

library(shewhartr)
library(dplyr)
```

A control chart serves two purposes that are easy to confuse, and
confusing them is the most common cause of misleading charts in
practice. Woodall (2000) crystallised the distinction:

- **Phase I** is *retrospective*. You have a body of historical data and
  want to *establish* trustworthy control limits. The natural workflow
  is iterative: look for out-of-control points, investigate whether they
  have assignable causes, remove those points if so, and recompute the
  limits. The output of Phase I is a chart whose limits are believable —
  points outside them are genuinely surprising.
- **Phase II** is *prospective*. You take Phase I’s limits as fixed and
  apply them to *new* data, signalling alarms when something departs
  from the established baseline.

Most R packages collapse the two into a single function call, which has
two consequences. First, every “monitoring” run silently re-estimates
the limits, so a real shift that grows over time can update the limits
along with itself and never alarm. Second, the diagnostic table for
Phase II shouldn’t contain “this baseline itself violates the rules”
entries — but it always does in tools that don’t separate the phases.

`shewhartr` keeps the two distinct in code through
[`calibrate()`](https://castlaboratory.github.io/shewhartr/reference/calibrate.md)
and
[`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md).

## A worked example

`bottle_fill` has 100 observations. Imagine the first 60 are our
historical baseline, gathered while the process was thought to be in
control, and the next 40 are new data we want to monitor.

``` r

baseline <- bottle_fill[1:60, ]
new_obs  <- bottle_fill[61:100, ]
```

### Phase I: calibration

``` r

calib <- calibrate(
  baseline,
  value         = ml,
  index         = observation,
  chart         = "i_mr",
  trim_outliers = TRUE
)
calib
#> 
#> ── Shewhart chart I-MR (individuals & moving range) ────────────────────────────
#> • Observations / subgroups: 60
#> • Phase: "phase_1"
#> • Sigma estimate ("mr"): 1.288
#> 
#> 
#> ── Control limits ──
#> # A tibble: 6 × 3
#>   chart line   value
#>   <chr> <chr>  <dbl>
#> 1 I     CL    500.  
#> 2 I     UCL   504.  
#> 3 I     LCL   496.  
#> 4 MR    CL      1.45
#> 5 MR    UCL     4.75
#> 6 MR    LCL     0
#> ── Rule violations ──
#> 
#> ✔ No violations across 2 rules: "nelson_1_beyond_3s" and "nelson_2_nine_same".
```

`trim_outliers = TRUE` enables iterative trimming: any observation that
violates the rules is removed and the limits are recomputed. The
procedure is described in Montgomery (2019), Section 6.2.3.

``` r

calib$phase
#> [1] "phase_1"
calib$n          # potentially less than nrow(baseline) if trimming dropped points
#> [1] 60
broom::tidy(calib)
#> # A tibble: 6 × 3
#>   chart line   value
#>   <chr> <chr>  <dbl>
#> 1 I     CL    500.  
#> 2 I     UCL   504.  
#> 3 I     LCL   496.  
#> 4 MR    CL      1.45
#> 5 MR    UCL     4.75
#> 6 MR    LCL     0
```

### Phase II: monitoring

``` r

alarms <- monitor(new_obs, calib)
alarms$phase
#> [1] "phase_2"
alarms$violations
#> # A tibble: 0 × 5
#> # ℹ 5 variables: position <int>, rule <chr>, description <chr>, value <dbl>,
#> #   severity <chr>
```

[`monitor()`](https://castlaboratory.github.io/shewhartr/reference/monitor.md)
does *not* re-estimate the limits. It propagates the calibrated limits
to the new data, applies the same rule set, and returns a fresh chart
object whose `phase` slot is `"phase_2"`.

You can plot the monitored series exactly the same way:

``` r

autoplot(alarms)
```

## Why the trim step matters

Suppose your baseline contains a single contaminated observation — say,
the time the operator forgot to recalibrate the scale. If you include
it, the moving range will be inflated, sigma will be overestimated, and
*future* alarms will be too lenient. The trim step iteratively removes
such contamination from the calibration data.

You can disable trimming if you don’t trust automatic outlier removal:

``` r

calib_no_trim <- calibrate(baseline, value = ml,
                           chart = "i_mr",
                           trim_outliers = FALSE)
calib_no_trim$sigma_hat
#> [1] 1.288322
calib$sigma_hat       # potentially smaller after trimming
#> [1] 1.288322
```

The general principle (Tukey 1977): an analyst should look at the data
before trusting any automated calibration. Use
[`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md)
and the runs-violation table to interrogate your baseline before
declaring it “in control”.

## When this matters most

The Phase I / Phase II distinction is most consequential when:

- The process has evolved (operators, materials, environment) since the
  historical baseline was collected. Limits estimated on the old data
  may misfit new operating conditions.
- A small sustained shift is present. Re-estimating limits each
  monitoring run masks slow drifts.
- You will compare different time periods. Without fixed limits, a
  comparison is between two estimates rather than against a single
  reference.

## References

- Woodall, W. H. (2000). Controversies and Contradictions in Statistical
  Process Control. *Journal of Quality Technology*, 32(4), 341-350.
- Montgomery, D. C. (2019). *Introduction to Statistical Quality
  Control* (8th ed.). Wiley. Section 6.2.3.
- Champ, C. W., & Woodall, W. H. (1987). Exact Results for Shewhart
  Control Charts with Supplementary Runs Rules. *Technometrics*, 29(4),
  393-399.
- Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.
