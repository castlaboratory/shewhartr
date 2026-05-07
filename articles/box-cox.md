# Choosing a transformation: Box-Cox in practice

``` r

library(shewhartr)
library(ggplot2)
```

Box & Cox (1964) introduced a one-parameter family of power
transformations,

``` math
y(\lambda) =
\begin{cases}
(x^\lambda - 1)/\lambda & \lambda \neq 0 \\
\log(x) & \lambda = 0,
\end{cases}
```

and a procedure for choosing $`\lambda`$ by maximum likelihood. The goal
is to find a scale on which the residuals are approximately normal and
homoscedastic — the assumptions that classical inferential tools,
including Shewhart charts, presuppose.

[`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
returns the profile log-likelihood, the maximiser $`\hat \lambda`$, and
a 95% confidence interval based on the chi-square approximation to twice
the log-likelihood drop.

## A textbook example

``` r

set.seed(2025)
y <- rlnorm(200, meanlog = 0, sdlog = 0.5)   # log-normal -> lambda = 0
bc <- shewhart_box_cox(y)
bc
#> 
#> ── Box-Cox profile likelihood ──────────────────────────────────────────────────
#> • n = 200
#> • lambda_hat = 0
#> • 95% CI: [-0.25, 0.2]
```

The optimal lambda is near zero (log transformation), and the 95% CI
should cover zero. Let’s plot the profile:

``` r

autoplot(bc)
```

If the CI for $`\lambda`$ contains 1, no transformation is needed (the
data are approximately normal as is). If it contains 0, take logs. If it
contains 0.5, take square roots — and so on.

## Interaction with `shewhart_regression(model = "auto")`

The `"auto"` model in
[`shewhart_regression()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_regression.md)
calls
[`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
internally on the response (with a +1 shift to keep zeros valid) and
selects among `linear`, `log`, `loglog` according to the value of
$`\hat \lambda`$:

- $`|\hat \lambda - 1| \le 0.1`$ → `linear`
- $`|\hat \lambda - 0| \le 0.1`$ → `log`
- $`|\hat \lambda - 0.5| \le 0.1`$ → `loglog`
- otherwise default to `linear` with a warning

This is a guidance step, not a guarantee. Always inspect the residual
diagnostics afterwards via
[`shewhart_diagnostics()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_diagnostics.md).

## When *not* to transform

If your data are counts, proportions, times-to-event, or other
quantities with a known parametric family, model that family explicitly.
Box was clear about this: if you can model the right distribution, do
so. Transforms exist for the case where the right distribution isn’t
tractable and a normal approximation on a suitably-chosen scale is the
best available compromise.

The c, u, p, and np charts in this package implement that advice: they
support `limits = "poisson"` (or `"binomial"`) for exact
distribution-aware limits, instead of relying on a transformation to
coerce counts into approximate normality.

## References

- Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
  *Journal of the Royal Statistical Society B*, 26(2), 211-252.
- Atkinson, A. C. (1985). *Plots, Transformations and Regression*.
  Oxford.
- Box, G. E. P., Hunter, W. G., & Hunter, J. S. (2005). *Statistics for
  Experimenters* (2nd ed.). Wiley.
- Sakia, R. M. (1992). The Box-Cox Transformation Technique: A Review.
  *The Statistician*, 41(2), 169-178.
