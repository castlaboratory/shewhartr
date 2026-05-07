# Residual diagnostics, Tukey style

``` r

library(shewhartr)
```

Every Shewhart chart silently makes assumptions about its residuals:
that they are independent (not autocorrelated), approximately normal (or
at least symmetric and unimodal), with constant variance over time. When
the assumptions hold, the chart’s nominal false-alarm rates apply. When
they don’t, the chart can be either too lenient or too strict, and
either way you cannot tell from the chart itself.

[`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md)
produces a five-panel residual diagnostic display. It is a working tool,
not a polished figure: the point is to surface the assumptions, not to
print them.

## What the panels show

``` r

fit <- shewhart_i_mr(bottle_fill, value = ml, index = observation)
shewhart_diagnostics(fit)
```

| Panel                | Reads as                                     |
|----------------------|----------------------------------------------|
| Residuals vs. fitted | Trend or non-constant variance in residuals? |
| Normal Q-Q           | Heavy tails, skew, gross departures from N   |
| ACF                  | Are residuals correlated in time?            |
| Moving range         | Drift in dispersion?                         |
| Histogram            | Symmetry and unimodality                     |

The Q-Q and histogram address normality. The ACF plot and the
moving-range trace address independence and stationarity. The
residuals-vs-fitted plot catches non-linearity and heteroscedasticity.

This panel is what John Tukey called the *exploratory* phase of any
analysis: before you trust an answer, look at the working. Box’s remark
applies — “all models are wrong” — but the residual panel tells you
*how* wrong, and whether the wrongness matters.

## A diagnosis-driven fix: Box-Cox

If the histogram or Q-Q reveals strong skew, the chart’s nominal limits
won’t give the advertised coverage. The classical fix is a Box-Cox
transformation:

``` r

bc <- shewhart_box_cox(bottle_fill, value = ml)
print(bc)
ggplot2::autoplot(bc)
```

The maximum-likelihood lambda and its 95% CI are returned. If 1 falls
inside the CI, no transformation is needed; if 0 does, take logs;
otherwise apply $`y^\lambda`$ to the data and re-fit the chart.

`shewhart_regression(model = "auto")` calls
[`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
internally and picks among `linear`, `log`, `loglog` based on the
profile-likelihood maximiser. For full control, run the diagnostic
yourself and pass `model` (or `formula`) explicitly.

## When non-normality is a feature, not a bug

Counts and proportions are non-normal *by construction*; that is why
attributes charts use Binomial / Poisson limits, not transforms.
Diagnostics on a c-chart’s residuals will show discrete jumps and
non-normal tails by construction; that is fine. The statistical honesty
here is to use the right distribution from the start, not to transform
until residuals look normal.

## References

- Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.
- Box, G. E. P., Hunter, W. G., & Hunter, J. S. (2005). *Statistics for
  Experimenters* (2nd ed.). Wiley.
- Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
  *Journal of the Royal Statistical Society B*, 26(2), 211-252.
- Atkinson, A. C. (1985). *Plots, Transformations and Regression*.
  Oxford.
