# Multivariate EWMA chart -------------------------------------------------
#
# Multivariate generalisation of the (univariate) EWMA chart. The chart
# accumulates information across observations along every variable
# jointly, so it detects small persistent shifts in the *vector* mean
# faster than a Hotelling T-squared chart, at the cost of a longer
# reaction time to large shifts.
#
# Lowry, Woodall, Champ & Rigdon (1992) introduced the MEWMA. The
# recursion is:
#
#   Z_i = lambda * (X_i - mu_0) + (1 - lambda) * Z_{i-1},   Z_0 = 0
#
# (X_i is the p-vector of observations at step i, mu_0 the in-control
# mean.) The MEWMA test statistic is
#
#   T2_i = Z_i' * Sigma_Zi^{-1} * Z_i
#
# with the time-varying covariance
#
#   Sigma_Zi = (lambda / (2 - lambda)) * (1 - (1 - lambda)^(2i)) * Sigma
#
# (steady state, i -> Inf, drops the (1 - (1 - lambda)^(2i)) factor).
# The chart signals when T2_i exceeds the decision interval h, which
# is calibrated for the desired in-control ARL.
#
# Default decision intervals follow the Markov-chain values tabulated
# in Prabhu & Runger (1997, JQT 29:8-15) for ARL_0 ~ 200, p in 2..6
# and lambda in {0.05, 0.10, 0.20, 0.40}. For (lambda, p) outside the
# table, the user must supply `h` explicitly.
#
# References:
#
#   Lowry, C. A., Woodall, W. H., Champ, C. W., & Rigdon, S. E. (1992).
#     A Multivariate Exponentially Weighted Moving Average Control
#     Chart. Technometrics, 34(1), 46-53.
#     <doi:10.1080/00401706.1992.10485232>
#   Prabhu, S. S., & Runger, G. C. (1997). Designing a Multivariate
#     EWMA Control Chart. Journal of Quality Technology, 29(1), 8-15.
#     <doi:10.1080/00224065.1997.11979721>
#   Montgomery, D. C. (2019). Introduction to Statistical Quality
#     Control (8th ed.), Chapter 11. Wiley.

#' Multivariate EWMA control chart
#'
#' Constructs a multivariate Exponentially Weighted Moving Average
#' (MEWMA) chart for jointly monitoring `p` correlated variables.
#' The chart is more sensitive than the Hotelling `T^2` chart to
#' small persistent shifts in the *vector* mean, in the same way the
#' univariate EWMA is more sensitive than a Shewhart I chart.
#'
#' By default `target` (the in-control mean vector) and `cov` (the
#' in-control covariance) are estimated from the data. For Phase II
#' monitoring, supply both explicitly so the limits use the
#' calibration values. The decision interval `h` is calibrated by
#' lookup in the Prabhu & Runger (1997) table for `ARL_0 ~ 200`; if
#' the `(lambda, p)` combination is outside the tabulated range, the
#' user must pass `h` explicitly.
#'
#' @param data A data frame.
#' @param vars Tidy-select expression for the columns to monitor
#'   jointly. Must select at least 2 columns.
#' @param index Optional tidy-eval column for the x-axis.
#' @param target Optional length-`p` numeric vector. The in-control
#'   mean. Defaults to `colMeans(data[, vars])`.
#' @param cov Optional `p x p` covariance matrix. Defaults to
#'   `cov(data[, vars])`.
#' @param lambda Smoothing constant in `(0, 1]`. Default `0.1`.
#' @param h Decision interval (UCL on the `T^2` statistic). If
#'   `NULL`, looked up in the Prabhu & Runger (1997) table for
#'   `ARL_0 ~ 200`.
#' @param steady_state Logical. Use the steady-state covariance
#'   `(lambda / (2 - lambda)) * Sigma` everywhere instead of the
#'   time-varying form? Default `FALSE`.
#' @param locale One of `"en"`, `"pt"`, `"es"`, `"fr"`.
#' @param verbose Logical. Print progress messages?
#'
#' @return A [shewhart_chart] object of subclass `shewhart_mewma`.
#'   The augmented tibble has columns `.t2` (the MEWMA statistic),
#'   `.upper` (the decision interval `h`), and `.flag_signal`.
#'
#' @references
#' Lowry, C. A., Woodall, W. H., Champ, C. W., & Rigdon, S. E. (1992).
#' A Multivariate Exponentially Weighted Moving Average Control Chart.
#' *Technometrics*, 34(1), 46-53.
#' \doi{10.1080/00401706.1992.10485232}
#'
#' Prabhu, S. S., & Runger, G. C. (1997). Designing a Multivariate
#' EWMA Control Chart. *Journal of Quality Technology*, 29(1), 8-15.
#' \doi{10.1080/00224065.1997.11979721}
#'
#' @examples
#' set.seed(1)
#' Sigma <- matrix(c(1, 0.6, 0.6, 1), 2, 2)
#' base  <- MASS::mvrnorm(60, c(0, 0), Sigma)
#' shift <- MASS::mvrnorm(40, c(0.4, 0.4), Sigma)         # 0.4 sigma shift
#' df    <- data.frame(t = 1:100,
#'                     x1 = c(base[, 1], shift[, 1]),
#'                     x2 = c(base[, 2], shift[, 2]))
#' fit <- shewhart_mewma(df, vars = c(x1, x2), index = t,
#'                       target = c(0, 0), cov = Sigma,
#'                       lambda = 0.1)
#' print(fit)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
#' @export
shewhart_mewma <- function(data, vars, index = NULL,
                           target = NULL, cov = NULL,
                           lambda = 0.1, h = NULL,
                           steady_state = FALSE,
                           locale = getOption("shewhart.locale", "en"),
                           verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  if (!is.numeric(lambda) || length(lambda) != 1L ||
      lambda <= 0 || lambda > 1) {
    cli::cli_abort("{.arg lambda} must be a single number in (0, 1].")
  }

  vars_q   <- rlang::enquo(vars)
  vars_pos <- tidyselect::eval_select(vars_q, data)
  if (length(vars_pos) < 2L) {
    cli::cli_abort(c(
      "{.arg vars} must select at least 2 columns.",
      "i" = "Got {.val {length(vars_pos)}}."
    ))
  }
  vars_names <- names(vars_pos)
  X <- as.matrix(data[, vars_pos, drop = FALSE])
  if (!is.numeric(X) || anyNA(X)) {
    cli::cli_abort("All selected {.arg vars} must be numeric and complete.")
  }
  p <- ncol(X)
  m <- nrow(X)
  if (m < 2L) {
    cli::cli_abort("MEWMA chart needs at least 2 observations.")
  }

  # Index
  idx_q <- rlang::enquo(index)
  if (!is_quo_null(idx_q)) {
    idx_name <- rlang::as_name(idx_q)
    check_column(data, idx_name, arg = "index")
    idx <- dplyr::pull(data, !!idx_q)
  } else {
    idx_name <- "index"
    idx <- seq_len(m)
  }

  # Target & covariance
  if (is.null(target)) target <- colMeans(X)
  if (length(target) != p || !is.numeric(target)) {
    cli::cli_abort("{.arg target} must be a numeric vector of length {.val {p}}.")
  }
  if (is.null(cov)) cov <- stats::cov(X)
  if (!is.matrix(cov) || nrow(cov) != p || ncol(cov) != p) {
    cli::cli_abort("{.arg cov} must be a {.val {p}}x{.val {p}} numeric matrix.")
  }
  cov_inv <- tryCatch(solve(cov), error = function(e) NULL)
  if (is.null(cov_inv)) {
    cli::cli_abort("{.arg cov} is singular and cannot be inverted.")
  }

  # Decision interval (Prabhu & Runger 1997)
  if (is.null(h)) {
    h <- mewma_h_lookup(lambda, p)
    if (is.na(h)) {
      cli::cli_abort(c(
        "No tabulated decision interval for {.arg lambda} = {.val {lambda}}, p = {.val {p}}.",
        "i" = "Pass {.arg h} explicitly, or pick {.arg lambda} from {.val {c(0.05, 0.10, 0.20, 0.40)}}."
      ))
    }
  } else if (!is.numeric(h) || length(h) != 1L || h <= 0) {
    cli::cli_abort("{.arg h} must be a single positive number.")
  }

  inform_step("MEWMA p={.val {p}}, lambda={.val {lambda}}, h={.val {round(h, 3)}}.",
              verbose = verbose)

  # Recursion
  centred <- sweep(X, 2L, target, "-")
  Z <- matrix(0, nrow = m, ncol = p)
  prev <- numeric(p)
  for (i in seq_len(m)) {
    Z[i, ] <- lambda * centred[i, ] + (1 - lambda) * prev
    prev <- Z[i, ]
  }

  # T2 statistic with time-varying or steady-state covariance
  ratio <- lambda / (2 - lambda)
  t2    <- numeric(m)
  for (i in seq_len(m)) {
    sigma_zi <- if (steady_state) {
      ratio * cov
    } else {
      ratio * (1 - (1 - lambda)^(2 * i)) * cov
    }
    sigma_zi_inv <- solve(sigma_zi)
    t2[i] <- as.numeric(t(Z[i, ]) %*% sigma_zi_inv %*% Z[i, ])
  }

  flag <- t2 > h
  augmented <- tibble::tibble(
    !!idx_name := idx,
    .obs        = seq_len(m),
    .t2         = t2,
    .center     = NA_real_,
    .upper      = h,
    .lower      = 0,
    .flag_signal = flag,
    .flag_any    = flag
  )

  limits <- tibble::tibble(chart = "MEWMA", line = "UCL", value = h)

  pos_hits <- which(flag)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "mewma_h",
      description = sprintf("MEWMA T2 exceeds h = %.3f", h),
      value       = t2[pos_hits],
      severity    = "alarm"
    )
  }

  new_shewhart_chart(
    type         = "mewma",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = "mewma_h",
    sigma_hat    = NA_real_,
    sigma_method = "mewma",
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      vars         = vars_names,
      index_name   = idx_name,
      p            = p,
      m            = m,
      lambda       = lambda,
      h            = h,
      target       = target,
      cov          = cov,
      cov_inv      = cov_inv,
      steady_state = steady_state,
      locale       = locale
    )
  )
}

# Internal: Prabhu & Runger (1997) ARL_0 ~ 200 table ----------------------

#' @keywords internal
#' @noRd
mewma_h_lookup <- function(lambda, p) {
  # Prabhu & Runger (1997), Table 3, ARL_0 ~ 200, p = 2..6
  tbl <- list(
    "0.05" = c("2" = 7.35,  "3" = 9.16,  "4" = 10.59, "5" = 11.84, "6" = 12.94),
    "0.10" = c("2" = 8.64,  "3" = 10.45, "4" = 11.95, "5" = 13.26, "6" = 14.42),
    "0.20" = c("2" = 9.65,  "3" = 11.46, "4" = 12.97, "5" = 14.30, "6" = 15.50),
    "0.40" = c("2" = 10.20, "3" = 12.01, "4" = 13.52, "5" = 14.85, "6" = 16.06)
  )
  lkey <- sprintf("%.2f", lambda)
  if (!lkey %in% names(tbl)) return(NA_real_)
  pkey <- as.character(p)
  row  <- tbl[[lkey]]
  if (!pkey %in% names(row)) return(NA_real_)
  unname(row[pkey])
}
