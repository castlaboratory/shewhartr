# Transformations ---------------------------------------------------------

#' Log-log transformation
#'
#' Applies the stabilising transformation
#' \deqn{y = \log\!\bigl(\log\bigl(x/\alpha + 1\bigr) + 1\bigr).}
#' Useful for very right-skewed non-negative data, particularly count
#' processes with heavy tails. The +1 inside each log makes the
#' transformation well-defined at zero.
#'
#' @param x Numeric vector. Values must satisfy `x / alpha > -1`.
#' @param alpha Positive scaling parameter. Default: 1.
#'
#' @return A numeric vector of transformed values.
#'
#' @seealso [iloglog()] for the inverse, [shewhart_box_cox()] for a
#'   data-driven transformation choice.
#'
#' @examples
#' x <- c(0, 1, 5, 10, 100, 1000)
#' loglog(x)
#'
#' @export
loglog <- function(x, alpha = 1) {
  check_numeric(x)
  check_numeric(alpha)
  if (length(alpha) != 1L || alpha <= 0) {
    cli::cli_abort("{.arg alpha} must be a positive scalar.")
  }
  log(log(x / alpha + 1) + 1)
}

#' Inverse log-log transformation
#'
#' Inverts [loglog()]:
#' \deqn{x = \alpha \,[\exp(\exp(y) - 1) - 1].}
#'
#' @param x Numeric vector previously transformed via [loglog()].
#' @param alpha Same `alpha` used in [loglog()]. Default: 1.
#'
#' @return A numeric vector on the original scale.
#'
#' @examples
#' original <- c(0, 1, 5, 10, 100, 1000)
#' all.equal(original, iloglog(loglog(original)))
#'
#' @export
iloglog <- function(x, alpha = 1) {
  check_numeric(x)
  check_numeric(alpha)
  if (length(alpha) != 1L || alpha <= 0) {
    cli::cli_abort("{.arg alpha} must be a positive scalar.")
  }
  alpha * (exp(exp(x) - 1) - 1)
}

#' Apply / invert a Box-Cox power transformation
#'
#' The Box-Cox transformation (Box & Cox, 1964) is
#' \deqn{y(\lambda) = \begin{cases}
#'   (x^\lambda - 1) / \lambda & \lambda \neq 0 \\
#'   \log(x) & \lambda = 0.
#' \end{cases}}
#'
#' For `lambda = 0` this returns `log(x)`; for `lambda = 1` it returns
#' `x - 1` (no shape change). Use [shewhart_box_cox()] to estimate
#' `lambda` from the data via profile log-likelihood.
#'
#' @param x Numeric vector of strictly positive values.
#' @param lambda Numeric scalar. Power parameter.
#'
#' @return A numeric vector of transformed values.
#'
#' @references
#' Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
#' *Journal of the Royal Statistical Society, Series B*, 26(2), 211-252.
#' \doi{10.1111/j.2517-6161.1964.tb00553.x}
#'
#' @seealso [shewhart_box_cox()] to estimate lambda from data.
#'
#' @examples
#' box_cox(1:10, lambda = 0)      # equivalent to log(1:10)
#' box_cox(1:10, lambda = 0.5)
#'
#' @export
box_cox <- function(x, lambda) {
  check_numeric(x)
  if (any(x <= 0, na.rm = TRUE)) {
    cli::cli_abort(
      c("Box-Cox transformation requires strictly positive values.",
        "i" = "If your data contains zeros, consider {.fn loglog} or shifting the series.")
    )
  }
  if (length(lambda) != 1L || !is.finite(lambda)) {
    cli::cli_abort("{.arg lambda} must be a finite scalar.")
  }
  if (abs(lambda) < 1e-8) log(x) else (x^lambda - 1) / lambda
}

#' Inverse Box-Cox transformation
#'
#' @inheritParams box_cox
#'
#' @return A numeric vector on the original scale.
#' @export
inv_box_cox <- function(x, lambda) {
  check_numeric(x)
  if (length(lambda) != 1L || !is.finite(lambda)) {
    cli::cli_abort("{.arg lambda} must be a finite scalar.")
  }
  if (abs(lambda) < 1e-8) exp(x) else (lambda * x + 1)^(1 / lambda)
}
