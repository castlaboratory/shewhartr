# Shewhart constants ------------------------------------------------------
#
# Tabulated values for n = 2..25 follow Montgomery (2019), Appendix VI,
# "Factors for Constructing Variables Control Charts". For n > 25 we
# compute c4 from its closed form and derive the rest. References:
#
#   Montgomery, D. C. (2019). Introduction to Statistical Quality
#     Control, 8th ed. Wiley. Appendix VI.
#   ASTM E2587-16: Standard Practice for Use of Control Charts in
#     Statistical Process Control.
#
# Constants:
#   A2  : Xbar chart factor when sigma estimated from R-bar
#   A3  : Xbar chart factor when sigma estimated from S-bar
#   c4  : E[S]/sigma, where S is the sample standard deviation
#   d2  : E[R]/sigma, where R is the sample range
#   d3  : sd[R]/sigma
#   B3,B4 : control limits for the S chart (sigma estimated)
#   B5,B6 : control limits for the S chart (sigma known)
#   D3,D4 : control limits for the R chart

.shewhart_constants_table <- data.frame(
  n  = 2:25,
  A2 = c(1.880, 1.023, 0.729, 0.577, 0.483, 0.419, 0.373, 0.337, 0.308, 0.285,
         0.266, 0.249, 0.235, 0.223, 0.212, 0.203, 0.194, 0.187, 0.180, 0.173,
         0.167, 0.162, 0.157, 0.153),
  A3 = c(2.659, 1.954, 1.628, 1.427, 1.287, 1.182, 1.099, 1.032, 0.975, 0.927,
         0.886, 0.850, 0.817, 0.789, 0.763, 0.739, 0.718, 0.698, 0.680, 0.663,
         0.647, 0.633, 0.619, 0.606),
  c4 = c(0.7979, 0.8862, 0.9213, 0.9400, 0.9515, 0.9594, 0.9650, 0.9693, 0.9727,
         0.9754, 0.9776, 0.9794, 0.9810, 0.9823, 0.9835, 0.9845, 0.9854, 0.9862,
         0.9869, 0.9876, 0.9882, 0.9887, 0.9892, 0.9896),
  d2 = c(1.128, 1.693, 2.059, 2.326, 2.534, 2.704, 2.847, 2.970, 3.078, 3.173,
         3.258, 3.336, 3.407, 3.472, 3.532, 3.588, 3.640, 3.689, 3.735, 3.778,
         3.819, 3.858, 3.895, 3.931),
  d3 = c(0.853, 0.888, 0.880, 0.864, 0.848, 0.833, 0.820, 0.808, 0.797, 0.787,
         0.778, 0.770, 0.763, 0.756, 0.750, 0.744, 0.739, 0.734, 0.729, 0.724,
         0.720, 0.716, 0.712, 0.708),
  B3 = c(0.000, 0.000, 0.000, 0.000, 0.030, 0.118, 0.185, 0.239, 0.284, 0.321,
         0.354, 0.382, 0.406, 0.428, 0.448, 0.466, 0.482, 0.497, 0.510, 0.523,
         0.534, 0.545, 0.555, 0.565),
  B4 = c(3.267, 2.568, 2.266, 2.089, 1.970, 1.882, 1.815, 1.761, 1.716, 1.679,
         1.646, 1.618, 1.594, 1.572, 1.552, 1.534, 1.518, 1.503, 1.490, 1.477,
         1.466, 1.455, 1.445, 1.435),
  B5 = c(0.000, 0.000, 0.000, 0.000, 0.029, 0.113, 0.179, 0.232, 0.276, 0.313,
         0.346, 0.374, 0.399, 0.421, 0.440, 0.458, 0.475, 0.490, 0.504, 0.516,
         0.528, 0.539, 0.549, 0.559),
  B6 = c(2.606, 2.276, 2.088, 1.964, 1.874, 1.806, 1.751, 1.707, 1.669, 1.637,
         1.610, 1.585, 1.563, 1.544, 1.526, 1.511, 1.496, 1.483, 1.470, 1.459,
         1.448, 1.438, 1.429, 1.420),
  D3 = c(0.000, 0.000, 0.000, 0.000, 0.000, 0.076, 0.136, 0.184, 0.223, 0.256,
         0.283, 0.307, 0.328, 0.347, 0.363, 0.378, 0.391, 0.403, 0.415, 0.425,
         0.434, 0.443, 0.451, 0.459),
  D4 = c(3.267, 2.574, 2.282, 2.114, 2.004, 1.924, 1.864, 1.816, 1.777, 1.744,
         1.717, 1.693, 1.672, 1.653, 1.637, 1.622, 1.608, 1.597, 1.585, 1.575,
         1.566, 1.557, 1.548, 1.541)
)

#' Compute c4 from its closed-form expression
#'
#' For a sample of size `n` from a normal distribution with standard
#' deviation sigma, the bias-correcting constant c4 is defined by
#' \deqn{c_4(n) = \sqrt{\frac{2}{n - 1}} \cdot
#'   \frac{\Gamma(n/2)}{\Gamma((n - 1)/2)}}
#' so that \eqn{E[S] = c_4 \, \sigma}.
#'
#' @param n Integer sample size (>= 2).
#'
#' @return The value of c4(n).
#'
#' @references Montgomery (2019), Appendix VI.
#'
#' @keywords internal
#' @noRd
c4_exact <- function(n) {
  stopifnot(all(n >= 2))
  sqrt(2 / (n - 1)) * exp(lgamma(n / 2) - lgamma((n - 1) / 2))
}

#' Look up Shewhart control chart constants
#'
#' Returns the classical Shewhart constants (A2, A3, c4, d2, d3, B3-B6,
#' D3-D4) for a given subgroup size `n`. Tabulated values are used for
#' `n <= 25`; for larger samples, c4 is computed from its closed form
#' and the remaining constants are derived analytically when known
#' (otherwise NA is returned with a warning).
#'
#' @param n Integer scalar or vector. Subgroup size (>= 2).
#'
#' @return A data frame with columns `n`, `A2`, `A3`, `c4`, `d2`, `d3`,
#'   `B3`, `B4`, `B5`, `B6`, `D3`, `D4`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Appendix VI.
#'
#' @examples
#' shewhart_constants(5)
#' shewhart_constants(c(2, 5, 10, 25))
#'
#' @export
shewhart_constants <- function(n) {
  check_numeric(n)
  n <- as.integer(n)
  if (any(n < 2L)) {
    cli::cli_abort("{.arg n} must be at least 2.")
  }

  out <- vapply(n, function(ni) {
    if (ni <= 25L) {
      return(unlist(.shewhart_constants_table[.shewhart_constants_table$n == ni, ]))
    }
    # Asymptotic expressions (good for large n; coarse for B5/B6, D3/D4)
    c4_n <- c4_exact(ni)
    c(
      n  = ni,
      A2 = NA_real_,                         # not defined for n > 25 here
      A3 = 3 / (c4_n * sqrt(ni)),
      c4 = c4_n,
      d2 = NA_real_,
      d3 = NA_real_,
      B3 = max(0, 1 - 3 * sqrt(1 - c4_n^2) / c4_n),
      B4 = 1 + 3 * sqrt(1 - c4_n^2) / c4_n,
      B5 = max(0, c4_n - 3 * sqrt(1 - c4_n^2)),
      B6 = c4_n + 3 * sqrt(1 - c4_n^2),
      D3 = NA_real_,
      D4 = NA_real_
    )
  }, FUN.VALUE = numeric(12))

  out <- as.data.frame(t(out))
  rownames(out) <- NULL
  if (any(is.na(out$A2))) {
    cli::cli_warn(
      c("Some constants (A2, d2, d3, D3, D4) are not tabulated for n > 25.",
        "i" = "Use {.code sigma_method = \"pooled_sd\"} or {.fn shewhart_xbar_s} instead.")
    )
  }
  out
}
