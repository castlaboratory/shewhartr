# Diagnostics -------------------------------------------------------------
#
# Two related but separable diagnostic tools:
#
#   shewhart_box_cox()       - profile log-likelihood for the Box-Cox
#                              power parameter, in the Box & Cox (1964)
#                              tradition. Returns the optimal lambda
#                              and a tibble of the profile.
#
#   shewhart_diagnostics()   - Tukey-style residual diagnostic panel:
#                              residuals vs. fitted, normal Q-Q,
#                              autocorrelation, moving-range plot,
#                              residual histogram. The point is not to
#                              produce a publication-quality figure
#                              but to surface the assumptions that
#                              every chart is silently making.

#' Box-Cox profile log-likelihood
#'
#' Computes the profile log-likelihood for the Box-Cox power parameter
#' lambda, applied to a single positive numeric series (regression to
#' a constant) or to the residuals of a linear model.
#'
#' Reports the lambda that maximises the profile likelihood and a
#' 95% confidence interval based on the chi-square approximation
#' to twice the log-likelihood drop (Box & Cox 1964, eq. 9).
#'
#' @param data A data frame, or a numeric vector. If a data frame,
#'   `value` must be supplied.
#' @param value Tidy-eval column reference for the response (only when
#'   `data` is a data frame).
#' @param lambda_grid Numeric vector of lambda values to evaluate.
#'   Default: a fine grid from -2 to 2.
#'
#' @return An object of class `shewhart_box_cox` with components
#'   `profile` (tibble of lambda vs. log-likelihood), `lambda_hat`
#'   (the maximiser), `ci` (95% CI). The object has its own
#'   `print()` method.
#'
#' @references
#' Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
#' *Journal of the Royal Statistical Society, Series B*, 26(2),
#' 211-252. \doi{10.1111/j.2517-6161.1964.tb00553.x}
#'
#' @examples
#' set.seed(1)
#' bc <- shewhart_box_cox(rlnorm(200, meanlog = 0, sdlog = 0.5))
#' bc$lambda_hat   # should be near 0 (log-normal data)
#'
#' @export
shewhart_box_cox <- function(data, value = NULL,
                             lambda_grid = seq(-2, 2, by = 0.05)) {

  if (is.numeric(data) && is.null(value)) {
    x <- data
  } else {
    check_data(data)
    v_q <- rlang::enquo(value)
    if (is_quo_null(v_q)) {
      cli::cli_abort("{.arg value} is required when {.arg data} is a data frame.")
    }
    x <- dplyr::pull(data, !!v_q)
  }
  check_numeric(x, allow_na = FALSE)
  if (any(x <= 0)) {
    cli::cli_abort(c(
      "Box-Cox requires strictly positive values.",
      "i" = "Found {.val {sum(x <= 0)}} non-positive value{?s}.",
      "i" = "Consider shifting the data or using {.fn loglog}."
    ))
  }

  ll <- function(lambda) {
    y_t <- box_cox(x, lambda)
    n   <- length(y_t)
    s2  <- mean((y_t - mean(y_t))^2)
    -0.5 * n * log(s2) + (lambda - 1) * sum(log(x))
  }

  profile <- tibble::tibble(
    lambda     = lambda_grid,
    loglik     = vapply(lambda_grid, ll, numeric(1L))
  )

  lambda_hat <- profile$lambda[which.max(profile$loglik)]
  ll_max     <- max(profile$loglik)
  threshold  <- ll_max - 0.5 * stats::qchisq(0.95, df = 1L)
  in_ci      <- profile$lambda[profile$loglik >= threshold]
  ci         <- if (length(in_ci) >= 2L) c(min(in_ci), max(in_ci)) else c(NA, NA)

  out <- list(
    profile     = profile,
    lambda_hat  = lambda_hat,
    ci          = ci,
    threshold   = threshold,
    n           = length(x)
  )
  class(out) <- "shewhart_box_cox"
  out
}

#' Internal helper to find the optimal Box-Cox lambda silently
#'
#' Used by `shewhart_regression(model = "auto")`. Returns the optimal
#' lambda only.
#'
#' @keywords internal
#' @noRd
shewhart_box_cox_lambda <- function(x) {
  x <- x[!is.na(x) & x > 0]
  if (length(x) < 5L) return(1)   # fall back to identity
  bc <- shewhart_box_cox(x, lambda_grid = seq(-2, 2, by = 0.1))
  bc$lambda_hat
}

#' @exportS3Method print shewhart_box_cox
print.shewhart_box_cox <- function(x, ...) {
  cli::cli_h1("Box-Cox profile likelihood")
  cli::cli_inform(c(
    "*" = "n = {.val {x$n}}",
    "*" = "lambda_hat = {.val {round(x$lambda_hat, 3)}}",
    "*" = "95% CI: [{.val {round(x$ci[1], 3)}}, {.val {round(x$ci[2], 3)}}]"
  ))
  invisible(x)
}

#' @exportS3Method ggplot2::autoplot shewhart_box_cox
autoplot.shewhart_box_cox <- function(object, locale = NULL, ...) {
  locale <- locale %||% getOption("shewhart.locale", "en")

  ggplot2::ggplot(object$profile,
                  ggplot2::aes(x = .data$lambda, y = .data$loglik)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_hline(yintercept = object$threshold,
                        linetype = "dashed", colour = "firebrick") +
    ggplot2::geom_vline(xintercept = object$lambda_hat,
                        linetype = "dotted") +
    ggplot2::geom_vline(xintercept = object$ci[1],
                        linetype = "dotted", colour = "firebrick") +
    ggplot2::geom_vline(xintercept = object$ci[2],
                        linetype = "dotted", colour = "firebrick") +
    ggplot2::labs(
      title = tr("diag_box_cox", locale),
      x     = tr("diag_lambda", locale),
      y     = "log L"
    ) +
    shewhart_theme()
}

# Tukey-style residual panel ----------------------------------------------

#' Tukey-style residual diagnostic panel
#'
#' For chart objects whose residuals are meaningful (`shewhart_i_mr`,
#' `shewhart_xbar_r`, `shewhart_xbar_s`, `shewhart_regression`),
#' produces the five-panel residual diagnostic favoured by exploratory
#' data analysis: residuals vs. fitted, normal Q-Q, autocorrelation,
#' moving-range plot of residuals, residual histogram. The aim is to
#' make the assumptions that the chart is making visible: independence
#' (ACF), normality (Q-Q, histogram), constant variance (residuals
#' vs. fitted), and the absence of trend in dispersion (moving range).
#'
#' @param chart A [shewhart_chart] object.
#' @param locale Optional override for the chart's stored locale.
#'
#' @return A list of `ggplot` objects with class
#'   `shewhart_diagnostics`. The print method composes the panels.
#'
#' @references
#' Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.
#'
#' Box, G. E. P., Hunter, W. G., & Hunter, J. S. (2005).
#' *Statistics for Experimenters: Design, Innovation, and Discovery*
#' (2nd ed.). Wiley.
#'
#' @examples
#' \donttest{
#' fit <- shewhart_i_mr(data.frame(y = rnorm(100)), value = y)
#' print(shewhart_diagnostics(fit))
#' }
#'
#' @export
shewhart_diagnostics <- function(chart, locale = NULL) {
  assert_chart(chart)
  locale <- locale %||% chart$metadata$locale %||% "en"

  aug <- chart$augmented
  resid <- aug$.value - aug$.center
  fitted <- aug$.center

  # Panel 1: residuals vs fitted ------------------------------------------
  p1 <- ggplot2::ggplot(data.frame(fitted = fitted, resid = resid),
                        ggplot2::aes(.data$fitted, .data$resid)) +
    ggplot2::geom_point(alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
    ggplot2::geom_smooth(formula = y ~ x, method = "loess",
                         se = FALSE, colour = "firebrick", linewidth = 0.6) +
    ggplot2::labs(title = tr("diag_residuals_fitted", locale),
                  x = "Fitted", y = "Residuals") +
    shewhart_theme()

  # Panel 2: Q-Q ----------------------------------------------------------
  qq <- stats::qqnorm(resid, plot.it = FALSE)
  p2 <- ggplot2::ggplot(data.frame(theoretical = qq$x, sample = qq$y),
                        ggplot2::aes(.data$theoretical, .data$sample)) +
    ggplot2::geom_point(alpha = 0.7) +
    ggplot2::geom_qq_line(ggplot2::aes(sample = .data$sample),
                          colour = "firebrick", linewidth = 0.6) +
    ggplot2::labs(title = tr("diag_qq_normal", locale),
                  x = "Theoretical", y = "Sample") +
    shewhart_theme()

  # Panel 3: ACF ----------------------------------------------------------
  ac <- stats::acf(resid, plot = FALSE, lag.max = min(30, length(resid) - 1L))
  ci <- 1.96 / sqrt(length(resid))
  p3 <- ggplot2::ggplot(data.frame(lag = as.numeric(ac$lag),
                                   acf = as.numeric(ac$acf)),
                        ggplot2::aes(x = .data$lag, y = .data$acf)) +
    ggplot2::geom_segment(ggplot2::aes(xend = .data$lag, yend = 0)) +
    ggplot2::geom_hline(yintercept = c(-ci, ci),
                        colour = "firebrick", linetype = "dashed") +
    ggplot2::labs(title = tr("diag_acf", locale), x = "Lag", y = "ACF") +
    shewhart_theme()

  # Panel 4: moving range -------------------------------------------------
  mr <- moving_range(resid)
  p4 <- ggplot2::ggplot(data.frame(obs = seq_along(mr), mr = mr),
                        ggplot2::aes(.data$obs, .data$mr)) +
    ggplot2::geom_line(colour = "grey50") +
    ggplot2::geom_point(alpha = 0.7) +
    ggplot2::labs(title = tr("diag_mr_plot", locale),
                  x = tr("label_observation", locale),
                  y = "MR(residuals)") +
    shewhart_theme()

  # Panel 5: histogram ----------------------------------------------------
  p5 <- ggplot2::ggplot(data.frame(resid = resid),
                        ggplot2::aes(x = .data$resid)) +
    ggplot2::geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
    ggplot2::labs(title = tr("diag_histogram", locale),
                  x = "Residuals", y = "") +
    shewhart_theme()

  out <- list(residuals_fitted = p1, qq = p2, acf = p3, mr = p4, histogram = p5)
  class(out) <- "shewhart_diagnostics"
  out
}

#' @exportS3Method print shewhart_diagnostics
print.shewhart_diagnostics <- function(x, ...) {
  if (requireNamespace("patchwork", quietly = TRUE)) {
    print(patchwork::wrap_plots(x, ncol = 2))
  } else {
    for (p in x) print(p)
  }
  invisible(x)
}
