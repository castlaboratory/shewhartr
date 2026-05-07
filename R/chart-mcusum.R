# Multivariate CUSUM chart ------------------------------------------------
#
# Crosier (1988) introduced the most widely used multivariate CUSUM,
# built on a shrinkage operator that resets the cumulative vector to
# zero when its Mahalanobis norm falls below a reference value k. The
# Pignatiello & Runger (1990) variant exists too, but Crosier's
# version is the one in the standard SPC textbooks (Montgomery 2019,
# §11.3.3) and it is what `qcc::mcusum.qcc` implements.
#
# Recursion:
#
#   S_0 = 0
#   For i = 1, 2, ...
#     V_i = S_{i-1} + (X_i - mu_0)
#     C_i = sqrt(V_i' Sigma^{-1} V_i)        (Mahalanobis distance)
#     If C_i <= k         S_i = 0
#     Else                S_i = V_i * (1 - k / C_i)
#     Y_i = sqrt(S_i' Sigma^{-1} S_i)
#
# The chart signals when Y_i > h. The reference value k plays the
# same role as in the univariate CUSUM: half the smallest shift size
# the chart should detect, expressed in sigma units. h is the
# decision interval, calibrated for the desired in-control ARL.
#
# Default decision intervals follow Crosier (1988) Table 1, k = 0.5,
# ARL_0 ~ 200, for p = 2..10. Outside that grid the user supplies h.
#
# References:
#
#   Crosier, R. B. (1988). Multivariate Generalizations of Cumulative
#     Sum Quality-Control Schemes. Technometrics, 30(3), 291-303.
#     <doi:10.1080/00401706.1988.10488402>
#   Pignatiello, J. J., & Runger, G. C. (1990). Comparisons of
#     Multivariate CUSUM Charts. Journal of Quality Technology, 22(3),
#     173-186. <doi:10.1080/00224065.1990.11979237>
#   Montgomery, D. C. (2019). Introduction to Statistical Quality
#     Control (8th ed.), Chapter 11.3.3. Wiley.

#' Multivariate CUSUM control chart (Crosier 1988)
#'
#' Constructs a multivariate CUSUM chart for jointly monitoring `p`
#' correlated variables. Like the univariate CUSUM it accumulates
#' deviations from a target with a reference value `k` that decides
#' when the accumulator resets; unlike a Hotelling `T^2` chart it
#' carries memory across observations and so detects small persistent
#' shifts faster.
#'
#' @param data A data frame.
#' @param vars Tidy-select expression for the columns to monitor
#'   jointly. At least 2 columns.
#' @param index Optional tidy-eval column for the x-axis.
#' @param target Optional length-`p` numeric vector. The in-control
#'   mean. Defaults to `colMeans(data[, vars])`.
#' @param cov Optional `p x p` covariance matrix. Defaults to
#'   `cov(data[, vars])`.
#' @param k Reference value, in sigma units. Default `0.5`, tuned
#'   for shifts of `1 sigma`. Lower `k` makes the chart sensitive to
#'   smaller shifts but increases false alarms.
#' @param h Decision interval. If `NULL`, looked up in the Crosier
#'   (1988) Table 1 for `k = 0.5`, `ARL_0 ~ 200`, `p = 2..10`.
#' @param locale One of `"en"`, `"pt"`, `"es"`, `"fr"`.
#' @param verbose Logical. Print progress messages?
#'
#' @return A [shewhart_chart] object of subclass `shewhart_mcusum`.
#'   The augmented tibble has columns `.y` (the chart statistic),
#'   `.upper` (the decision interval `h`), and `.flag_signal`.
#'
#' @references
#' Crosier, R. B. (1988). Multivariate Generalizations of Cumulative
#' Sum Quality-Control Schemes. *Technometrics*, 30(3), 291-303.
#' \doi{10.1080/00401706.1988.10488402}
#'
#' Pignatiello, J. J., & Runger, G. C. (1990). Comparisons of
#' Multivariate CUSUM Charts. *Journal of Quality Technology*, 22(3),
#' 173-186. \doi{10.1080/00224065.1990.11979237}
#'
#' @examples
#' set.seed(1)
#' Sigma <- matrix(c(1, 0.6, 0.6, 1), 2, 2)
#' base  <- MASS::mvrnorm(60, c(0, 0), Sigma)
#' shift <- MASS::mvrnorm(40, c(0.6, 0.6), Sigma)
#' df    <- data.frame(t = 1:100,
#'                     x1 = c(base[, 1], shift[, 1]),
#'                     x2 = c(base[, 2], shift[, 2]))
#' fit <- shewhart_mcusum(df, vars = c(x1, x2), index = t,
#'                        target = c(0, 0), cov = Sigma)
#' print(fit)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
#' @export
shewhart_mcusum <- function(data, vars, index = NULL,
                            target = NULL, cov = NULL,
                            k = 0.5, h = NULL,
                            locale = getOption("shewhart.locale", "en"),
                            verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  if (!is.numeric(k) || length(k) != 1L || k <= 0) {
    cli::cli_abort("{.arg k} must be a single positive number.")
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
    cli::cli_abort("MCUSUM chart needs at least 2 observations.")
  }

  idx_q <- rlang::enquo(index)
  if (!is_quo_null(idx_q)) {
    idx_name <- rlang::as_name(idx_q)
    check_column(data, idx_name, arg = "index")
    idx <- dplyr::pull(data, !!idx_q)
  } else {
    idx_name <- "index"
    idx <- seq_len(m)
  }

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

  if (is.null(h)) {
    h <- mcusum_h_lookup(k, p)
    if (is.na(h)) {
      cli::cli_abort(c(
        "No tabulated decision interval for {.arg k} = {.val {k}}, p = {.val {p}}.",
        "i" = "Pass {.arg h} explicitly. The lookup table covers k = 0.5 and p = 2..10."
      ))
    }
  } else if (!is.numeric(h) || length(h) != 1L || h <= 0) {
    cli::cli_abort("{.arg h} must be a single positive number.")
  }

  inform_step("MCUSUM p={.val {p}}, k={.val {k}}, h={.val {round(h, 3)}}.",
              verbose = verbose)

  centred <- sweep(X, 2L, target, "-")
  S    <- matrix(0, nrow = m, ncol = p)
  Y    <- numeric(m)
  Cval <- numeric(m)
  prev <- numeric(p)
  for (i in seq_len(m)) {
    V    <- prev + centred[i, ]
    Ci   <- sqrt(as.numeric(t(V) %*% cov_inv %*% V))
    Cval[i] <- Ci
    if (Ci <= k) {
      S[i, ] <- 0
    } else {
      S[i, ] <- V * (1 - k / Ci)
    }
    Y[i] <- sqrt(as.numeric(t(S[i, ]) %*% cov_inv %*% S[i, ]))
    prev <- S[i, ]
  }

  flag <- Y > h
  augmented <- tibble::tibble(
    !!idx_name := idx,
    .obs        = seq_len(m),
    .y          = Y,
    .center     = NA_real_,
    .upper      = h,
    .lower      = 0,
    .flag_signal = flag,
    .flag_any    = flag
  )

  limits <- tibble::tibble(chart = "MCUSUM", line = "UCL", value = h)

  pos_hits <- which(flag)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "mcusum_h",
      description = sprintf("MCUSUM Y exceeds h = %.3f", h),
      value       = Y[pos_hits],
      severity    = "alarm"
    )
  }

  new_shewhart_chart(
    type         = "mcusum",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = "mcusum_h",
    sigma_hat    = NA_real_,
    sigma_method = "mcusum",
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      vars       = vars_names,
      index_name = idx_name,
      p          = p,
      m          = m,
      k          = k,
      h          = h,
      target     = target,
      cov        = cov,
      cov_inv    = cov_inv,
      last_S     = S[m, ],
      locale     = locale
    )
  )
}

# Internal: Crosier (1988) ARL_0 ~ 200 lookup, k = 0.5 --------------------

#' @keywords internal
#' @noRd
mcusum_h_lookup <- function(k, p) {
  # Crosier (1988), Table 1: ARL_0 ~ 200 for k = 0.5
  if (!isTRUE(all.equal(k, 0.5))) return(NA_real_)
  tbl <- c("2"  =  5.50,
           "3"  =  6.40,
           "4"  =  7.18,
           "5"  =  7.85,
           "6"  =  8.46,
           "7"  =  9.01,
           "8"  =  9.52,
           "9"  = 10.00,
           "10" = 10.43)
  pkey <- as.character(p)
  if (!pkey %in% names(tbl)) return(NA_real_)
  unname(tbl[pkey])
}
