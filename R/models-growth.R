# Growth curves -----------------------------------------------------------
#
# Growth curves are a natural ingredient for regression-based control
# charts when the underlying process exhibits a sigmoidal trend (e.g.
# bacterial growth, drug dissolution, market saturation, epidemic
# trajectory). The Gompertz curve is asymmetric (flatter at the upper
# asymptote than the logistic) and was originally proposed by
# Gompertz (1825) for human mortality.

#' Gompertz growth function
#'
#' Computes the value of the Gompertz curve parameterised in terms of
#' starting value, asymptote, growth rate and lag:
#' \deqn{G(x) = y_0 + (y_{\max} - y_0)\,
#'   \exp\!\left[-\exp\!\left(\frac{k(\mathrm{lag} - x)}{y_{\max} - y_0}
#'   + 1\right)\right].}
#'
#' This parameterisation, often called the "Zwietering Gompertz" form
#' after Zwietering et al. (1990), gives directly interpretable
#' parameters: `y0` is the lower asymptote, `ymax` the upper
#' asymptote, `k` the maximum specific growth rate, and `lag` the lag
#' time before exponential growth.
#'
#' @param x Numeric vector. The independent variable (e.g. time).
#' @param y0 Lower asymptote.
#' @param ymax Upper asymptote.
#' @param k Maximum specific growth rate.
#' @param lag Lag time.
#'
#' @return A numeric vector the same length as `x`.
#'
#' @references
#' Gompertz, B. (1825). On the Nature of the Function Expressive of the
#' Law of Human Mortality. *Philosophical Transactions of the Royal
#' Society of London*, 115, 513-583.
#'
#' Zwietering, M. H., Jongenburger, I., Rombouts, F. M., & van 't Riet,
#' K. (1990). Modeling of the Bacterial Growth Curve. *Applied and
#' Environmental Microbiology*, 56(6), 1875-1881.
#' \doi{10.1128/aem.56.6.1875-1881.1990}
#'
#' @seealso [SSgompertzDummy()] for an `nls`-friendly self-starting
#'   variant that allows a covariate shift.
#'
#' @examples
#' x <- seq(0, 30, by = 0.5)
#' y <- Gompertz(x, y0 = 0, ymax = 100, k = 5, lag = 5)
#' plot(x, y, type = "l", main = "Gompertz growth curve")
#'
#' @export
Gompertz <- function(x, y0, ymax, k, lag) {
  check_numeric(x); check_numeric(y0); check_numeric(ymax)
  check_numeric(k); check_numeric(lag)
  if (any(ymax <= y0)) cli::cli_abort("{.arg ymax} must exceed {.arg y0}.")
  y0 + (ymax - y0) * exp(-exp(k * (lag - x) / (ymax - y0) + 1))
}

#' Self-starting Gompertz with an additive dummy term
#'
#' Extends the classical Gompertz form by adding a linear contribution
#' from a dummy covariate:
#' \deqn{y = \mathrm{Asym}\,\exp(-b_2\,\exp(-b_3 x)) + \beta\,d.}
#' Designed for use inside [stats::nls()]: starting values for the four
#' parameters are computed automatically from the data, and the
#' analytic gradient is supplied for faster, more reliable
#' convergence.
#'
#' @param x Numeric vector. Independent variable.
#' @param dummy Numeric (typically 0/1) vector of the same length as `x`.
#' @param Asym Upper asymptote.
#' @param b2 Curvature parameter.
#' @param b3 Rate parameter.
#' @param Beta Dummy effect size.
#'
#' @return A numeric vector of fitted values, with attributes for
#'   self-starting and an analytic gradient.
#'
#' @references Same as [Gompertz()].
#'
#' @seealso [stats::SSgompertz()] for the standard self-starting
#'   Gompertz without a dummy term, [fit_gompertz_dummy()] for a
#'   convenience wrapper.
#'
#' @examples
#' \donttest{
#' set.seed(42)
#' n <- 50
#' x <- seq(1, 10, length.out = n)
#' d <- rep(c(0, 1), each = n / 2)
#' y <- 100 * exp(-2 * exp(-0.3 * x)) + 20 * d + rnorm(n, 0, 3)
#' df <- data.frame(x = x, y = y, dummy = d)
#'
#' fit <- nls(y ~ SSgompertzDummy(x, dummy, Asym, b2, b3, Beta), data = df)
#' summary(fit)
#' }
#'
#' @export
SSgompertzDummy <- stats::selfStart(
  function(x, dummy, Asym, b2, b3, Beta) {
    Asym * exp(-b2 * exp(-b3 * x)) + Beta * dummy
  },
  initial = function(mCall, data, LHS, ...) {
    x_val     <- eval(mCall[["x"]],     data)
    dummy_val <- eval(mCall[["dummy"]], data)
    y_val     <- eval(LHS,              data)

    # Restrict to the dummy-zero subset for the curve-shape estimates so
    # the dummy effect (Beta) does not contaminate Asym, b2, b3.
    base_idx <- if (any(dummy_val == 0)) dummy_val == 0 else rep(TRUE, length(y_val))
    xb <- x_val[base_idx];  yb <- y_val[base_idx]

    Asym <- max(yb, na.rm = TRUE) * 1.05
    if (!is.finite(Asym) || Asym <= 0) Asym <- max(y_val, na.rm = TRUE) * 1.05

    # b2 controls the initial deficit: y(0) = Asym * exp(-b2). Use the
    # smallest observed y in the baseline as a proxy for y(0).
    y0 <- max(min(yb, na.rm = TRUE), Asym * 1e-4)   # avoid log(0)
    b2_init <- max(0.1, -log(max(1e-4, y0 / Asym)))

    # b3 is the rate parameter; estimate from the slope of
    # log(-log(y/Asym)) vs x in the linear part of the baseline data
    # where 0.1 < y/Asym < 0.9 so the double log is well-defined.
    ratio   <- pmin(pmax(yb / Asym, 1e-4), 1 - 1e-4)
    valid   <- ratio > 0.1 & ratio < 0.9 & is.finite(xb) & is.finite(ratio)
    b3_init <- if (sum(valid) >= 2L) {
      slope <- tryCatch(
        unname(stats::coef(stats::lm(log(-log(ratio[valid])) ~ xb[valid]))[2L]),
        error = function(e) NA_real_
      )
      if (is.finite(slope) && slope < 0) -slope else 0.1
    } else 0.1

    # Beta: rough estimate from the mean shift at non-zero dummy values.
    Beta_init <- if (any(dummy_val != 0)) {
      mean(y_val[dummy_val != 0], na.rm = TRUE) -
      mean(y_val[base_idx],        na.rm = TRUE)
    } else 0
    if (!is.finite(Beta_init)) Beta_init <- 0

    list(Asym = Asym, b2 = b2_init, b3 = b3_init, Beta = Beta_init)
  },
  parameters = c("Asym", "b2", "b3", "Beta")
)

# Analytic gradient -------------------------------------------------------
#
# f(x) = Asym * exp(-b2 * w) + Beta * d,  w = exp(-b3 x)
# df/dAsym = exp(-b2 * w)
# df/db2   = -Asym * w * exp(-b2 * w)
# df/db3   =  Asym * b2 * x * w * exp(-b2 * w)
# df/dBeta = d

attr(SSgompertzDummy, "gradient") <- function(x, dummy, Asym, b2, b3, Beta) {
  w   <- exp(-b3 * x)
  k   <- exp(-b2 * w)
  cbind(
    Asym = k,
    b2   = -Asym * w * k,
    b3   =  Asym * b2 * x * w * k,
    Beta = dummy
  )
}

#' Convenience wrapper to fit `SSgompertzDummy` to a data frame
#'
#' @param data A data frame with the columns referenced by `x`, `y`,
#'   `dummy`.
#' @param x,y,dummy Tidy-eval column references.
#' @param start Optional named list of starting values (`Asym`, `b2`,
#'   `b3`, `Beta`). If `NULL`, the self-starting initialiser is used.
#' @param ... Additional arguments passed to [stats::nls()].
#'
#' @return An object of class `nls`.
#'
#' @examples
#' \donttest{
#' set.seed(42)
#' df <- data.frame(
#'   x = seq(1, 10, length.out = 50),
#'   d = rep(c(0, 1), each = 25)
#' )
#' df$y <- 100 * exp(-2 * exp(-0.3 * df$x)) + 20 * df$d + rnorm(50, 0, 3)
#' fit <- fit_gompertz_dummy(df, x = x, y = y, dummy = d)
#' coef(fit)
#' }
#'
#' @export
fit_gompertz_dummy <- function(data, x, y, dummy, start = NULL, ...) {
  check_data(data)
  x_q <- rlang::enquo(x); x_n <- rlang::as_name(x_q)
  y_q <- rlang::enquo(y); y_n <- rlang::as_name(y_q)
  d_q <- rlang::enquo(dummy); d_n <- rlang::as_name(d_q)
  check_column(data, x_n, arg = "x")
  check_column(data, y_n, arg = "y")
  check_column(data, d_n, arg = "dummy")

  # nls expects literal names; rename to standard ones for the formula
  df <- data.frame(
    x     = data[[x_n]],
    y     = data[[y_n]],
    dummy = data[[d_n]]
  )

  if (is.null(start)) {
    stats::nls(
      formula = y ~ SSgompertzDummy(x, dummy, Asym, b2, b3, Beta),
      data    = df,
      ...
    )
  } else {
    stats::nls(
      formula = y ~ SSgompertzDummy(x, dummy, Asym, b2, b3, Beta),
      data    = df,
      start   = start,
      ...
    )
  }
}
