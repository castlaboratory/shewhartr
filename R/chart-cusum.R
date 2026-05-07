# CUSUM chart -------------------------------------------------------------
#
# Tabular two-sided CUSUM (Cumulative Sum) chart. Where Shewhart and
# EWMA charts plot a smoothed statistic against fixed limits, the
# CUSUM accumulates *signed* deviations from a target and signals when
# the accumulated drift exceeds a decision interval.
#
# Definitions (Page 1954; Hawkins & Olwell 1998; Montgomery 2019, ch. 9):
#
#   C+_0 = C-_0 = 0
#   C+_i = max(0,  C+_{i-1} + (x_i - mu) - k * sigma)
#   C-_i = max(0,  C-_{i-1} - (x_i - mu) - k * sigma)
#
# Signal:  C+_i  > h * sigma   (upward shift)
#       OR C-_i  > h * sigma   (downward shift)
#
# `k` is the reference value (in units of sigma) — typically half the
# minimum shift size you care about detecting; conventional default
# is k = 0.5 (target sensitivity to 1-sigma shifts). `h` is the
# decision interval (in units of sigma); h = 4 gives ARL_0 ~ 168 and
# h = 5 gives ARL_0 ~ 465 for k = 0.5 (Hawkins & Olwell 1998, Table 3.1).
#
# CUSUM does not use Nelson runs rules — the cumulative statistic
# already encodes them implicitly. The only "rule" is the decision
# interval, captured in the `.flag_signal` column.
#
# References:
#
#   Page, E. S. (1954). Continuous Inspection Schemes. Biometrika,
#     41(1-2), 100-115. <doi:10.1093/biomet/41.1-2.100>
#   Hawkins, D. M., & Olwell, D. H. (1998). Cumulative Sum Charts and
#     Charting for Quality Improvement. Springer.
#   Montgomery, D. C. (2019). Introduction to Statistical Quality Control
#     (8th ed.), Chapter 9. Wiley.

#' Tabular CUSUM control chart
#'
#' Constructs a two-sided tabular CUSUM chart for a single column of
#' individual measurements. Two cumulative statistics, `C+` (upward)
#' and `C-` (downward), are accumulated against a target with a
#' reference value `k`; an alarm fires when either crosses the
#' decision interval `h * sigma`.
#'
#' By default, sigma is estimated from the moving range of `value`
#' (`MR_bar / 1.128`); the target is the mean of `value`. Either can
#' be overridden via `target` and `sigma` for Phase II monitoring
#' against pre-calibrated values.
#'
#' @param data A data frame.
#' @param value Tidy-eval column reference for the measurement.
#' @param index Optional tidy-eval column reference for the x-axis.
#' @param target Numeric. Process target. Defaults to `mean(value)`.
#' @param sigma Numeric. Process sigma. Defaults to `MR_bar / 1.128`.
#' @param k Numeric. Reference value in units of sigma. Default `0.5`,
#'   tuned to detect 1-sigma shifts.
#' @param h Numeric. Decision interval in units of sigma. Default `4`,
#'   giving `ARL_0 ~ 168` for `k = 0.5`. Use `h = 5` for `ARL_0 ~ 465`
#'   (Hawkins & Olwell 1998).
#' @param locale One of `"en"`, `"pt"`, `"es"`, `"fr"`.
#' @param verbose Logical. Print progress messages?
#'
#' @return A [shewhart_chart] object of subclass `shewhart_cusum`. The
#'   `augmented` slot has columns `.value`, `.cusum_pos`, `.cusum_neg`
#'   (the two accumulated statistics, both non-negative), `.upper`
#'   (the decision interval `h * sigma`), and `.flag_signal`.
#'
#' @references
#' Page, E. S. (1954). Continuous Inspection Schemes. *Biometrika*,
#' 41(1-2), 100-115. \doi{10.1093/biomet/41.1-2.100}
#'
#' Hawkins, D. M., & Olwell, D. H. (1998). *Cumulative Sum Charts and
#' Charting for Quality Improvement*. Springer.
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
#' fit <- shewhart_cusum(df, value = y, index = day)
#' print(fit)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
#' @export
shewhart_cusum <- function(data, value, index = NULL,
                           target = NULL, sigma = NULL,
                           k = 0.5, h = 4,
                           locale = getOption("shewhart.locale", "en"),
                           verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  if (!is.numeric(k) || length(k) != 1L || k <= 0) {
    cli::cli_abort("{.arg k} must be a positive number.")
  }
  if (!is.numeric(h) || length(h) != 1L || h <= 0) {
    cli::cli_abort("{.arg h} must be a positive number.")
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
    cli::cli_abort("CUSUM chart needs at least 5 observations; got {.val {length(v)}}.")
  }

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

  inform_step("CUSUM with k = {.val {k}}, h = {.val {h}}.", verbose = verbose)

  # CUSUM recursion --------------------------------------------------------
  c_pos <- numeric(length(v))
  c_neg <- numeric(length(v))
  ks    <- k * sigma_hat
  for (i in seq_along(v)) {
    prev_pos <- if (i == 1L) 0 else c_pos[i - 1L]
    prev_neg <- if (i == 1L) 0 else c_neg[i - 1L]
    c_pos[i] <- max(0,  prev_pos + (v[i] - centre) - ks)
    c_neg[i] <- max(0,  prev_neg - (v[i] - centre) - ks)
  }

  decision <- h * sigma_hat
  flag_signal <- (c_pos > decision) | (c_neg > decision)

  augmented <- tibble::tibble(
    !!index_name := idx,
    .obs          = seq_along(v),
    .value        = v,
    .cusum_pos    = c_pos,
    .cusum_neg    = c_neg,
    .center       = 0,
    .sigma        = sigma_hat,
    .upper        = decision,
    .lower        = -decision,
    .flag_signal  = flag_signal,
    .flag_any     = flag_signal
  )

  limits <- tibble::tibble(
    chart  = c("CUSUM", "CUSUM"),
    line   = c("h_upper", "h_lower"),
    value  = c(decision, -decision)
  )

  # Synthesise a violations tibble shaped like shewhart_runs() output
  pos_hits <- which(flag_signal)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "cusum_decision",
      description = sprintf("CUSUM exceeds h*sigma = %.3f", decision),
      value       = pmax(c_pos[pos_hits], c_neg[pos_hits]),
      severity    = "alarm"
    )
  }

  new_shewhart_chart(
    type         = "cusum",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = "cusum_decision",
    sigma_hat    = sigma_hat,
    sigma_method = if (is.null(sigma)) "mr" else "user",
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      value_name = value_name,
      index_name = index_name,
      target     = centre,
      k          = k,
      h          = h,
      decision   = decision,
      locale     = locale
    )
  )
}
