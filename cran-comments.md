# shewhartr 1.3.0 — first CRAN submission

## Test environments

* local: macOS 26.6, R 4.6.0
* CI (GitHub Actions, R-CMD-check.yaml):
  - macOS-latest, R release
  - windows-latest, R release
  - ubuntu-latest, R devel
  - ubuntu-latest, R release
  - ubuntu-latest, R oldrel-1

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission. The package was previously distributed informally
  under the name `Shewhart` (v0.1.x) for monitoring of COVID-19 in Recife.
  The 1.x series is a comprehensive rewrite that broadens the scope to general
  Statistical Process Control and renames the package to lowercase per modern
  convention. Versions 1.0.0 to 1.2.0 were released on GitHub only; no prior
  version exists on CRAN under either name.

## Note about URLs in README

The README links to a forthcoming pkgdown documentation site at
<https://castlaboratory.github.io/shewhartr/>. The site is built and deployed
automatically by GitHub Actions on each push to `main`. At the time of
submission these links may show as 404 in `R CMD check`; they resolve as soon
as the gh-pages branch is published.

## Reverse dependencies

This is a new package; no reverse dependencies exist.

## Package philosophy

The package complements `qcc` (classical, S3, no tidyverse) and `qicharts2`
(healthcare-focused, fixed plots) with five differentiators:

1. tidyverse-native API (data first, tidy-eval column references, `.by`)
2. broom integration (`tidy()`, `glance()`, `augment()` for every chart)
3. regression-based control charts as a first-class citizen
4. embedded methodology: ARL by Monte Carlo, all 8 Nelson runs rules,
   Box-Cox guidance, Tukey-style residual diagnostics
5. explicit Phase I (`calibrate()`) / Phase II (`monitor()`) workflow,
   following Woodall (2000)

Multilingual plots (`locale = "en" | "pt" | "es" | "fr"`), exact Poisson /
binomial quantile limits for c/u/p charts (`limits = "poisson"` /
`"binomial"`), memory-based charts (EWMA, CUSUM) and multivariate charts
(Hotelling T^2, MEWMA, MCUSUM) are also supported.
