# Base S3 class -----------------------------------------------------------
#
# All charts return an object inheriting from `shewhart_chart`. The
# specific subclass (e.g. `shewhart_i_mr`, `shewhart_xbar_r`,
# `shewhart_p`) drives method dispatch for plotting and broom methods.
#
# Anatomy of a shewhart_chart:
#
#   $type        chr   "i_mr", "xbar_r", "p", "regression", ...
#   $augmented   tbl   per-observation results: .value, .center, .sigma,
#                       .upper, .lower, .flag_*, .phase (if applicable)
#   $limits      tbl   summary table of CL/UCL/LCL per chart
#   $fits        list  fitted model objects (regression chart only)
#   $rules       chr   the rule set applied
#   $violations  tbl   shewhart_runs() output for these rules
#   $sigma_hat   num   estimate of process sigma
#   $sigma_method chr  how sigma was estimated
#   $phase       chr   "phase_1" or "phase_2"
#   $n           int   number of observations / subgroups
#   $call        call  the function call
#   $metadata    list  additional chart-specific information
#
# Subclasses may add their own slots without breaking shared methods.

#' Construct a `shewhart_chart` object
#'
#' Internal constructor used by every public chart function. Validates
#' the assembled pieces, attaches the appropriate S3 classes and
#' returns the finished object.
#'
#' @param type Character. Chart subtype key (e.g. `"i_mr"`).
#' @param augmented Tibble with per-observation results.
#' @param limits Tibble summarising control limits.
#' @param violations Tibble from [shewhart_runs()].
#' @param ... Additional named slots stored on the object.
#'
#' @keywords internal
#' @noRd
new_shewhart_chart <- function(type, augmented, limits,
                               violations = NULL,
                               fits = list(),
                               rules = character(),
                               sigma_hat = NA_real_,
                               sigma_method = NA_character_,
                               phase = "phase_1",
                               call = NULL,
                               metadata = list()) {
  stopifnot(is.character(type), length(type) == 1L)
  stopifnot(is.data.frame(augmented))
  stopifnot(is.data.frame(limits))

  obj <- list(
    type         = type,
    augmented    = tibble::as_tibble(augmented),
    limits       = tibble::as_tibble(limits),
    violations   = if (is.null(violations)) {
      tibble::tibble(position = integer(0), rule = character(0),
                     description = character(0), value = numeric(0),
                     severity = character(0))
    } else tibble::as_tibble(violations),
    fits         = fits,
    rules        = rules,
    sigma_hat    = sigma_hat,
    sigma_method = sigma_method,
    phase        = phase,
    n            = nrow(augmented),
    call         = call,
    metadata     = metadata
  )

  class(obj) <- c(paste0("shewhart_", type), "shewhart_chart")
  obj
}

#' Test whether an object is a Shewhart chart
#'
#' @param x An object.
#'
#' @return Logical scalar.
#'
#' @examples
#' fit <- shewhart_i_mr(data.frame(v = rnorm(30)), v)
#' is_shewhart_chart(fit)
#' @export
is_shewhart_chart <- function(x) {
  inherits(x, "shewhart_chart")
}

#' @keywords internal
#' @noRd
assert_chart <- function(x, arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (!is_shewhart_chart(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls shewhart_chart} object.",
      call = call
    )
  }
  invisible(x)
}
