# Runs tests --------------------------------------------------------------
#
# Implementation of the eight Nelson rules (Nelson 1984, 1985), plus a
# few classical Western Electric variants. Each rule is a pure
# function over (value, center, sigma) that returns a logical vector
# the same length as `value`, TRUE at the position the rule fires.
# `shewhart_runs()` orchestrates them.
#
# References:
#
#   Nelson, L. S. (1984). The Shewhart Control Chart -- Tests for
#     Special Causes. Journal of Quality Technology, 16(4), 237-239.
#     <doi:10.1080/00224065.1984.11978921>
#   Nelson, L. S. (1985). Interpreting Shewhart Xbar Control Charts.
#     Journal of Quality Technology, 17(2), 114-117.
#     <doi:10.1080/00224065.1985.11978941>
#   Western Electric Co. (1956). Statistical Quality Control Handbook.
#     AT&T Technologies.
#
# A note on false-alarm rates: under H0 (process in control with normal
# data), the marginal probability that any single rule fires at a given
# point implies an in-control ARL. Combining rules degrades ARL_0
# multiplicatively. shewhart_arl() simulates the joint behaviour for
# any chosen subset.
#
# Missing values: a window that contains an NA is *incomplete* and never
# fires (rules 3, 4, 7, 8 used to abort with "missing value where
# TRUE/FALSE needed"). Rules 5 and 6 ("k out of m") fire at the point
# that completes the pattern, which must itself lie beyond the zone
# (Nelson 1984; Minitab convention). This avoids flagging the same pair
# twice when a third, in-zone point enters the window, and lets a
# pattern that starts at positions 1-2 fire before a full window of
# m points is available.
#
# Exact (probability) limits: for p / c / u charts with
# `limits = "binomial"` or `"poisson"` the plotted limits are not
# center +/- 3 sigma. `apply_exact_limits_rule1()` re-derives Nelson 1
# against the actual `.lower` / `.upper` so that flags and plot agree.

# Individual rule implementations -----------------------------------------

#' @keywords internal
#' @noRd
rule_n1 <- function(value, center, sigma) {
  # Nelson 1: one point beyond +/- 3 sigma
  abs(value - center) > 3 * sigma
}

#' @keywords internal
#' @noRd
rule_n2 <- function(value, center, sigma, n_consec = 9L) {
  # Nelson 2: n_consec points in a row on the same side of the center line
  side <- sign(value - center)
  side[is.na(side)] <- 0
  out <- logical(length(value))
  for (i in seq_along(value)) {
    if (i < n_consec) next
    window <- side[(i - n_consec + 1L):i]
    if (all(window == 1) || all(window == -1)) out[i] <- TRUE
  }
  out
}

#' @keywords internal
#' @noRd
rule_n3 <- function(value, center, sigma, n_consec = 6L) {
  # Nelson 3: n_consec points in a row, all increasing or all decreasing
  d <- c(NA_real_, diff(value))
  out <- logical(length(value))
  for (i in seq_along(value)) {
    if (i < n_consec) next
    window <- d[(i - n_consec + 2L):i]
    if (anyNA(window)) next
    if (all(window > 0) || all(window < 0)) out[i] <- TRUE
  }
  out
}

#' @keywords internal
#' @noRd
rule_n4 <- function(value, center, sigma, n_consec = 14L) {
  # Nelson 4: n_consec points in a row, alternating up and down
  d <- c(NA_real_, diff(value))
  s <- sign(d)
  out <- logical(length(value))
  for (i in seq_along(value)) {
    if (i < n_consec) next
    window <- s[(i - n_consec + 2L):i]
    if (anyNA(window)) next
    # alternating means consecutive products are -1
    if (length(window) >= 2L &&
        all(window[-length(window)] * window[-1L] == -1)) {
      out[i] <- TRUE
    }
  }
  out
}

#' @keywords internal
#' @noRd
rule_n5 <- function(value, center, sigma) {
  # Nelson 5: 2 out of 3 consecutive points beyond +2 sigma (or -2 sigma),
  # flagged at the point that completes the pattern (itself beyond).
  rule_k_of_m(value - center, 2 * sigma, k = 2L, m = 3L)
}

#' @keywords internal
#' @noRd
rule_n6 <- function(value, center, sigma) {
  # Nelson 6: 4 out of 5 consecutive points beyond +1 sigma (or -1 sigma),
  # flagged at the point that completes the pattern (itself beyond).
  rule_k_of_m(value - center, sigma, k = 4L, m = 5L)
}

#' "k out of m beyond a threshold, same side" helper for Nelson 5 / 6
#'
#' Fires at position i when point i lies beyond the threshold and at
#' least k of the (up to) m points ending at i lie beyond it on the
#' same side. Windows shorter than m at the start of the series are
#' allowed, so a pattern at positions 1..k fires at k.
#'
#' @keywords internal
#' @noRd
rule_k_of_m <- function(dev, threshold, k, m) {
  beyond_pos <- dev >  threshold
  beyond_neg <- dev < -threshold
  beyond_pos[is.na(beyond_pos)] <- FALSE
  beyond_neg[is.na(beyond_neg)] <- FALSE
  out <- logical(length(dev))
  for (i in seq_along(dev)) {
    if (i < k) next
    lo <- max(1L, i - m + 1L)
    if ((beyond_pos[i] && sum(beyond_pos[lo:i]) >= k) ||
        (beyond_neg[i] && sum(beyond_neg[lo:i]) >= k)) {
      out[i] <- TRUE
    }
  }
  out
}

#' @keywords internal
#' @noRd
rule_n7 <- function(value, center, sigma, n_consec = 15L) {
  # Nelson 7: n_consec points in a row within +/- 1 sigma
  within <- abs(value - center) < sigma
  out <- logical(length(value))
  for (i in seq_along(value)) {
    if (i < n_consec) next
    window <- within[(i - n_consec + 1L):i]
    if (isTRUE(all(window))) out[i] <- TRUE
  }
  out
}

#' @keywords internal
#' @noRd
rule_n8 <- function(value, center, sigma, n_consec = 8L) {
  # Nelson 8: n_consec points in a row outside +/- 1 sigma (either side)
  outside <- abs(value - center) > sigma
  out <- logical(length(value))
  for (i in seq_along(value)) {
    if (i < n_consec) next
    window <- outside[(i - n_consec + 1L):i]
    if (isTRUE(all(window))) out[i] <- TRUE
  }
  out
}

#' @keywords internal
#' @noRd
rule_we_seven <- function(value, center, sigma, n_consec = 7L) {
  # Western Electric (legacy): 7 points in a row on same side of center
  rule_n2(value, center, sigma, n_consec = n_consec)
}

# Registry of rules -------------------------------------------------------

.shewhart_rule_registry <- list(
  nelson_1_beyond_3s     = list(fn = rule_n1, label = "1 point beyond 3 sigma"),
  nelson_2_nine_same     = list(fn = rule_n2, label = "9 points in a row on same side of center"),
  nelson_3_six_trend     = list(fn = rule_n3, label = "6 points in a row, all increasing or decreasing"),
  nelson_4_alternating   = list(fn = rule_n4, label = "14 points in a row, alternating"),
  nelson_5_two_of_three  = list(fn = rule_n5, label = "2 out of 3 consecutive points beyond 2 sigma (same side)"),
  nelson_6_four_of_five  = list(fn = rule_n6, label = "4 out of 5 consecutive points beyond 1 sigma (same side)"),
  nelson_7_stratification = list(fn = rule_n7, label = "15 points in a row within 1 sigma"),
  nelson_8_mixture       = list(fn = rule_n8, label = "8 points in a row outside 1 sigma (either side)"),
  we_seven_same          = list(fn = rule_we_seven, label = "7 points in a row on same side of center (Western Electric)")
)

#' List available runs rules
#'
#' @return A tibble with columns `rule` (the key) and `description`.
#'
#' @examples
#' shewhart_rules_available()
#' @export
shewhart_rules_available <- function() {
  tibble::tibble(
    rule        = names(.shewhart_rule_registry),
    description = vapply(.shewhart_rule_registry, `[[`, "label",
                         FUN.VALUE = character(1L))
  )
}

#' Apply runs tests to a chart object or to raw vectors
#'
#' Implements the eight rules of Nelson (1984, 1985) plus a Western
#' Electric "7 in a row" variant for backward compatibility. Returns a
#' tidy tibble of rule violations.
#'
#' @param x Either a `shewhart_chart` object (most common) or a numeric
#'   vector of values. If a vector is supplied, `center` and `sigma`
#'   must also be provided.
#' @param rules Character vector of rule keys to apply. Use
#'   [shewhart_rules_available()] to see all options. Default applies
#'   Nelson 1 (beyond 3 sigma) and Nelson 2 (9 same side), the most
#'   commonly recommended pair.
#' @param center,sigma Numeric scalars or vectors. Required only when
#'   `x` is a numeric vector. Ignored otherwise.
#'
#' @return A tibble with columns `position` (integer, the index where
#'   the rule fired), `rule` (character key), `description` (character
#'   label), `value` (the value at that position) and `severity`
#'   (currently always `"out_of_control"`; reserved for future
#'   warning-level rules).
#'
#' @references
#' Nelson, L. S. (1984). The Shewhart Control Chart -- Tests for
#' Special Causes. *Journal of Quality Technology*, 16(4), 237-239.
#' \doi{10.1080/00224065.1984.11978921}
#'
#' Nelson, L. S. (1985). Interpreting Shewhart Xbar Control Charts.
#' *Journal of Quality Technology*, 17(2), 114-117.
#' \doi{10.1080/00224065.1985.11978941}
#'
#' Western Electric Co. (1956). *Statistical Quality Control Handbook*.
#'
#' @examples
#' set.seed(1)
#' x <- c(rnorm(20), 5, rnorm(20))    # one outlier at position 21
#' shewhart_runs(x, center = 0, sigma = 1)
#'
#' @export
shewhart_runs <- function(x,
                          rules = c("nelson_1_beyond_3s",
                                    "nelson_2_nine_same"),
                          center = NULL,
                          sigma  = NULL) {

  # Dispatch on input type --------------------------------------------------
  if (inherits(x, "shewhart_chart")) {
    aug    <- x$augmented
    value  <- aug[[".fitted_value"]] %||% aug[[".value"]]
    cen    <- aug[[".center"]]
    sig    <- aug[[".sigma"]]
  } else {
    check_numeric(x)
    if (is.null(center) || is.null(sigma)) {
      cli::cli_abort(c(
        "When {.arg x} is a numeric vector, {.arg center} and {.arg sigma} must be supplied.",
        "i" = "If you have a chart object from {.pkg shewhartr}, pass it directly."
      ))
    }
    value <- x
    cen   <- if (length(center) == 1L) rep(center, length(x)) else center
    sig   <- if (length(sigma)  == 1L) rep(sigma,  length(x)) else sigma
  }

  unknown <- setdiff(rules, names(.shewhart_rule_registry))
  if (length(unknown) > 0L) {
    cli::cli_abort(c(
      "Unknown rule{?s}: {.val {unknown}}.",
      "i" = "See {.fn shewhart_rules_available} for the registry."
    ))
  }

  # Apply each rule ---------------------------------------------------------
  results <- purrr::map_dfr(rules, function(rule_key) {
    spec <- .shewhart_rule_registry[[rule_key]]
    fired <- spec$fn(value, cen, sig)
    fired[is.na(fired)] <- FALSE
    if (!any(fired)) return(tibble::tibble(
      position    = integer(0),
      rule        = character(0),
      description = character(0),
      value       = numeric(0),
      severity    = character(0)
    ))
    tibble::tibble(
      position    = which(fired),
      rule        = rule_key,
      description = spec$label,
      value       = value[fired],
      severity    = "out_of_control"
    )
  })

  results
}

#' Append a `.flag_<rule>` and `.flag_any` column for every rule
#'
#' Used internally by chart constructors and `augment()` methods to
#' annotate each row with which rule(s) fired.
#'
#' @keywords internal
#' @noRd
flag_rules <- function(value, center, sigma, rules) {
  out <- list()
  for (rule_key in rules) {
    spec <- .shewhart_rule_registry[[rule_key]]
    fired <- spec$fn(value, center, sigma)
    fired[is.na(fired)] <- FALSE
    out[[paste0(".flag_", rule_key)]] <- fired
  }
  out[[".flag_any"]] <- Reduce(`|`, out, init = logical(length(value)))
  tibble::as_tibble(out)
}

#' Re-derive Nelson 1 against exact (probability) limits
#'
#' For attribute charts with exact binomial / Poisson limits, the
#' plotted `.lower` / `.upper` are quantiles, not `center +/- 3 sigma`.
#' This helper replaces the `.flag_nelson_1_beyond_3s` column and the
#' matching rows of the violations table so that a point is flagged iff
#' it lies strictly outside the plotted limits. The other rules keep
#' their sigma-zone definitions. A no-op when Nelson 1 is not among
#' `rules`.
#'
#' @param flags Tibble returned by `flag_rules()`.
#' @param violations Tibble returned by `shewhart_runs()`.
#' @param value,lower,upper Numeric vectors (recycled) with the
#'   statistic and its exact limits.
#' @param rules Character vector of rule keys in application order.
#'
#' @return A list with the updated `flags` and `violations`.
#'
#' @keywords internal
#' @noRd
apply_exact_limits_rule1 <- function(flags, violations, value, lower, upper,
                                     rules) {
  key <- "nelson_1_beyond_3s"
  if (!key %in% rules) {
    return(list(flags = flags, violations = violations))
  }
  n <- length(value)
  lower <- rep_len(lower, n)
  upper <- rep_len(upper, n)
  fired <- (value > upper) | (value < lower)
  fired[is.na(fired)] <- FALSE

  flag_col <- paste0(".flag_", key)
  flags[[flag_col]] <- fired
  rule_cols <- paste0(".flag_", rules)
  flags[[".flag_any"]] <- Reduce(`|`, as.list(flags[rule_cols]),
                                 init = logical(n))

  new_rows <- tibble::tibble(
    position    = which(fired),
    rule        = rep(key, sum(fired)),
    description = rep(.shewhart_rule_registry[[key]]$label, sum(fired)),
    value       = value[fired],
    severity    = rep("out_of_control", sum(fired))
  )
  violations <- dplyr::bind_rows(
    violations[violations$rule != key, , drop = FALSE],
    new_rows
  )
  ord <- order(match(violations$rule, rules), violations$position)
  violations <- violations[ord, , drop = FALSE]

  list(flags = flags, violations = violations)
}
