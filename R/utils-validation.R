# Validation helpers ------------------------------------------------------
#
# All user-facing functions delegate input validation to these helpers.
# They follow a consistent pattern:
#   - rlang::caller_arg() to capture the original argument name
#   - rlang::caller_env() to throw the error from the caller's frame
#   - cli::cli_abort() with informative, multi-line messages
#
# This keeps validation noise out of the chart constructors and ensures
# error messages are uniform in style across the package.

#' @keywords internal
#' @noRd
check_data <- function(data,
                       arg = rlang::caller_arg(data),
                       call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c("{.arg {arg}} must be a data frame.",
        "x" = "Got {.obj_type_friendly {data}}."),
      call = call
    )
  }
  if (nrow(data) == 0L) {
    cli::cli_abort(
      "{.arg {arg}} has zero rows.",
      call = call
    )
  }
  invisible(data)
}

#' Verify a column referenced by tidy-eval exists
#'
#' @param col_name Character. Already extracted name (use `rlang::as_name(enquo(x))`).
#' @keywords internal
#' @noRd
check_column <- function(data, col_name, arg = "column",
                         call = rlang::caller_env(),
                         allow_null = FALSE) {
  if (allow_null && is.null(col_name)) return(invisible())
  if (!col_name %in% names(data)) {
    available <- names(data)
    if (length(available) > 10L) {
      shown <- c(available[1:10], "...")
    } else {
      shown <- available
    }
    cli::cli_abort(
      c("Column {.var {col_name}} (referenced by {.arg {arg}}) was not found.",
        "i" = "Available columns: {.var {shown}}."),
      call = call
    )
  }
  invisible(col_name)
}

#' @keywords internal
#' @noRd
check_numeric <- function(x, arg = rlang::caller_arg(x),
                          call = rlang::caller_env(),
                          allow_na = TRUE) {
  if (!is.numeric(x)) {
    cli::cli_abort(
      c("{.arg {arg}} must be numeric.",
        "x" = "Got {.obj_type_friendly {x}}."),
      call = call
    )
  }
  if (!allow_na && any(is.na(x))) {
    n_na <- sum(is.na(x))
    cli::cli_abort(
      "{.arg {arg}} contains {.val {n_na}} missing value{?s}, which {?is/are} not allowed here.",
      call = call
    )
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_count <- function(x, arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  check_numeric(x, arg = arg, call = call, allow_na = FALSE)
  if (any(x < 0)) {
    cli::cli_abort("{.arg {arg}} must be non-negative.", call = call)
  }
  if (any(x != round(x))) {
    cli::cli_abort("{.arg {arg}} must contain only integer counts.", call = call)
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_proportion <- function(x, arg = rlang::caller_arg(x),
                             call = rlang::caller_env()) {
  check_numeric(x, arg = arg, call = call, allow_na = FALSE)
  if (any(x < 0 | x > 1)) {
    cli::cli_abort("{.arg {arg}} must lie in [0, 1].", call = call)
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_scalar_int <- function(x, arg = rlang::caller_arg(x),
                             min = 1L, max = Inf,
                             call = rlang::caller_env()) {
  if (length(x) != 1L || !is.numeric(x) || is.na(x) || x != round(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single integer.",
      call = call
    )
  }
  if (x < min || x > max) {
    cli::cli_abort(
      "{.arg {arg}} = {.val {x}} is outside the allowed range [{.val {min}}, {.val {max}}].",
      call = call
    )
  }
  invisible(as.integer(x))
}

#' @keywords internal
#' @noRd
check_choice <- function(x, choices, arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (length(x) != 1L || !x %in% choices) {
    cli::cli_abort(
      c("{.arg {arg}} must be one of {.val {choices}}.",
        "x" = "Got {.val {x}}."),
      call = call
    )
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
check_subgroup_size <- function(n, arg = "subgroup size",
                                min = 2L, max_warn = 25L,
                                call = rlang::caller_env()) {
  if (n < min) {
    cli::cli_abort(
      c("Subgroup size {.val {n}} is below the minimum of {.val {min}}.",
        "i" = "For individual observations use {.fn shewhart_i_mr} instead."),
      call = call
    )
  }
  if (n > max_warn) {
    cli::cli_warn(
      c("Subgroup size {.val {n}} is unusually large.",
        "i" = "Classical constants assume n <= 25; consider {.fn shewhart_xbar_s} with {.code sigma_method = \"pooled_sd\"}.")
    )
  }
  invisible(as.integer(n))
}

#' Soft alert for verbose informational messages
#'
#' Respects the `shewhart.verbose` option and the function-level
#' `verbose` argument when present.
#'
#' @keywords internal
#' @noRd
inform_step <- function(message, ..., verbose = NULL) {
  v <- verbose %||% getOption("shewhart.verbose", FALSE)
  if (isTRUE(v)) cli::cli_alert_info(message, ...)
  invisible()
}

#' @keywords internal
#' @noRd
success_step <- function(message, ..., verbose = NULL) {
  v <- verbose %||% getOption("shewhart.verbose", FALSE)
  if (isTRUE(v)) cli::cli_alert_success(message, ...)
  invisible()
}
