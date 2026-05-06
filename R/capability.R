# Process capability ------------------------------------------------------
#
# Capability indices summarise how well a process meets its
# specifications. They presuppose that the process is in control;
# otherwise the indices are meaningless. Phase I should always come
# first.
#
# Cp = (USL - LSL) / (6 sigma_within)
# Cpk = min((USL - mu) / (3 sigma_within), (mu - LSL) / (3 sigma_within))
# Pp = (USL - LSL) / (6 sigma_overall)
# Ppk = min((USL - mu) / (3 sigma_overall), (mu - LSL) / (3 sigma_overall))
#
# The Cp/Cpk pair uses the within-subgroup sigma (typically R-bar/d2 or
# similar) and answers "how capable could the process be if special
# causes were removed?". The Pp/Ppk pair uses the overall sample
# standard deviation and answers "how capable is the process *as it
# runs*?". The two diverge when between-subgroup variation is large.
#
# Confidence intervals: closed forms exist (Kotz & Lovelace 1998), but
# we use a non-parametric bootstrap by default for robustness to
# non-normality.

#' Process capability indices Cp, Cpk, Pp, Ppk
#'
#' Computes the four classical capability indices for a Shewhart chart
#' or a raw vector. Optionally returns bootstrap confidence intervals.
#'
#' For a `shewhart_chart` of type `i_mr`, `xbar_r`, or `xbar_s`, the
#' within-subgroup sigma stored on the chart object is used for
#' Cp/Cpk; the overall standard deviation of the raw data is used for
#' Pp/Ppk. For a numeric vector `data`, a single sigma is used for
#' both pairs (so Cp = Pp and Cpk = Ppk).
#'
#' Capability indices are only meaningful when the process is in
#' statistical control (Phase I). The function emits a warning if the
#' supplied chart has any rule violations.
#'
#' @param data A [shewhart_chart] object or a numeric vector.
#' @param lsl,usl Numeric scalars. Lower and upper specification
#'   limits. At least one must be supplied.
#' @param target Numeric scalar. Optional process target. If missing,
#'   defaults to the midpoint of `(lsl, usl)`.
#' @param ci_level Numeric. Confidence level for bootstrap intervals.
#'   Default `0.95`. Set to `NA` to skip bootstrap.
#' @param n_boot Integer. Number of bootstrap replicates. Default 2000.
#' @param seed Optional integer for reproducibility.
#'
#' @return A list of class `shewhart_capability` with point estimates
#'   and (optionally) bootstrap CIs.
#'
#' @references
#' Kotz, S., & Lovelace, C. R. (1998). *Process Capability Indices in
#' Theory and Practice*. Arnold.
#'
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 8.
#'
#' Pearn, W. L., & Kotz, S. (2006). *Encyclopedia and Handbook of
#' Process Capability Indices*. World Scientific.
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' df <- data.frame(y = rnorm(100, mean = 50, sd = 0.8))
#' fit <- shewhart_i_mr(df, value = y)
#' cap <- shewhart_capability(fit, lsl = 47, usl = 53, target = 50)
#' print(cap)
#' }
#'
#' @export
shewhart_capability <- function(data, lsl = NA_real_, usl = NA_real_,
                                target = NA_real_,
                                ci_level = 0.95, n_boot = 2000L,
                                seed = NULL) {

  if (is.na(lsl) && is.na(usl)) {
    cli::cli_abort("At least one of {.arg lsl} or {.arg usl} must be supplied.")
  }

  if (is_shewhart_chart(data)) {
    if (nrow(data$violations) > 0L) {
      cli::cli_warn(c(
        "Computing capability for a chart with {.val {nrow(data$violations)}} violation{?s}.",
        "i" = "Capability indices are only meaningful when the process is in control."
      ))
    }
    raw         <- data$augmented$.value
    sigma_within <- data$sigma_hat
    if (data$type %in% c("xbar_r", "xbar_s")) {
      # For subgroup charts, sigma_hat is the standard error of xbar;
      # the per-individual sigma is sigma_hat * sqrt(n).
      n <- data$metadata$n %||% 1L
      sigma_within <- sigma_within * sqrt(n)
    }
  } else {
    check_numeric(data, allow_na = TRUE)
    raw          <- data[!is.na(data)]
    sigma_within <- stats::sd(raw)
  }

  if (is.na(target)) target <- mean(c(lsl, usl), na.rm = TRUE)
  mu_hat       <- mean(raw)
  sigma_total  <- stats::sd(raw)

  compute_idx <- function(mu, sw, st) {
    cp  <- if (!is.na(usl) && !is.na(lsl)) (usl - lsl) / (6 * sw) else NA_real_
    cpk <- min(
      if (!is.na(usl)) (usl - mu) / (3 * sw) else Inf,
      if (!is.na(lsl)) (mu - lsl) / (3 * sw) else Inf
    )
    pp  <- if (!is.na(usl) && !is.na(lsl)) (usl - lsl) / (6 * st) else NA_real_
    ppk <- min(
      if (!is.na(usl)) (usl - mu) / (3 * st) else Inf,
      if (!is.na(lsl)) (mu - lsl) / (3 * st) else Inf
    )
    list(Cp = cp, Cpk = cpk, Pp = pp, Ppk = ppk)
  }

  point <- compute_idx(mu_hat, sigma_within, sigma_total)

  ci <- NULL
  if (!is.na(ci_level)) {
    if (!is.null(seed)) set.seed(seed)
    boot_mat <- replicate(n_boot, {
      smp  <- sample(raw, length(raw), replace = TRUE)
      mu_b <- mean(smp); sw_b <- stats::sd(smp); st_b <- stats::sd(smp)
      idx  <- compute_idx(mu_b, sw_b, st_b)
      c(Cp = idx$Cp, Cpk = idx$Cpk, Pp = idx$Pp, Ppk = idx$Ppk)
    })
    alpha <- (1 - ci_level) / 2
    ci <- apply(boot_mat, 1L, stats::quantile,
                probs = c(alpha, 1 - alpha), na.rm = TRUE)
  }

  out <- list(
    Cp        = point$Cp,
    Cpk       = point$Cpk,
    Pp        = point$Pp,
    Ppk       = point$Ppk,
    mean      = mu_hat,
    sigma_w   = sigma_within,
    sigma_t   = sigma_total,
    lsl       = lsl,
    usl       = usl,
    target    = target,
    n         = length(raw),
    ci        = ci,
    ci_level  = ci_level
  )
  class(out) <- "shewhart_capability"
  out
}

#' @exportS3Method print shewhart_capability
print.shewhart_capability <- function(x, ...) {
  cli::cli_h1("Process capability")
  cli::cli_inform(c(
    "*" = "n = {.val {x$n}}, mean = {.val {round(x$mean, 4)}}",
    "*" = "Sigma within = {.val {round(x$sigma_w, 4)}}, sigma overall = {.val {round(x$sigma_t, 4)}}",
    "*" = "LSL = {.val {x$lsl}}, USL = {.val {x$usl}}, target = {.val {x$target}}"
  ))
  cli::cli_h2("Indices")
  ind <- tibble::tibble(
    index = c("Cp", "Cpk", "Pp", "Ppk"),
    value = c(x$Cp, x$Cpk, x$Pp, x$Ppk)
  )
  if (!is.null(x$ci)) {
    ind$lower <- x$ci[1L, ]
    ind$upper <- x$ci[2L, ]
  }
  print(ind, n = Inf)
  invisible(x)
}

#' @exportS3Method broom::tidy shewhart_capability
tidy.shewhart_capability <- function(x, ...) {
  out <- tibble::tibble(
    index    = c("Cp", "Cpk", "Pp", "Ppk"),
    estimate = c(x$Cp, x$Cpk, x$Pp, x$Ppk)
  )
  if (!is.null(x$ci)) {
    out$conf_low  <- x$ci[1L, ]
    out$conf_high <- x$ci[2L, ]
  }
  out
}
