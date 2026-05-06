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
#'
#' @examples
#' fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
#' broom::tidy(fit)
#'
#' @exportS3Method broom::tidy shewhart_chart
tidy.shewhart_chart <- function(x, ...) {
  assert_chart(x)
  x$limits
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
#'   `pct_violations`.
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
    pct_violations = if (x$n > 0L) nrow(x$violations) / x$n else NA_real_
  )
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
