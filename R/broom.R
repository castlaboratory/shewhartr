# broom methods -----------------------------------------------------------
#
# Three S3 methods that bring shewhart_chart objects into the broom
# ecosystem and let users compose them with the rest of the tidyverse:
#
#   tidy()     summary of control limits as a tibble
#   glance()   one-row tibble with overall diagnostics
#   augment()  per-observation tibble with .fitted / .upper / .lower / .flag

#' Tidy the control limits of a Shewhart chart
#'
#' Returns a tibble of the chart's control limits in tall format. Each
#' row corresponds to one line of one chart panel (CL / UCL / LCL).
#'
#' @param x A [shewhart_chart] object.
#' @param ... Currently unused.
#'
#' @return A tibble with at least columns `chart`, `line`, `value`.
#'   For regression charts, whose limits follow a fitted curve, the
#'   tibble is in long format with one row per phase, endpoint and
#'   line: columns `chart` (`"regression"`), `.phase`, `endpoint`
#'   (`"first"` / `"last"` observation of the phase), `line` (`"CL"`,
#'   `"UCL"`, `"LCL"`) and `value`.
#'
#' @examples
#' fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
#' broom::tidy(fit)
#'
#' @exportS3Method broom::tidy shewhart_chart
tidy.shewhart_chart <- function(x, ...) {
  assert_chart(x)
  lim <- x$limits
  if (identical(x$type, "regression") &&
      !all(c("chart", "line", "value") %in% names(lim))) {
    lim <- tidy_regression_limits(lim)
  }
  lim
}

#' Reshape the wide per-phase regression limits to chart/line/value
#'
#' @keywords internal
#' @noRd
tidy_regression_limits <- function(lim) {
  spec <- tibble::tibble(
    col      = c("cl_first", "ucl_first", "lcl_first",
                 "cl_last",  "ucl_last",  "lcl_last"),
    endpoint = rep(c("first", "last"), each = 3L),
    line     = rep(c("CL", "UCL", "LCL"), times = 2L)
  )
  spec <- spec[spec$col %in% names(lim), , drop = FALSE]
  rows <- lapply(seq_len(nrow(lim)), function(i) {
    tibble::tibble(
      chart    = "regression",
      .phase   = lim$.phase[i],
      endpoint = spec$endpoint,
      line     = spec$line,
      value    = vapply(spec$col, function(cl) as.numeric(lim[[cl]][i]),
                        numeric(1L), USE.NAMES = FALSE)
    )
  })
  dplyr::bind_rows(rows)
}

#' Glance at a Shewhart chart's overall diagnostics
#'
#' Returns a one-row tibble with overall chart-level diagnostics
#' suitable for filling a row in a comparison table.
#'
#' @param x A [shewhart_chart] object.
#' @param ... Currently unused.
#'
#' @return A one-row tibble with columns `type`, `n`, `phase`,
#'   `sigma_hat`, `sigma_method`, `n_violations`, `n_rules`,
#'   `pct_violations`. `n_violations` counts rule hits (one row per
#'   point and rule), while `pct_violations` is the share of points
#'   flagged by at least one rule, so it always lies in `[0, 1]`.
#'
#' @examples
#' fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
#' broom::glance(fit)
#'
#' @exportS3Method broom::glance shewhart_chart
glance.shewhart_chart <- function(x, ...) {
  assert_chart(x)
  tibble::tibble(
    type           = x$type,
    n              = x$n,
    phase          = x$phase,
    sigma_hat      = x$sigma_hat,
    sigma_method   = x$sigma_method,
    n_violations   = nrow(x$violations),
    n_rules        = length(x$rules),
    pct_violations = glance_pct_violations(x)
  )
}

#' Share of points flagged by at least one rule
#'
#' @keywords internal
#' @noRd
glance_pct_violations <- function(x) {
  if (x$n <= 0L) return(NA_real_)
  flag <- x$augmented[[".flag_any"]]
  if (is.null(flag)) {
    # Fallback for objects without a .flag_any column: distinct positions
    return(length(unique(x$violations$position)) / x$n)
  }
  mean(flag, na.rm = TRUE)
}

#' Augment new data with control-chart annotations
#'
#' Returns the per-observation augmented tibble, optionally re-aligned
#' against fresh data passed via `newdata` (Phase II monitoring). When
#' `newdata` is `NULL`, returns the in-sample augmented tibble.
#'
#' @param x A [shewhart_chart] object.
#' @param newdata Optional data frame with the same columns as the
#'   data used to fit `x`. If supplied, control limits are propagated
#'   to the new rows (Phase II monitoring) and rule violations are
#'   re-evaluated.
#' @param ... Currently unused.
#'
#' @return A tibble. When `newdata = NULL`, the chart's augmented
#'   tibble; otherwise the same shape but for `newdata`.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(y = rnorm(50))
#' fit <- shewhart_i_mr(df, value = y)
#' broom::augment(fit)
#'
#' @exportS3Method broom::augment shewhart_chart
augment.shewhart_chart <- function(x, newdata = NULL, ...) {
  assert_chart(x)
  if (is.null(newdata)) return(x$augmented)

  # Phase II augment: propagate limits and re-evaluate rules
  monitor(newdata, x)$augmented
}
