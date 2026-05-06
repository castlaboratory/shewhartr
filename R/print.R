# print methods -----------------------------------------------------------

#' Print a Shewhart chart object
#'
#' Concise summary including chart type, sample size, sigma estimate
#' and any rule violations. For full per-row results, use
#' [augment()][broom::augment]; for a tabular limit summary, use
#' [tidy()][broom::tidy].
#'
#' @param x A [shewhart_chart] object.
#' @param ... Currently unused.
#'
#' @return Returns `x` invisibly (for chaining).
#'
#' @examples
#' set.seed(1)
#' fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
#' print(fit)
#'
#' @exportS3Method print shewhart_chart
print.shewhart_chart <- function(x, ...) {
  assert_chart(x)

  type_pretty <- switch(x$type,
    i_mr        = "I-MR (individuals & moving range)",
    xbar_r      = "Xbar-R",
    xbar_s      = "Xbar-S",
    p           = "p (proportion of nonconforming)",
    np          = "np (number of nonconforming)",
    c           = "c (number of nonconformities)",
    u           = "u (nonconformities per unit)",
    regression  = "regression-based",
    x$type
  )

  cli::cli_h1("Shewhart chart {.field {type_pretty}}")

  cli::cli_inform(c(
    "*" = "Observations / subgroups: {.val {x$n}}",
    "*" = "Phase: {.val {x$phase}}",
    "*" = "Sigma estimate ({.val {x$sigma_method}}): {.val {signif(x$sigma_hat, 4)}}"
  ))

  cli::cli_h2("Control limits")
  print(x$limits, n = Inf)

  n_viol <- nrow(x$violations)
  cli::cli_h2("Rule violations")
  if (n_viol == 0L) {
    cli::cli_alert_success("No violations across {.val {length(x$rules)}} rule{?s}: {.val {x$rules}}.")
  } else {
    cli::cli_alert_warning("{.val {n_viol}} violation{?s} across {.val {length(x$rules)}} rule{?s}.")
    by_rule <- table(x$violations$rule)
    for (r in names(by_rule)) {
      cli::cli_inform("  {.field {r}}: {.val {as.integer(by_rule[r])}} hit{?s}.")
    }
  }

  invisible(x)
}

#' Compact tibble-like summary
#'
#' @param object A [shewhart_chart] object.
#' @param ... Currently unused.
#'
#' @return A list with elements `limits` and `violations`.
#'
#' @examples
#' fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
#' summary(fit)
#'
#' @exportS3Method summary shewhart_chart
summary.shewhart_chart <- function(object, ...) {
  assert_chart(object)
  out <- list(
    type         = object$type,
    n            = object$n,
    phase        = object$phase,
    sigma_hat    = object$sigma_hat,
    sigma_method = object$sigma_method,
    rules        = object$rules,
    n_violations = nrow(object$violations),
    limits       = object$limits,
    violations   = object$violations
  )
  class(out) <- "summary.shewhart_chart"
  out
}

#' @exportS3Method print summary.shewhart_chart
print.summary.shewhart_chart <- function(x, ...) {
  cli::cli_h1("Summary of {.cls shewhart_chart}: {.field {x$type}}")
  cli::cli_inform(c(
    "*" = "n = {.val {x$n}}, phase = {.val {x$phase}}, sigma = {.val {signif(x$sigma_hat, 4)}}",
    "*" = "Rules: {.val {x$rules}}",
    "*" = "Violations: {.val {x$n_violations}}"
  ))
  cli::cli_h2("Limits")
  print(x$limits, n = Inf)
  if (x$n_violations > 0L) {
    cli::cli_h2("Violations")
    print(x$violations, n = Inf)
  }
  invisible(x)
}
