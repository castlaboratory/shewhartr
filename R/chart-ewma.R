# EWMA chart --------------------------------------------------------------
#
# Exponentially Weighted Moving Average (EWMA) chart for individual
# measurements. Where the Shewhart I chart only uses the most recent
# observation, the EWMA accumulates information across observations,
# making it more sensitive to small persistent shifts. The classic
# reference is Roberts (1959), with the steady-state and time-varying
# limits as worked out in Lucas & Saccucci (1990).
#
# Definitions (Roberts 1959; Montgomery 2019, ch. 9):
#
#   z_0 = mu           (target / centre)
#   z_i = lambda * x_i + (1 - lambda) * z_{i-1}
#
# Var(z_i) = sigma^2 * (lambda / (2 - lambda)) * (1 - (1 - lambda)^(2i))
#
# Time-varying limits:
#   UCL_i = mu + L * sigma * sqrt(Var(z_i) / sigma^2)
#   LCL_i = mu - L * sigma * sqrt(Var(z_i) / sigma^2)
#
# Steady-state limits (i -> infinity):
#   UCL = mu + L * sigma * sqrt(lambda / (2 - lambda))
#
# Defaults (lambda = 0.2, L = 2.7) give ARL_0 ~ 370 and good sensitivity
# to shifts of 0.5 to 1 sigma. For larger shifts, raise lambda; for
# smaller shifts, lower it. See the table on Montgomery (2019) p. 421
# for ARL profiles.
#
# References:
#
#   Roberts, S. W. (1959). Control Chart Tests Based on Geometric Moving
#     Averages. Technometrics, 1(3), 239-250.
#     <doi:10.1080/00401706.1959.10489860>
#   Lucas, J. M., & Saccucci, M. S. (1990). Exponentially Weighted Moving
#     Average Control Schemes: Properties and Enhancements. Technometrics,
#     32(1), 1-12. <doi:10.1080/00401706.1990.10484583>
#   Montgomery, D. C. (2019). Introduction to Statistical Quality Control
#     (8th ed.), Chapter 9. Wiley.

#' Exponentially Weighted Moving Average (EWMA) control chart
#'
#' Constructs an EWMA chart for a single column of individual
#' measurements. The chart is more sensitive than a Shewhart I chart
#' to small but persistent shifts in the process mean, at the cost of
#' a longer reaction time to large shifts.
#'
#' By default, sigma is estimated from the moving range of `value`
#' (Wheeler 1992 convention, `MR_bar / 1.128`); the centre is the mean
#' of `value`. Either can be overridden via `target` and `sigma` for
#' Phase II monitoring against pre-calibrated values.
#'
#' Limits are time-varying by default — they widen out from `target`
#' as the EWMA "warms up" — converging to the asymptotic limits as
#' `i -> infinity`. Set `steady_state = TRUE` to use the asymptotic
#' limits everywhere (commonly chosen when calibrating from a long
#' baseline).
#'
#' @param data A data frame.
#' @param value Tidy-eval column reference for the measurement.
#' @param index Optional tidy-eval column reference for the x-axis.
#' @param target Numeric. Process target / centre line. Defaults to
#'   `mean(value)`.
#' @param sigma Numeric. Process sigma. Defaults to `MR_bar / 1.128`.
#' @param lambda Numeric in `(0, 1]`. Smoothing constant. Default
#'   `0.2`. Smaller lambda = more memory, more sensitive to small
#'   shifts.
#' @param L Numeric. Width of the limits in standard errors of the
#'   EWMA. Default `2.7`, which combined with `lambda = 0.2` yields
#'   `ARL_0 ~ 370` (Lucas & Saccucci 1990).
#' @param steady_state Logical. Use asymptotic (constant) limits
#'   instead of time-varying ones?
#' @param rules Character vector of runs rules to flag. Defaults to
#'   Nelson 1 only — the EWMA's own limits already encode most of the
#'   diagnostic power and the higher-order Nelson rules are not
#'   designed for autocorrelated statistics.
#' @param locale One of `"en"`, `"pt"`, `"es"`, `"fr"`.
#' @param verbose Logical. Print progress messages?
#'
#' @return A [shewhart_chart] object of subclass `shewhart_ewma`. The
#'   `augmented` slot has columns `.value` (the original observation),
#'   `.ewma` (the smoothed statistic z_i, plotted on the chart), and
#'   the usual `.center`, `.upper`, `.lower`, `.flag_*`.
#'
#' @references
#' Roberts, S. W. (1959). Control Chart Tests Based on Geometric Moving
#' Averages. *Technometrics*, 1(3), 239-250.
#' \doi{10.1080/00401706.1959.10489860}
#'
#' Lucas, J. M., & Saccucci, M. S. (1990). Exponentially Weighted
#' Moving Average Control Schemes: Properties and Enhancements.
#' *Technometrics*, 32(1), 1-12.
#' \doi{10.1080/00401706.1990.10484583}
#'
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 9.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   day = 1:80,
#'   y   = c(rnorm(40, mean = 100, sd = 2),
#'           rnorm(40, mean = 101, sd = 2))   # 0.5 sigma shift
#' )
#' fit <- shewhart_ewma(df, value = y, index = day)
#' print(fit)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
#' @export
shewhart_ewma <- function(data, value, index = NULL,
                          target = NULL, sigma = NULL,
                          lambda = 0.2, L = 2.7,
                          steady_state = FALSE,
                          rules = "nelson_1_beyond_3s",
                          locale = getOption("shewhart.locale", "en"),
                          verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  if (!is.numeric(lambda) || length(lambda) != 1L ||
      lambda <= 0 || lambda > 1) {
    cli::cli_abort("{.arg lambda} must be a single number in (0, 1].")
  }
  if (!is.numeric(L) || length(L) != 1L || L <= 0) {
    cli::cli_abort("{.arg L} must be a positive number.")
  }

  value_q <- rlang::enquo(value)
  index_q <- rlang::enquo(index)
  value_name <- rlang::as_name(value_q)
  check_column(data, value_name, arg = "value")
  v <- dplyr::pull(data, !!value_q)
  check_numeric(v, arg = "value")

  if (is_quo_null(index_q)) {
    idx <- seq_along(v)
    index_name <- "index"
  } else {
    index_name <- rlang::as_name(index_q)
    check_column(data, index_name, arg = "index")
    idx <- dplyr::pull(data, !!index_q)
  }

  if (length(v) < 5L) {
    cli::cli_abort("EWMA chart needs at least 5 observations; got {.val {length(v)}}.")
  }

  # Centre and sigma -------------------------------------------------------
  centre <- if (is.null(target)) mean(v, na.rm = TRUE) else {
    if (!is.numeric(target) || length(target) != 1L) {
      cli::cli_abort("{.arg target} must be a single number.")
    }
    target
  }
  sigma_hat <- if (is.null(sigma)) mr_bar(v) / 1.128 else {
    if (!is.numeric(sigma) || length(sigma) != 1L || sigma <= 0) {
      cli::cli_abort("{.arg sigma} must be a single positive number.")
    }
    sigma
  }
  if (!is.finite(sigma_hat) || sigma_hat <= 0) {
    cli::cli_abort("Estimated sigma is {.val {sigma_hat}}; cannot proceed.")
  }

  inform_step("EWMA with {.val {lambda}} smoothing, L = {.val {L}}.",
              verbose = verbose)

  # EWMA recursion ---------------------------------------------------------
  z <- numeric(length(v))
  prev <- centre
  for (i in seq_along(v)) {
    z[i] <- lambda * v[i] + (1 - lambda) * prev
    prev <- z[i]
  }

  # Time-varying or steady-state limits ------------------------------------
  i_seq    <- seq_along(v)
  ratio    <- lambda / (2 - lambda)
  if (steady_state) {
    se <- rep(sigma_hat * sqrt(ratio), length(v))
  } else {
    se <- sigma_hat * sqrt(ratio * (1 - (1 - lambda) ^ (2 * i_seq)))
  }
  upper <- centre + L * se
  lower <- centre - L * se

  # Flags ------------------------------------------------------------------
  # Pass z (not v) and the time-varying sigma-equivalent so rule_n1 fires
  # at the correct boundary. Higher Nelson rules are evaluated against
  # the EWMA series too.
  sigma_eq <- se / L * 3   # vector such that center + 3*sigma_eq == upper
  flags <- flag_rules(z, rep(centre, length(v)), sigma_eq, rules)

  augmented <- tibble::tibble(
    !!index_name := idx,
    .obs          = i_seq,
    .value        = v,
    .ewma         = z,
    .center       = centre,
    .sigma        = sigma_hat,
    .upper        = upper,
    .lower        = lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  limits <- tibble::tibble(
    chart  = "EWMA",
    line   = c("CL", "UCL_asymptotic", "LCL_asymptotic"),
    value  = c(centre,
               centre + L * sigma_hat * sqrt(ratio),
               centre - L * sigma_hat * sqrt(ratio))
  )

  violations <- shewhart_runs(z,
                              rules  = rules,
                              center = centre,
                              sigma  = sigma_eq)

  new_shewhart_chart(
    type         = "ewma",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = rules,
    sigma_hat    = sigma_hat,
    sigma_method = if (is.null(sigma)) "mr" else "user",
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      value_name   = value_name,
      index_name   = index_name,
      target       = centre,
      lambda       = lambda,
      L            = L,
      steady_state = steady_state,
      locale       = locale
    )
  )
}
