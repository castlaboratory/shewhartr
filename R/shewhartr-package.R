#' shewhartr: Statistical Process Control with Tidyverse-Native Workflows
#'
#' The `shewhartr` package brings classical Statistical Process Control
#' (SPC) methodology into a modern, tidy-friendly R workflow. It implements
#' the full family of classical Shewhart control charts (I-MR, Xbar-R,
#' Xbar-S, p, np, c, u), regression-based charts for processes with trend,
#' runs tests (Nelson 1-8), Average Run Length (ARL) simulation, process
#' capability indices, Box-Cox guidance, and an explicit Phase I / Phase II
#' workflow.
#'
#' @section Design principles:
#'
#' \describe{
#'   \item{Tidyverse-native}{All constructors take `data` as the first
#'     argument, support tidy evaluation for column references via `{{ }}`,
#'     and accept a `.by` argument where group-aware behaviour makes sense.}
#'   \item{Object-oriented}{Every chart returns an S3 object of class
#'     `shewhart_chart` (with a specific subclass like `shewhart_i_mr`)
#'     supporting `print()`, `summary()`, `plot()`, `autoplot()`,
#'     `tidy()`, `glance()` and `augment()`.}
#'   \item{Diagnostic-rich}{Every chart can be passed through
#'     [shewhart_runs()] (configurable rule sets), [shewhart_arl()]
#'     (Monte Carlo ARL), [shewhart_diagnostics()] (Tukey-style residual
#'     panel) and [shewhart_capability()] (Cp, Cpk, Pp, Ppk with
#'     bootstrap CI).}
#'   \item{Statistically honest}{Counts are charted with exact Poisson
#'     limits when requested (`limits = "poisson"`), per Box's advice
#'     to model the right distribution rather than transform.}
#'   \item{Robust alternatives}{Most charts accept `sigma_method =
#'     "biweight"` for Tukey-style robust scale estimation as an
#'     alternative to the classical moving range.}
#'   \item{Internationalisation}{Plot labels and informative messages
#'     accept a `locale` argument (`"en"`, `"pt"`, `"es"`, `"fr"`).}
#' }
#'
#' @section The four families of functions:
#'
#' \describe{
#'   \item{Classical charts (variables)}{[shewhart_i_mr()],
#'     [shewhart_xbar_r()], [shewhart_xbar_s()].}
#'   \item{Classical charts (attributes)}{[shewhart_p()], [shewhart_np()],
#'     [shewhart_c()], [shewhart_u()].}
#'   \item{Regression-based chart}{[shewhart_regression()] for trended
#'     processes, with optional automatic phase detection via the runs
#'     test.}
#'   \item{Diagnostics & methodology}{[shewhart_runs()], [shewhart_arl()],
#'     [shewhart_diagnostics()], [shewhart_box_cox()],
#'     [shewhart_capability()], [calibrate()], [monitor()].}
#' }
#'
#' @section Recommended starting points:
#'
#' New users should start with `vignette("getting-started", package =
#' "shewhartr")` for a 5-minute overview, then move to the chart family
#' that matches their data type. The vignette `"phase1-phase2"`
#' explains the central distinction between estimation and monitoring,
#' and `"arl-simulation"` shows how to evaluate the operating
#' characteristics of any chart configuration.
#'
#' @references
#' Shewhart, W. A. (1931). *Economic Control of Quality of Manufactured
#' Product*. D. Van Nostrand.
#'
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
#' (8th ed.). Wiley. ISBN: 978-1-119-39930-8.
#'
#' Nelson, L. S. (1984). The Shewhart Control Chart - Tests for Special
#' Causes. *Journal of Quality Technology*, 16(4), 237-239.
#' \doi{10.1080/00224065.1984.11978921}
#'
#' Woodall, W. H. (2000). Controversies and Contradictions in Statistical
#' Process Control. *Journal of Quality Technology*, 32(4), 341-350.
#' \doi{10.1080/00224065.2000.11980013}
#'
#' Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
#' *Journal of the Royal Statistical Society, Series B*, 26(2), 211-252.
#' \doi{10.1111/j.2517-6161.1964.tb00553.x}
#'
#' Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.
#'
#' Wheeler, D. J., & Chambers, D. S. (1992). *Understanding Statistical
#' Process Control* (2nd ed.). SPC Press.
#'
#' @keywords internal
#' @aliases shewhartr-package
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||% .data := enquo enquos as_label as_name caller_env caller_arg
#' @importFrom stats lm nls predict residuals fitted coef sd qnorm pnorm qpois ppois
#' @importFrom stats setNames quantile median mad var na.omit complete.cases weighted.mean
#' @importFrom utils head tail
#' @importFrom broom tidy glance augment
## usethis namespace: end
NULL
