# Hotelling T-squared chart -----------------------------------------------
#
# Multivariate generalisation of the Shewhart chart for jointly
# monitoring p correlated quality characteristics. A Hotelling chart
# detects shifts in the correlation structure of the variables that
# univariate charts can miss entirely; conversely, when only one
# variable drifts, a multivariate chart can be slower than the
# matching univariate one.
#
# Two modes:
#
#   subgrouped  (n > 1)   data  contains m subgroups of size n each.
#                                T2_i = n * (xbar_i - xbarbar)' Sp^{-1}
#                                                        (xbar_i - xbarbar)
#
#   individual  (n = 1)   each row is its own observation; estimate
#                                covariance from the m row vectors.
#                                T2_i = (x_i - xbar)' S^{-1}
#                                                        (x_i - xbar)
#
# Limits (Tracy, Young & Mason 1992; Mason & Young 2002):
#
#   subgrouped Phase I    UCL = p(m-1)(n-1) / (mn - m - p + 1) *
#                                       F(alpha, p, mn - m - p + 1)
#   subgrouped Phase II   UCL = p(m+1)(n-1) / (mn - m - p + 1) *
#                                       F(alpha, p, mn - m - p + 1)
#   individual Phase I    UCL = (m-1)^2 / m *
#                                       Beta(alpha, p/2, (m-p-1)/2)
#   individual Phase II   UCL = p(m+1)(m-1) / (m * (m - p)) *
#                                       F(alpha, p, m - p)
#
# Per-variable contributions: a one-step decomposition (Mason, Tracy &
# Young 1995, JQT 27:99-108): for each variable j, drop it, recompute
# T2 in the (p-1)-dim subspace, and the difference is the marginal
# contribution of j. This is the simplest decomposition that works
# uniformly for individual and subgrouped data and is enough to point
# the analyst at the variable(s) responsible for an alarm.
#
# References:
#
#   Hotelling, H. (1947). Multivariate quality control. In: C. Eisenhart,
#     M. W. Hastay & W. A. Wallis (Eds.), Techniques of Statistical
#     Analysis. McGraw-Hill.
#   Tracy, N. D., Young, J. C., & Mason, R. L. (1992). Multivariate
#     control charts for individual observations. Journal of Quality
#     Technology, 24(2), 88-95. <doi:10.1080/00224065.1992.11979383>
#   Mason, R. L., Tracy, N. D., & Young, J. C. (1995). Decomposition
#     of T2 for multivariate control chart interpretation. Journal of
#     Quality Technology, 27(2), 99-108.
#     <doi:10.1080/00224065.1995.11979573>
#   Mason, R. L., & Young, J. C. (2002). Multivariate Statistical
#     Process Control with Industrial Applications. SIAM/ASA.
#   Montgomery, D. C. (2019). Introduction to Statistical Quality
#     Control (8th ed.). Wiley. Chapter 11.

#' Hotelling T-squared multivariate control chart
#'
#' Constructs a Hotelling `T²` chart for joint monitoring of `p`
#' correlated quality characteristics. Use this chart when the
#' variables genuinely co-vary — a classical example is a chemical
#' process where temperature, pressure and flow rate are mechanically
#' coupled, and a fault that breaks the coupling moves them off the
#' joint distribution but possibly stays inside each marginal limit.
#'
#' Both individual observations (`subgroup = NULL`) and rationally
#' subgrouped observations (`subgroup` supplied) are supported. The
#' chart selects the appropriate exact small-sample limits for the
#' selected `phase` (Phase I uses retrospective limits derived from
#' a Beta or F distribution; Phase II uses the slightly wider limits
#' that propagate the Phase I parameter uncertainty to a fresh
#' observation).
#'
#' @param data A data frame.
#' @param vars Tidy-select expression for the columns containing the
#'   variables to monitor jointly (`c(x1, x2, x3)`,
#'   `tidyselect::starts_with("temp")`, etc.). Must select at least 2
#'   columns.
#' @param subgroup Optional tidy-eval column for rational subgrouping.
#'   If supplied, all rows sharing a value of this column are treated
#'   as a single subgroup. If `NULL` (default), every row is its own
#'   observation (individual-observations chart).
#' @param index Optional tidy-eval column for the x-axis. If
#'   supplied, must vary across observations (or across subgroups, if
#'   `subgroup` is supplied).
#' @param phase One of `"phase_1"` (default; retrospective) or
#'   `"phase_2"` (prospective monitoring of new observations against
#'   parameters estimated from the same data).
#' @param alpha Type-I error rate per observation. Default `0.0027`,
#'   matching the conventional Shewhart `3-sigma` false-alarm rate.
#' @param locale One of `"en"`, `"pt"`, `"es"`, `"fr"`.
#' @param verbose Logical. Print progress messages?
#'
#' @return A [shewhart_chart] object of subclass `shewhart_hotelling`.
#'   The augmented tibble has columns `.t2` (the statistic), `.upper`
#'   (UCL — constant within a chart), `.flag_signal` and `.flag_any`,
#'   and one `.contrib_<var>` column per monitored variable giving
#'   that variable's marginal contribution to the alarm (Mason et al.
#'   1995). The `limits` slot contains the chart-level UCL; the
#'   `metadata` slot stores the variable names, subgroup column name,
#'   and the parameters `p`, `m`, `n`, `phase`, `alpha` that
#'   determined the limit.
#'
#' @references
#' Hotelling, H. (1947). Multivariate quality control. In:
#' *Techniques of Statistical Analysis*. McGraw-Hill.
#'
#' Tracy, N. D., Young, J. C., & Mason, R. L. (1992). Multivariate
#' control charts for individual observations. *Journal of Quality
#' Technology*, 24(2), 88-95. \doi{10.1080/00224065.1992.11979383}
#'
#' Mason, R. L., Tracy, N. D., & Young, J. C. (1995). Decomposition
#' of `T²` for multivariate control chart interpretation. *Journal of
#' Quality Technology*, 27(2), 99-108.
#' \doi{10.1080/00224065.1995.11979573}
#'
#' Mason, R. L., & Young, J. C. (2002). *Multivariate Statistical
#' Process Control with Industrial Applications*. SIAM/ASA.
#'
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 11.
#'
#' @examples
#' set.seed(1)
#' Sigma <- matrix(c(1, 0.7, 0.7, 1), 2, 2)
#' Z     <- MASS::mvrnorm(60, c(0, 0), Sigma)
#' df    <- tibble::tibble(t = 1:60, x1 = Z[, 1], x2 = Z[, 2])
#' fit   <- shewhart_hotelling(df, vars = c(x1, x2), index = t)
#' print(fit)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
#' @export
shewhart_hotelling <- function(data, vars, subgroup = NULL, index = NULL,
                               phase = c("phase_1", "phase_2"),
                               alpha = 0.0027,
                               locale = getOption("shewhart.locale", "en"),
                               verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  phase <- rlang::arg_match(phase)
  if (!is.numeric(alpha) || length(alpha) != 1L ||
      alpha <= 0 || alpha >= 1) {
    cli::cli_abort("{.arg alpha} must be a single number in (0, 1).")
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

  sub_q <- rlang::enquo(subgroup)
  has_subgroup <- !is_quo_null(sub_q)
  if (has_subgroup) {
    sub_name <- rlang::as_name(sub_q)
    check_column(data, sub_name, arg = "subgroup")
    sub_v    <- dplyr::pull(data, !!sub_q)
  } else {
    sub_name <- NULL
    sub_v    <- NULL
  }

  idx_q <- rlang::enquo(index)
  if (!is_quo_null(idx_q)) {
    idx_name <- rlang::as_name(idx_q)
    check_column(data, idx_name, arg = "index")
  } else {
    idx_name <- "index"
  }

  inform_step("Hotelling T-squared, {.val {p}}-variate, phase {.val {phase}}.",
              verbose = verbose)

  if (has_subgroup) {
    res <- t2_subgrouped(X, sub_v, p, alpha, phase)
    idx <- if (!is_quo_null(idx_q)) {
      # If idx supplied, take the first index per subgroup
      vapply(split(data[[idx_name]], sub_v),
             function(z) z[1L], data[[idx_name]][1L])
    } else {
      seq_len(res$m)
    }
    n  <- res$n
    m  <- res$m
  } else {
    res <- t2_individual(X, p, alpha, phase)
    idx <- if (!is_quo_null(idx_q)) {
      dplyr::pull(data, !!idx_q)
    } else {
      seq_len(nrow(X))
    }
    n  <- 1L
    m  <- res$m
  }

  flag <- res$t2 > res$ucl
  augmented <- tibble::tibble(
    !!idx_name := idx,
    .obs        = seq_along(res$t2),
    .t2         = res$t2,
    .center     = NA_real_,
    .upper      = res$ucl,
    .lower      = 0,
    .flag_signal = flag,
    .flag_any    = flag
  )
  for (j in seq_along(vars_names)) {
    augmented[[paste0(".contrib_", vars_names[j])]] <- res$contrib[, j]
  }

  limits <- tibble::tibble(
    chart = "T2",
    line  = "UCL",
    value = res$ucl
  )

  pos_hits <- which(flag)
  violations <- if (length(pos_hits) == 0L) {
    tibble::tibble(position = integer(0), rule = character(0),
                   description = character(0), value = numeric(0),
                   severity = character(0))
  } else {
    tibble::tibble(
      position    = pos_hits,
      rule        = "hotelling_ucl",
      description = sprintf("T2 exceeds UCL = %.3f", res$ucl),
      value       = res$t2[pos_hits],
      severity    = "alarm"
    )
  }

  new_shewhart_chart(
    type         = "hotelling",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = "hotelling_ucl",
    sigma_hat    = NA_real_,
    sigma_method = "hotelling",
    phase        = phase,
    call         = call,
    metadata     = list(
      vars     = vars_names,
      subgroup = sub_name,
      index_name = idx_name,
      p        = p,
      m        = m,
      n        = n,
      alpha    = alpha,
      mean_vec = res$mean_vec,
      cov_inv  = res$cov_inv,
      locale   = locale
    )
  )
}

# Internal: T2 for individuals --------------------------------------------

#' @keywords internal
#' @noRd
t2_individual <- function(X, p, alpha, phase) {
  m <- nrow(X)
  if (m <= p + 1L) {
    cli::cli_abort(c(
      "Need at least {.val {p + 2L}} rows for {.val {p}} variables.",
      "i" = "Got {.val {m}}."
    ))
  }
  xbar <- colMeans(X)
  S    <- stats::cov(X)
  Sinv <- tryCatch(solve(S), error = function(e) NULL)
  if (is.null(Sinv)) {
    cli::cli_abort(c(
      "Sample covariance is singular; cannot invert.",
      "i" = "Check for collinear or duplicated columns in {.arg vars}."
    ))
  }

  centered <- sweep(X, 2L, xbar, "-")
  t2 <- rowSums((centered %*% Sinv) * centered)

  ucl <- ucl_individual(p, m, alpha, phase)

  # Marginal contributions: T2 - T2_(-j)
  contrib <- matrix(0, nrow = m, ncol = p)
  for (j in seq_len(p)) {
    Xj    <- X[, -j, drop = FALSE]
    xbarj <- colMeans(Xj)
    Sj    <- stats::cov(Xj)
    Sjinv <- tryCatch(solve(Sj), error = function(e) NULL)
    if (is.null(Sjinv)) next
    cent_j <- sweep(Xj, 2L, xbarj, "-")
    t2_j   <- rowSums((cent_j %*% Sjinv) * cent_j)
    contrib[, j] <- pmax(0, t2 - t2_j)
  }

  list(t2 = t2, ucl = ucl, m = m, contrib = contrib,
       mean_vec = xbar, cov_inv = Sinv)
}

# Internal: T2 for subgrouped data ----------------------------------------

#' @keywords internal
#' @noRd
t2_subgrouped <- function(X, sub_v, p, alpha, phase) {
  groups <- split(seq_len(nrow(X)), sub_v)
  ns     <- vapply(groups, length, integer(1L))
  if (length(unique(ns)) > 1L) {
    cli::cli_abort(c(
      "All subgroups must have the same size for a Hotelling chart.",
      "i" = "Got sizes: {.val {unique(ns)}}."
    ))
  }
  n <- unname(ns[1L])
  m <- length(groups)
  if (n < 2L) {
    cli::cli_abort(c(
      "Subgroup size must be >= 2; got {.val {n}}.",
      "i" = "Drop {.arg subgroup} to use the individual-observations chart."
    ))
  }
  if (m * (n - 1L) <= p) {
    cli::cli_abort(c(
      "Need m*(n - 1) > p for a non-singular pooled covariance.",
      "i" = "Got m = {.val {m}}, n = {.val {n}}, p = {.val {p}}."
    ))
  }

  xbar_g <- do.call(rbind,
                    lapply(groups,
                           function(idx) colMeans(X[idx, , drop = FALSE])))
  xbarbar <- colMeans(xbar_g)

  # Pooled within-subgroup covariance
  S_list <- lapply(groups, function(idx) stats::cov(X[idx, , drop = FALSE]))
  Sp     <- Reduce("+", S_list) / m
  Sp_inv <- tryCatch(solve(Sp), error = function(e) NULL)
  if (is.null(Sp_inv)) {
    cli::cli_abort("Pooled covariance is singular; check for collinearity.")
  }

  centered <- sweep(xbar_g, 2L, xbarbar, "-")
  t2 <- n * rowSums((centered %*% Sp_inv) * centered)

  ucl <- ucl_subgrouped(p, m, n, alpha, phase)

  contrib <- matrix(0, nrow = m, ncol = p)
  for (j in seq_len(p)) {
    Xj      <- X[, -j, drop = FALSE]
    xbar_gj <- do.call(rbind,
                       lapply(groups,
                              function(idx) colMeans(Xj[idx, , drop = FALSE])))
    xbarbar_j <- colMeans(xbar_gj)
    Sj_list <- lapply(groups,
                      function(idx) stats::cov(Xj[idx, , drop = FALSE]))
    Spj     <- Reduce("+", Sj_list) / m
    Spj_inv <- tryCatch(solve(Spj), error = function(e) NULL)
    if (is.null(Spj_inv)) next
    cent_j <- sweep(xbar_gj, 2L, xbarbar_j, "-")
    t2_j   <- n * rowSums((cent_j %*% Spj_inv) * cent_j)
    contrib[, j] <- pmax(0, t2 - t2_j)
  }

  list(t2 = t2, ucl = ucl, m = m, n = n, contrib = contrib,
       mean_vec = xbarbar, cov_inv = Sp_inv)
}

# Internal: UCL formulas --------------------------------------------------

#' @keywords internal
#' @noRd
ucl_individual <- function(p, m, alpha, phase) {
  if (phase == "phase_1") {
    # Beta-based exact limit (Tracy, Young & Mason 1992)
    if (m <= p + 1L) {
      cli::cli_abort("Need m > p + 1 for the Beta-distribution limit.")
    }
    bq <- stats::qbeta(1 - alpha, shape1 = p / 2,
                       shape2 = (m - p - 1) / 2)
    ((m - 1)^2 / m) * bq
  } else {
    # F-based prediction limit
    if (m <= p) {
      cli::cli_abort("Need m > p for the Phase II limit.")
    }
    fq <- stats::qf(1 - alpha, df1 = p, df2 = m - p)
    p * (m + 1) * (m - 1) / (m * (m - p)) * fq
  }
}

#' @keywords internal
#' @noRd
ucl_subgrouped <- function(p, m, n, alpha, phase) {
  df2 <- m * n - m - p + 1L
  if (df2 <= 0L) {
    cli::cli_abort("Need m*(n-1) > p - 1 for a valid F-based limit.")
  }
  fq <- stats::qf(1 - alpha, df1 = p, df2 = df2)
  if (phase == "phase_1") {
    p * (m - 1) * (n - 1) / df2 * fq
  } else {
    p * (m + 1) * (n - 1) / df2 * fq
  }
}
