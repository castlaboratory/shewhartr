# shewhartr 1.4.0

Update of the package on CRAN (1.3.0, published 2026-05-13, OK on all
13 flavors at the time of this submission).

## Test environments

* local: macOS 26.6 (Apple Silicon), R 4.6.0, `R CMD check --as-cran`
* CI (GitHub Actions, R-CMD-check.yaml):
  - macOS-latest, R release
  - windows-latest, R release
  - ubuntu-latest, R devel
  - ubuntu-latest, R release
  - ubuntu-latest, R oldrel-1

## R CMD check results

0 errors | 0 warnings | 1 note

* The note is local only: "Skipping checking HTML validation: 'tidy'
  doesn't look like recent enough HTML Tidy" and "package 'V8'
  unavailable". Both tools are present on the CRAN check machines.

## What changed

This release follows an audit of the 1.3.0 code base. It fixes 34
defects (all listed in NEWS.md with the finding number), the most
user-visible being:

* Phase II `monitor()` on a regression chart continued the model's
  time index from 1 instead of from the end of the last phase.
* `shewhart_capability()` on subgroup charts scaled sigma by sqrt(n)
  and used subgroup means as raw data.
* `autoplot()` failed on a monitored I-MR chart.
* The MEWMA and MCUSUM decision-interval tables held ARL_0 ~ 200 only
  for p = 2; they were re-derived by simulation for p >= 3.
* The EWMA default `L` moved from 2.7 to 2.86 so that the documented
  ARL_0 ~ 370 holds.

New: `limits_scale = "model"` for the regression chart, dated phase
labels, the `cvd_brazil` dataset, and two vignettes reproducing
Ferraz et al. (2020). `lubridate` and `vdiffr` were dropped from
Suggests (unused).

Vignette build time is under 10 s each; the Monte Carlo tests that
verify the decision-interval tables are wrapped in `skip_on_cran()`.

## Reverse dependencies

There are no reverse dependencies on CRAN.
