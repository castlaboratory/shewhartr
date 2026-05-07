# Phase I / Phase II workflow ---------------------------------------------
#
# Woodall (2000) crystallised the distinction between Phase I (where
# the practitioner uses control charts retrospectively to identify
# assignable causes and establish stable in-control limits) and Phase
# II (where those limits are deployed prospectively to monitor new
# observations).
#
# Most R packages collapse the two into a single function call, which
# makes the Phase II step error-prone (limits get re-estimated from
# the new data). `calibrate()` returns an explicit Phase I object;
# `monitor()` consumes it and returns a fresh chart for new data,
# inheriting all limits.
#
# Reference:
#
#   Woodall, W. H. (2000). Controversies and Contradictions in
#     Statistical Process Control. Journal of Quality Technology,
#     32(4), 341-350. <doi:10.1080/00224065.2000.11980013>

#' Phase I calibration of a control chart
#'
#' Convenience wrapper that fits a control chart and tags its phase as
#' `"phase_1"` (the default for any chart constructor). The intent is
#' to make Phase I usage *explicit* in code: the practitioner
#' acknowledges that limits are being estimated.
#'
#' Optionally drops violations from the in-control estimate ("trimmed"
#' calibration), per the iterative procedure described in Montgomery
#' (2019) Section 6.2.3: if any observation falls outside the limits,
#' it is removed and the limits are recomputed; iterate until either
#' all remaining points are in control or no further trimming is
#' possible.
#'
#' @param data A data frame.
#' @param ... Arguments passed to a chart constructor.
#' @param chart A character key naming the chart constructor:
#'   `"i_mr"` (default), `"xbar_r"`, `"xbar_s"`, `"p"`, `"np"`, `"c"`,
#'   `"u"`, `"regression"`, `"ewma"`, `"cusum"`, `"hotelling"`,
#'   `"mewma"`, `"mcusum"`.
#' @param trim_outliers Logical. If `TRUE`, iteratively drop
#'   observations that violate the rules and re-estimate limits
#'   (Montgomery 2019, Section 6.2.3).
#' @param max_trim_iter Integer. Maximum trimming iterations.
#'
#' @return A [shewhart_chart] object with `$phase = "phase_1"`.
#'
#' @references
#' Woodall, W. H. (2000). Controversies and Contradictions in
#' Statistical Process Control. *Journal of Quality Technology*,
#' 32(4), 341-350. \doi{10.1080/00224065.2000.11980013}
#'
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Section 6.2.3.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(y = c(rnorm(40, mean = 100, sd = 2), 110, rnorm(20, 100, 2)))
#' calib <- calibrate(df, value = y, chart = "i_mr", trim_outliers = TRUE)
#' calib$n          # 60 if trim was avoided, fewer if outliers were removed
#'
#' @export
calibrate <- function(data, ..., chart = "i_mr",
                      trim_outliers = FALSE,
                      max_trim_iter = 5L) {

  check_data(data)
  chart <- rlang::arg_match(
    chart,
    values = c("i_mr", "xbar_r", "xbar_s", "p", "np", "c", "u",
               "regression", "ewma", "cusum", "hotelling",
               "mewma", "mcusum")
  )

  builder <- switch(chart,
    i_mr       = shewhart_i_mr,
    xbar_r     = shewhart_xbar_r,
    xbar_s     = shewhart_xbar_s,
    p          = shewhart_p,
    np         = shewhart_np,
    c          = shewhart_c,
    u          = shewhart_u,
    regression = shewhart_regression,
    ewma       = shewhart_ewma,
    cusum      = shewhart_cusum,
    hotelling  = shewhart_hotelling,
    mewma      = shewhart_mewma,
    mcusum     = shewhart_mcusum
  )

  fit <- builder(data, ...)
  fit$phase <- "phase_1"

  if (!trim_outliers) return(fit)

  for (iter in seq_len(max_trim_iter)) {
    if (nrow(fit$violations) == 0L) break
    drop_pos <- unique(fit$violations$position)
    cli::cli_alert_info(
      "Trim iteration {.val {iter}}: dropping {.val {length(drop_pos)}} observation{?s}."
    )
    keep <- setdiff(seq_len(nrow(data)), drop_pos)
    if (length(keep) < 10L) {
      cli::cli_warn("Fewer than 10 observations remain; stopping trim early.")
      break
    }
    fit <- builder(data[keep, , drop = FALSE], ...)
    fit$phase <- "phase_1"
  }

  fit
}

#' Phase II monitoring against pre-calibrated limits
#'
#' Applies the control limits (and rule set) from a calibrated
#' [shewhart_chart] object to fresh data. The new data must contain
#' the same columns used by the original chart constructor.
#'
#' Limits are *not* re-estimated; they are the limits stored on the
#' calibration object. Only the violation table is recomputed against
#' the new observations.
#'
#' @param data A data frame with the same columns as the data used to
#'   fit `chart`.
#' @param chart A pre-calibrated [shewhart_chart] object.
#'
#' @return A [shewhart_chart] object with `$phase = "phase_2"` and
#'   limits inherited from `chart`.
#'
#' @references
#' Woodall, W. H. (2000). Controversies and Contradictions in
#' Statistical Process Control. *Journal of Quality Technology*,
#' 32(4), 341-350.
#'
#' @examples
#' set.seed(1)
#' base    <- data.frame(y = rnorm(50, mean = 100, sd = 2))
#' new_obs <- data.frame(y = rnorm(20, mean = 102, sd = 2))   # small shift
#' calib   <- calibrate(base, value = y, chart = "i_mr")
#' alarms  <- monitor(new_obs, calib)
#' alarms$violations
#'
#' @export
monitor <- function(data, chart) {
  check_data(data)
  assert_chart(chart, arg = "chart")

  m <- chart$metadata

  # Reconstruct value vector from the new data using stored column names
  switch(chart$type,
    i_mr       = monitor_i_mr(data, chart),
    p          = monitor_p(data, chart),
    c          = monitor_c(data, chart),
    np         = monitor_np(data, chart),
    u          = monitor_u(data, chart),
    xbar_r     = monitor_xbar_r(data, chart),
    xbar_s     = monitor_xbar_s(data, chart),
    regression = monitor_regression(data, chart),
    ewma       = monitor_ewma(data, chart),
    cusum      = monitor_cusum(data, chart),
    hotelling  = monitor_hotelling(data, chart),
    mewma      = monitor_mewma(data, chart),
    mcusum     = monitor_mcusum(data, chart),
    cli::cli_abort(c(
      "Phase II monitoring not implemented for chart type {.val {chart$type}}."
    ))
  )
}

#' @keywords internal
#' @noRd
monitor_i_mr <- function(data, chart) {
  m  <- chart$metadata
  v  <- data[[m$value_name]]
  check_numeric(v, arg = m$value_name)

  centre <- chart$augmented$.center[1L]
  sigma  <- chart$sigma_hat
  upper  <- centre + 3 * sigma
  lower  <- centre - 3 * sigma

  flags <- flag_rules(v, rep(centre, length(v)), rep(sigma, length(v)),
                      chart$rules)

  augmented <- tibble::tibble(
    .obs       = seq_along(v),
    .value     = v,
    .center    = centre,
    .sigma     = sigma,
    .upper     = upper,
    .lower     = lower
  )
  if (!is.null(m$index_name) && m$index_name %in% names(data)) {
    augmented[[m$index_name]] <- data[[m$index_name]]
  }
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(v, rules = chart$rules,
                              center = centre, sigma = sigma)

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' @keywords internal
#' @noRd
monitor_p <- function(data, chart) {
  m <- chart$metadata
  defects_v <- data[[m$defects_name]]; check_count(defects_v, arg = m$defects_name)
  n_v       <- data[[m$n_name]];        check_count(n_v, arg = m$n_name)
  if (any(defects_v > n_v)) {
    cli::cli_abort("{.arg defects} cannot exceed {.arg n}.")
  }

  p_i  <- defects_v / n_v
  p_bar <- m$p_bar
  sigma_i <- sqrt(p_bar * (1 - p_bar) / n_v)
  upper   <- pmin(1, p_bar + 3 * sigma_i)
  lower   <- pmax(0, p_bar - 3 * sigma_i)

  flags <- flag_rules(p_i, rep(p_bar, length(p_i)), sigma_i, chart$rules)

  augmented <- tibble::tibble(
    .obs    = seq_along(p_i),
    .defects = defects_v,
    .n       = n_v,
    .value   = p_i,
    .center  = p_bar,
    .sigma   = sigma_i,
    .upper   = upper,
    .lower   = lower
  )
  if (!is.null(m$index_name) && m$index_name %in% names(data)) {
    augmented[[m$index_name]] <- data[[m$index_name]]
  }
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(p_i, rules = chart$rules,
                              center = p_bar, sigma = sigma_i)

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' @keywords internal
#' @noRd
monitor_c <- function(data, chart) {
  m <- chart$metadata
  defects_v <- data[[m$defects_name]]; check_count(defects_v, arg = m$defects_name)

  c_bar <- m$c_bar
  sigma <- sqrt(c_bar)
  upper <- chart$augmented$.upper[1L]
  lower <- chart$augmented$.lower[1L]

  flags <- flag_rules(defects_v,
                      rep(c_bar, length(defects_v)),
                      rep(sigma, length(defects_v)),
                      chart$rules)

  augmented <- tibble::tibble(
    .obs    = seq_along(defects_v),
    .value  = defects_v,
    .center = c_bar,
    .sigma  = sigma,
    .upper  = upper,
    .lower  = lower
  )
  if (!is.null(m$index_name) && m$index_name %in% names(data)) {
    augmented[[m$index_name]] <- data[[m$index_name]]
  }
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(defects_v, rules = chart$rules,
                              center = c_bar, sigma = sigma)

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' @keywords internal
#' @noRd
monitor_np <- function(data, chart) {
  m <- chart$metadata
  defects_v <- data[[m$defects_name]]; check_count(defects_v, arg = m$defects_name)
  n         <- m$n
  if (any(defects_v > n)) {
    cli::cli_abort("{.arg defects} cannot exceed stored subgroup size {.val {n}}.")
  }

  np_bar <- m$p_bar * n
  sigma  <- sqrt(np_bar * (1 - m$p_bar))
  upper  <- chart$augmented$.upper[1L]
  lower  <- chart$augmented$.lower[1L]

  flags <- flag_rules(defects_v,
                      rep(np_bar, length(defects_v)),
                      rep(sigma,  length(defects_v)),
                      chart$rules)

  augmented <- tibble::tibble(
    .obs    = seq_along(defects_v),
    .value  = defects_v,
    .center = np_bar,
    .sigma  = sigma,
    .upper  = upper,
    .lower  = lower
  )
  if (!is.null(m$index_name) && m$index_name %in% names(data)) {
    augmented[[m$index_name]] <- data[[m$index_name]]
  }
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(defects_v, rules = chart$rules,
                              center = np_bar, sigma = sigma)

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' @keywords internal
#' @noRd
monitor_u <- function(data, chart) {
  m <- chart$metadata
  defects_v  <- data[[m$defects_name]];  check_count(defects_v, arg = m$defects_name)
  exposure_v <- data[[m$exposure_name]]; check_numeric(exposure_v, arg = m$exposure_name)
  if (any(exposure_v <= 0)) {
    cli::cli_abort("{.arg exposure} values must be strictly positive.")
  }

  u_i     <- defects_v / exposure_v
  u_bar   <- m$u_bar
  sigma_i <- sqrt(u_bar / exposure_v)
  upper   <- u_bar + 3 * sigma_i
  lower   <- pmax(0, u_bar - 3 * sigma_i)

  flags <- flag_rules(u_i, rep(u_bar, length(u_i)), sigma_i, chart$rules)

  augmented <- tibble::tibble(
    .obs      = seq_along(u_i),
    .defects  = defects_v,
    .exposure = exposure_v,
    .value    = u_i,
    .center   = u_bar,
    .sigma    = sigma_i,
    .upper    = upper,
    .lower    = lower
  )
  if (!is.null(m$index_name) && m$index_name %in% names(data)) {
    augmented[[m$index_name]] <- data[[m$index_name]]
  }
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(u_i, rules = chart$rules,
                              center = u_bar, sigma = sigma_i)

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' @keywords internal
#' @noRd
monitor_xbar_r <- function(data, chart) {
  m <- chart$metadata
  v_n <- m$value_name
  g_n <- m$group_name
  check_column(data, v_n, arg = "value")
  check_column(data, g_n, arg = "subgroup")
  v <- data[[v_n]]; check_numeric(v, arg = v_n)

  agg <- dplyr::summarise(
    dplyr::group_by(data, .data[[g_n]]),
    .xbar = mean(.data[[v_n]], na.rm = TRUE),
    .r    = diff(range(.data[[v_n]], na.rm = TRUE)),
    .n    = sum(!is.na(.data[[v_n]])),
    .groups = "drop"
  )

  if (any(agg$.n != m$n)) {
    cli::cli_warn(c(
      "Phase II subgroup sizes differ from Phase I ({.val {m$n}}).",
      "i" = "Limits assume size {.val {m$n}}; results for unequal sizes are approximate."
    ))
  }

  centre   <- chart$augmented$.center[1L]
  sigma    <- chart$sigma_hat
  upper    <- chart$augmented$.upper[1L]
  lower    <- chart$augmented$.lower[1L]
  r_centre <- chart$augmented$.r_center[1L]
  r_upper  <- chart$augmented$.r_upper[1L]
  r_lower  <- chart$augmented$.r_lower[1L]

  flags <- flag_rules(agg$.xbar,
                      rep(centre, nrow(agg)),
                      rep(sigma / sqrt(m$n), nrow(agg)),
                      chart$rules)

  augmented <- tibble::tibble(
    !!g_n     := agg[[g_n]],
    .obs       = seq_len(nrow(agg)),
    .n         = agg$.n,
    .xbar      = agg$.xbar,
    .range     = agg$.r,
    .value     = agg$.xbar,
    .center    = centre,
    .sigma     = sigma / sqrt(m$n),
    .upper     = upper,
    .lower     = lower,
    .r_center  = r_centre,
    .r_upper   = r_upper,
    .r_lower   = r_lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(agg$.xbar, rules = chart$rules,
                              center = centre,
                              sigma  = sigma / sqrt(m$n))

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' @keywords internal
#' @noRd
monitor_xbar_s <- function(data, chart) {
  m <- chart$metadata
  v_n <- m$value_name
  g_n <- m$group_name
  check_column(data, v_n, arg = "value")
  check_column(data, g_n, arg = "subgroup")
  v <- data[[v_n]]; check_numeric(v, arg = v_n)

  agg <- dplyr::summarise(
    dplyr::group_by(data, .data[[g_n]]),
    .xbar = mean(.data[[v_n]], na.rm = TRUE),
    .s    = stats::sd(.data[[v_n]], na.rm = TRUE),
    .n    = sum(!is.na(.data[[v_n]])),
    .groups = "drop"
  )

  if (any(agg$.n != m$n)) {
    cli::cli_warn(c(
      "Phase II subgroup sizes differ from Phase I ({.val {m$n}}).",
      "i" = "Limits assume size {.val {m$n}}."
    ))
  }

  centre   <- chart$augmented$.center[1L]
  sigma    <- chart$sigma_hat
  upper    <- chart$augmented$.upper[1L]
  lower    <- chart$augmented$.lower[1L]
  s_centre <- chart$augmented$.s_center[1L]
  s_upper  <- chart$augmented$.s_upper[1L]
  s_lower  <- chart$augmented$.s_lower[1L]

  flags <- flag_rules(agg$.xbar,
                      rep(centre, nrow(agg)),
                      rep(sigma / sqrt(m$n), nrow(agg)),
                      chart$rules)

  augmented <- tibble::tibble(
    !!g_n     := agg[[g_n]],
    .obs       = seq_len(nrow(agg)),
    .n         = agg$.n,
    .xbar      = agg$.xbar,
    .s         = agg$.s,
    .value     = agg$.xbar,
    .center    = centre,
    .sigma     = sigma / sqrt(m$n),
    .upper     = upper,
    .lower     = lower,
    .s_center  = s_centre,
    .s_upper   = s_upper,
    .s_lower   = s_lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(agg$.xbar, rules = chart$rules,
                              center = centre,
                              sigma  = sigma / sqrt(m$n))

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

#' Phase II monitoring for regression-based control charts
#'
#' Projects the most recently estimated phase fit onto new index
#' values, uses the stored sigma to construct limits, and tests the
#' residuals with the same runs rules used in Phase I. The
#' implementation follows Mandel (1969) and Hawkins (1991): the
#' calibration model is treated as fixed for the purpose of detecting
#' future shifts.
#'
#' @keywords internal
#' @noRd
monitor_regression <- function(data, chart) {
  m   <- chart$metadata
  v_n <- m$value_name
  i_n <- m$index_name
  d_n <- m$dummy_name
  check_column(data, v_n, arg = "value")
  check_column(data, i_n, arg = "index")
  if (!is.null(d_n) && !d_n %in% names(data)) {
    cli::cli_abort("{.arg dummy} column {.field {d_n}} missing from new data.")
  }

  v <- data[[v_n]]; check_numeric(v, arg = v_n)

  # Use the LAST fit from Phase I (most recent state of the process)
  fits <- chart$fits
  if (is.null(fits) || length(fits) == 0L) {
    cli::cli_abort(c(
      "Cannot monitor: chart contains no stored fit.",
      "i" = "Was the chart calibrated successfully?"
    ))
  }
  last_fit <- fits[[length(fits)]]

  # Build a one-row-per-obs tibble matching the column names used at fit time
  newd <- tibble::tibble(.N = seq_len(nrow(data)))
  newd[[i_n]] <- data[[i_n]]
  if (!is.null(d_n)) newd[[d_n]] <- data[[d_n]]

  # Predict on response scale using the helper used internally in Phase I
  fitted <- predict_original(last_fit, newd, v_n)

  resid <- v - fitted
  sigma <- chart$sigma_hat
  upper <- fitted + 3 * sigma
  lower <- fitted - 3 * sigma

  flags <- flag_rules(v,
                      fitted,
                      rep(sigma, length(v)),
                      chart$rules)

  augmented <- tibble::tibble(
    .obs      = seq_along(v),
    .value    = v,
    .fitted   = fitted,
    .residual = resid,
    .center   = fitted,
    .sigma    = sigma,
    .upper    = upper,
    .lower    = lower,
    .phase    = factor("phase_2"),
    .phase_label = "phase_2"
  )
  if (i_n %in% names(data)) augmented[[i_n]] <- data[[i_n]]
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(v,
                              rules  = chart$rules,
                              center = fitted,
                              sigma  = rep(sigma, length(v)))

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

# Monitor: EWMA -----------------------------------------------------------

#' @keywords internal
#' @noRd
monitor_ewma <- function(data, chart) {
  m   <- chart$metadata
  v_n <- m$value_name
  check_column(data, v_n, arg = "value")
  v <- data[[v_n]]; check_numeric(v, arg = v_n)

  centre <- m$target
  sigma  <- chart$sigma_hat
  lambda <- m$lambda
  L      <- m$L

  # Continue the EWMA recursion from the last calibration point so that the
  # Phase II series begins where Phase I left off.
  z0   <- chart$augmented$.ewma[chart$n]
  z    <- numeric(length(v))
  prev <- z0
  for (i in seq_along(v)) {
    z[i] <- lambda * v[i] + (1 - lambda) * prev
    prev <- z[i]
  }

  # Phase II uses steady-state (asymptotic) limits — the Phase I baseline
  # has already absorbed the warm-up.
  ratio <- lambda / (2 - lambda)
  se    <- sigma * sqrt(ratio)
  upper <- centre + L * se
  lower <- centre - L * se

  sigma_eq <- rep(se / L * 3, length(v))
  flags <- flag_rules(z, rep(centre, length(v)), sigma_eq, chart$rules)

  augmented <- tibble::tibble(
    .obs    = seq_along(v),
    .value  = v,
    .ewma   = z,
    .center = centre,
    .sigma  = sigma,
    .upper  = upper,
    .lower  = lower
  )
  augmented[[m$index_name]] <- if (m$index_name %in% names(data)) {
    data[[m$index_name]]
  } else {
    seq_along(v)
  }
  augmented <- dplyr::bind_cols(augmented, flags)

  violations <- shewhart_runs(z, rules = chart$rules,
                              center = centre, sigma = sigma_eq)

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

# Monitor: CUSUM ----------------------------------------------------------

#' @keywords internal
#' @noRd
monitor_cusum <- function(data, chart) {
  m   <- chart$metadata
  v_n <- m$value_name
  check_column(data, v_n, arg = "value")
  v <- data[[v_n]]; check_numeric(v, arg = v_n)

  centre <- m$target
  sigma  <- chart$sigma_hat
  k      <- m$k
  decision <- m$decision

  # Continue both accumulators from the final Phase I values.
  c_pos <- numeric(length(v))
  c_neg <- numeric(length(v))
  prev_pos <- chart$augmented$.cusum_pos[chart$n]
  prev_neg <- chart$augmented$.cusum_neg[chart$n]
  ks <- k * sigma
  for (i in seq_along(v)) {
    c_pos[i] <- max(0,  prev_pos + (v[i] - centre) - ks)
    c_neg[i] <- max(0,  prev_neg - (v[i] - centre) - ks)
    prev_pos <- c_pos[i]
    prev_neg <- c_neg[i]
  }

  flag_signal <- (c_pos > decision) | (c_neg > decision)

  augmented <- tibble::tibble(
    .obs         = seq_along(v),
    .value       = v,
    .cusum_pos   = c_pos,
    .cusum_neg   = c_neg,
    .center      = 0,
    .sigma       = sigma,
    .upper       = decision,
    .lower       = -decision,
    .flag_signal = flag_signal,
    .flag_any    = flag_signal
  )
  augmented[[m$index_name]] <- if (m$index_name %in% names(data)) {
    data[[m$index_name]]
  } else {
    seq_along(v)
  }

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

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

# Monitor: Hotelling T-squared --------------------------------------------

#' @keywords internal
#' @noRd
monitor_hotelling <- function(data, chart) {
  m <- chart$metadata
  for (v in m$vars) check_column(data, v, arg = v)
  X <- as.matrix(data[, m$vars, drop = FALSE])
  if (!is.numeric(X) || anyNA(X)) {
    cli::cli_abort("All monitored variables must be numeric and complete.")
  }

  # Use the Phase II UCL formula and the calibration covariance / mean.
  if (m$n == 1L) {
    centered <- sweep(X, 2L, m$mean_vec, "-")
    t2 <- rowSums((centered %*% m$cov_inv) * centered)
    fq <- stats::qf(1 - m$alpha, df1 = m$p, df2 = m$m - m$p)
    ucl <- m$p * (m$m + 1) * (m$m - 1) / (m$m * (m$m - m$p)) * fq
    idx_count <- nrow(X)
  } else {
    # Subgrouped: each row in `data` is one observation; reduce to per-
    # subgroup means using the stored subgroup column name.
    sub_col <- m$subgroup
    if (is.null(sub_col) || !sub_col %in% names(data)) {
      cli::cli_abort("Subgrouped Hotelling monitoring needs column {.field {sub_col}}.")
    }
    groups <- split(seq_len(nrow(X)), data[[sub_col]])
    xbar_g <- do.call(rbind,
                      lapply(groups,
                             function(idx) colMeans(X[idx, , drop = FALSE])))
    centered <- sweep(xbar_g, 2L, m$mean_vec, "-")
    t2 <- m$n * rowSums((centered %*% m$cov_inv) * centered)
    df2 <- m$m * m$n - m$m - m$p + 1L
    fq  <- stats::qf(1 - m$alpha, df1 = m$p, df2 = df2)
    ucl <- m$p * (m$m + 1) * (m$n - 1) / df2 * fq
    idx_count <- length(groups)
  }

  flag <- t2 > ucl
  augmented <- tibble::tibble(
    .obs         = seq_len(idx_count),
    .t2          = t2,
    .center      = NA_real_,
    .upper       = ucl,
    .lower       = 0,
    .flag_signal = flag,
    .flag_any    = flag
  )
  augmented[[m$index_name]] <- if (m$index_name %in% names(data)) {
    if (m$n == 1L) data[[m$index_name]] else
      vapply(split(data[[m$index_name]], data[[m$subgroup]]),
             function(z) z[1L], data[[m$index_name]][1L])
  } else {
    seq_len(idx_count)
  }

  pos_hits <- which(flag)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "hotelling_ucl",
      description = sprintf("T2 exceeds UCL = %.3f", ucl),
      value       = t2[pos_hits],
      severity    = "alarm"
    )
  }

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

# Monitor: Multivariate EWMA ----------------------------------------------

#' @keywords internal
#' @noRd
monitor_mewma <- function(data, chart) {
  m <- chart$metadata
  for (v in m$vars) check_column(data, v, arg = v)
  X <- as.matrix(data[, m$vars, drop = FALSE])
  if (!is.numeric(X) || anyNA(X)) {
    cli::cli_abort("All monitored variables must be numeric and complete.")
  }

  centred <- sweep(X, 2L, m$target, "-")
  n_new   <- nrow(X)

  # Continue the recursion from the final Phase I value.
  z0   <- if (chart$n > 0L) {
    aug_p <- chart$augmented
    # Reconstruct Z_n by re-running the recursion on the original data is
    # overkill; instead carry the implicit Z = 0 reset and use the
    # Phase II steady-state covariance, which is the recommended practice
    # (Lowry et al. 1992 §4).
    rep(0, m$p)
  } else rep(0, m$p)

  Z <- matrix(0, nrow = n_new, ncol = m$p)
  prev <- z0
  for (i in seq_len(n_new)) {
    Z[i, ] <- m$lambda * centred[i, ] + (1 - m$lambda) * prev
    prev <- Z[i, ]
  }

  ratio    <- m$lambda / (2 - m$lambda)
  sigma_zi <- ratio * m$cov         # steady-state for Phase II
  sigma_zi_inv <- solve(sigma_zi)
  t2 <- numeric(n_new)
  for (i in seq_len(n_new)) {
    t2[i] <- as.numeric(t(Z[i, ]) %*% sigma_zi_inv %*% Z[i, ])
  }

  flag <- t2 > m$h
  augmented <- tibble::tibble(
    .obs         = seq_len(n_new),
    .t2          = t2,
    .center      = NA_real_,
    .upper       = m$h,
    .lower       = 0,
    .flag_signal = flag,
    .flag_any    = flag
  )
  augmented[[m$index_name]] <- if (m$index_name %in% names(data)) {
    data[[m$index_name]]
  } else {
    seq_len(n_new)
  }

  pos_hits <- which(flag)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "mewma_h",
      description = sprintf("MEWMA T2 exceeds h = %.3f", m$h),
      value       = t2[pos_hits],
      severity    = "alarm"
    )
  }

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}

# Monitor: Multivariate CUSUM ---------------------------------------------

#' @keywords internal
#' @noRd
monitor_mcusum <- function(data, chart) {
  m <- chart$metadata
  for (v in m$vars) check_column(data, v, arg = v)
  X <- as.matrix(data[, m$vars, drop = FALSE])
  if (!is.numeric(X) || anyNA(X)) {
    cli::cli_abort("All monitored variables must be numeric and complete.")
  }

  centred <- sweep(X, 2L, m$target, "-")
  n_new   <- nrow(X)

  # Continue from the final Phase I S-vector so the recursion picks up
  # exactly where the calibration left off (this is the recommendation
  # in Crosier 1988 §5 for prospective use).
  prev <- m$last_S %||% numeric(m$p)
  S    <- matrix(0, nrow = n_new, ncol = m$p)
  Y    <- numeric(n_new)
  for (i in seq_len(n_new)) {
    V  <- prev + centred[i, ]
    Ci <- sqrt(as.numeric(t(V) %*% m$cov_inv %*% V))
    if (Ci <= m$k) {
      S[i, ] <- 0
    } else {
      S[i, ] <- V * (1 - m$k / Ci)
    }
    Y[i] <- sqrt(as.numeric(t(S[i, ]) %*% m$cov_inv %*% S[i, ]))
    prev <- S[i, ]
  }

  flag <- Y > m$h
  augmented <- tibble::tibble(
    .obs         = seq_len(n_new),
    .y           = Y,
    .center      = NA_real_,
    .upper       = m$h,
    .lower       = 0,
    .flag_signal = flag,
    .flag_any    = flag
  )
  augmented[[m$index_name]] <- if (m$index_name %in% names(data)) {
    data[[m$index_name]]
  } else {
    seq_len(n_new)
  }

  pos_hits <- which(flag)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "mcusum_h",
      description = sprintf("MCUSUM Y exceeds h = %.3f", m$h),
      value       = Y[pos_hits],
      severity    = "alarm"
    )
  }

  out <- chart
  out$augmented  <- augmented
  out$violations <- violations
  out$phase      <- "phase_2"
  out$n          <- nrow(augmented)
  out
}
