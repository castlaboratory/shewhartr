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
# Sigma within, per chart type (the same estimator the chart used):
#
#   i_mr / ewma / cusum  sigma_hat of the chart (MR-bar / d2(2) by
#                        default); sigma_hat is already per individual.
#   xbar_r / xbar_s      sigma_hat of the chart (R-bar / d2(n),
#                        S-bar / c4(n) or pooled SD). This is already
#                        the per-individual sigma -- it must NOT be
#                        rescaled by sqrt(n). Mean and overall sigma
#                        come from the individual measurements stored in
#                        `metadata$values`, never from the subgroup
#                        means (whose spread is sigma / sqrt(n)).
#
# Confidence intervals: closed forms exist (Kotz & Lovelace 1998), but
# we use a non-parametric bootstrap by default for robustness to
# non-normality. Each replicate re-estimates sigma within with the
# *same* estimator as the point estimate, so the Cp/Cpk interval is an
# interval for Cp/Cpk and not for Pp/Ppk:
#
#   subgroup charts   resample whole subgroups (with replacement) and
#                     recompute R-bar/d2, S-bar/c4 or the pooled SD;
#   individual charts resample consecutive pairs (x[i-1], x[i]) so each
#                     replicate carries its moving ranges with it, and
#                     recompute MR-bar/d2 (or median MR / 0.954);
#   numeric vector    one sigma (the SD) for both pairs, as before.

#' Process capability indices Cp, Cpk, Pp, Ppk
#'
#' Computes the four classical capability indices for a Shewhart chart
#' or a raw vector. Optionally returns bootstrap confidence intervals.
#'
#' For a `shewhart_chart` of type `i_mr`, `ewma`, `cusum`, `xbar_r`
#' or `xbar_s`, the within sigma stored on the chart object
#' (`sigma_hat`, already expressed per individual measurement) is used
#' for Cp/Cpk; the overall standard deviation of the individual
#' measurements is used for Pp/Ppk. For subgroup charts the individual
#' measurements are the ones the chart was built from (not the subgroup
#' means). For a numeric vector `data`, a single sigma is used for both
#' pairs (so Cp = Pp and Cpk = Ppk). Other chart types (attribute,
#' regression, multivariate) are not supported; pass the measurements
#' as a numeric vector instead.
#'
#' Bootstrap intervals re-estimate sigma within in every replicate
#' with the same estimator as the chart: whole subgroups are resampled
#' for Xbar-R / Xbar-S charts, and consecutive pairs of observations
#' (so that each replicate keeps its moving ranges) for individual
#' charts.
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
    est <- capability_estimator(data)
  } else {
    check_numeric(data, allow_na = TRUE)
    raw <- data[!is.na(data)]
    est <- list(
      raw      = raw,
      sigma_w  = stats::sd(raw),
      resample = function() {
        smp <- sample(raw, length(raw), replace = TRUE)
        list(raw = smp, sigma_w = stats::sd(smp))
      }
    )
  }

  raw          <- est$raw
  sigma_within <- est$sigma_w

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
      b    <- est$resample()
      idx  <- compute_idx(mean(b$raw), b$sigma_w, stats::sd(b$raw))
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

#' Point estimate and bootstrap resampler of sigma within for a chart
#'
#' Returns a list with `raw` (individual measurements), `sigma_w` (the
#' chart's within sigma) and `resample()`, a closure that draws one
#' bootstrap replicate and re-estimates sigma within with the chart's
#' own estimator.
#'
#' @keywords internal
#' @noRd
capability_estimator <- function(chart, call = rlang::caller_env()) {
  type <- chart$type

  if (type %in% c("xbar_r", "xbar_s")) {
    raw    <- chart$metadata$values
    groups <- chart$metadata$value_groups
    if (is.null(raw) || is.null(groups)) {
      cli::cli_abort(c(
        "This {.val {type}} chart does not carry its individual measurements.",
        "i" = "Rebuild it with the current version of {.pkg shewhartr}."
      ), call = call)
    }
    cons   <- chart$metadata$constants
    method <- chart$sigma_method
    split_vals <- unname(split(raw, factor(groups, levels = unique(groups))))

    within_subgroups <- function(sg) {
      switch(method,
        range     = mean(vapply(sg, function(z) diff(range(z)), numeric(1L))) /
                    cons$d2,
        sbar      = mean(vapply(sg, stats::sd, numeric(1L))) / cons$c4,
        pooled_sd = sqrt(sum(vapply(sg, function(z) sum((z - mean(z))^2),
                                    numeric(1L))) /
                         sum(lengths(sg) - 1L)),
        cli::cli_abort("Unknown sigma method {.val {method}}.", call = call)
      )
    }

    return(list(
      raw      = raw,
      sigma_w  = chart$sigma_hat,
      resample = function() {
        sg <- split_vals[sample.int(length(split_vals), replace = TRUE)]
        list(raw     = unlist(sg, use.names = FALSE),
             sigma_w = within_subgroups(sg))
      }
    ))
  }

  if (type %in% c("i_mr", "ewma", "cusum")) {
    v       <- chart$augmented$.value
    raw     <- v[!is.na(v)]
    method  <- chart$sigma_method
    sigma_w <- chart$sigma_hat
    # consecutive pairs (x[i-1], x[i]) with both values present
    i_pair <- which(!is.na(v) & !is.na(c(NA_real_, v[-length(v)])))
    mr     <- abs(v[i_pair] - v[i_pair - 1L])
    x_pair <- v[i_pair]

    within_pairs <- function(k) {
      switch(method,
        mr        = mean(mr[k]) / 1.128,
        median_mr = stats::median(mr[k]) / 0.954,
        biweight  = unname(biweight(x_pair[k] -
                                    stats::median(x_pair[k]))["scale"]),
        sd        = stats::sd(x_pair[k]),
        user      = sigma_w,
        cli::cli_abort("Unknown sigma method {.val {method}}.", call = call)
      )
    }

    return(list(
      raw      = raw,
      sigma_w  = sigma_w,
      resample = function() {
        k <- sample.int(length(i_pair), length(i_pair), replace = TRUE)
        list(raw = x_pair[k], sigma_w = within_pairs(k))
      }
    ))
  }

  cli::cli_abort(c(
    "Capability indices are not defined for {.val {type}} charts.",
    "i" = "Supported chart types: {.val {c('i_mr', 'ewma', 'cusum', 'xbar_r', 'xbar_s')}}.",
    "i" = "Pass the individual measurements as a numeric vector instead."
  ), call = call)
}
