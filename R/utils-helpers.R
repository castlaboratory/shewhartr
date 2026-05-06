# General-purpose helpers -------------------------------------------------

#' Rolling sum with a configurable window
#'
#' Slides over `x` summing the last `.window` elements (including the
#' current one). Treats `NA` as zero. Used internally by the runs tests.
#'
#' @param x Numeric vector.
#' @param .window Integer window size (>= 1). Default: 7.
#'
#' @return A numeric vector the same length as `x`.
#'
#' @examples
#' rolling_sum(c(1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1), .window = 7)
#'
#' @export
rolling_sum <- function(x, .window = 7L) {
  check_numeric(x)
  .window <- check_scalar_int(.window, min = 1L)
  slider::slide_dbl(
    .x        = x,
    .f        = ~ sum(.x, na.rm = TRUE),
    .before   = .window - 1L,
    .after    = 0L,
    .complete = FALSE
  )
}

#' Generate a qualitative HCL palette
#'
#' Internal palette used as a default when a number of phases or
#' subgroups need distinct colours. For most plots, ggplot2's default
#' palette is fine; this is provided for backward compatibility and
#' quick prototyping.
#'
#' @param n Integer (>= 1). Number of colours to generate.
#'
#' @return A character vector of `n` hex colour strings.
#'
#' @examples
#' color_hue(5)
#'
#' @export
color_hue <- function(n) {
  n <- check_scalar_int(n, min = 1L)
  hues <- seq(15, 375, length.out = n + 1L)
  grDevices::hcl(h = hues, l = 65, c = 100)[seq_len(n)]
}

# Internal pipe-friendly utilities ---------------------------------------

#' @keywords internal
#' @noRd
moving_range <- function(x) {
  c(NA_real_, abs(diff(x)))
}

#' @keywords internal
#' @noRd
mr_bar <- function(x, robust = FALSE) {
  mr <- moving_range(x)
  if (robust) stats::median(mr, na.rm = TRUE) else mean(mr, na.rm = TRUE)
}

#' Tukey biweight (M-estimator) for location and scale
#'
#' Robust alternative to mean/sd. Uses standard tuning constants
#' c = 4.685 for location and c = 9.0 for scale (Mosteller & Tukey,
#' 1977). Iterates to convergence.
#'
#' @keywords internal
#' @noRd
biweight <- function(x, c_loc = 4.685, c_scl = 9.0,
                     max_iter = 50, tol = 1e-7) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(c(location = NA_real_, scale = NA_real_))

  loc <- stats::median(x)
  scl <- stats::mad(x, constant = 1.4826)
  if (scl == 0) return(c(location = loc, scale = 0))

  for (i in seq_len(max_iter)) {
    u <- (x - loc) / (c_loc * scl)
    w <- ifelse(abs(u) < 1, (1 - u^2)^2, 0)
    loc_new <- sum(w * x) / sum(w)
    if (abs(loc_new - loc) < tol) {
      loc <- loc_new
      break
    }
    loc <- loc_new
  }

  # Biweight midvariance
  u <- (x - loc) / (c_scl * stats::mad(x, constant = 1.4826))
  good <- abs(u) < 1
  num <- sum((x[good] - loc)^2 * (1 - u[good]^2)^4)
  den <- sum((1 - u[good]^2) * (1 - 5 * u[good]^2))
  scl <- sqrt(length(x) * num) / abs(den)

  c(location = loc, scale = scl)
}

#' Detect whether a tidy-eval argument is NULL
#'
#' @keywords internal
#' @noRd
is_quo_null <- function(q) {
  rlang::quo_is_null(q) || identical(rlang::quo_get_expr(q), quote(NULL))
}
