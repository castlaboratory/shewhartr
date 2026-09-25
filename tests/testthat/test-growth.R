test_that("Gompertz returns finite values across the canonical range", {
  x <- seq(0, 30, length.out = 100)
  y <- Gompertz(x, y0 = 0, ymax = 100, k = 5, lag = 5)
  expect_equal(length(y), length(x))
  expect_true(all(is.finite(y)))
  expect_lt(y[1], y[length(y)])           # monotone non-decreasing on this grid
  expect_lt(max(y), 100 + 1e-6)            # bounded by ymax
})

test_that("Gompertz k is the maximum slope and lag the tangent intercept (audit #26)", {
  y0 <- 2; ymax <- 102; k <- 5; lag <- 5
  x  <- seq(0, 60, by = 1e-3)
  y  <- Gompertz(x, y0 = y0, ymax = ymax, k = k, lag = lag)
  slope <- diff(y) / diff(x)
  i  <- which.max(slope)
  # Zwietering et al. (1990): maximum slope equals k (was k / e)
  expect_equal(max(slope), k, tolerance = 1e-4)
  # Tangent at the inflection point crosses the lower asymptote at lag
  x_i <- x[i]; y_i <- y[i]
  expect_equal(x_i - (y_i - y0) / slope[i], lag, tolerance = 1e-3)
})

test_that("Gompertz aborts when ymax <= y0", {
  expect_error(
    Gompertz(0:10, y0 = 50, ymax = 50, k = 1, lag = 1),
    "ymax"
  )
})

test_that("fit_gompertz_dummy recovers parameters without manual start values", {
  set.seed(42)
  df <- data.frame(
    x = seq(1, 10, length.out = 50),
    d = rep(c(0, 1), each = 25)
  )
  df$y <- 100 * exp(-2 * exp(-0.3 * df$x)) + 20 * df$d + rnorm(50, 0, 3)

  fit <- fit_gompertz_dummy(df, x = x, y = y, dummy = d)
  est <- coef(fit)
  expect_equal(unname(est["Asym"]), 100, tolerance = 0.10)
  expect_equal(unname(est["b2"]),     2,   tolerance = 0.20)
  expect_equal(unname(est["b3"]),     0.3, tolerance = 0.20)
  expect_equal(unname(est["Beta"]),  20,   tolerance = 0.10)
})

test_that("fit_gompertz_dummy honours user-supplied start values", {
  set.seed(1)
  df <- data.frame(
    x = seq(1, 10, length.out = 40),
    d = rep(c(0, 1), each = 20)
  )
  df$y <- 80 * exp(-2.5 * exp(-0.4 * df$x)) + 10 * df$d + rnorm(40, 0, 2)
  start <- list(Asym = 80, b2 = 2.5, b3 = 0.4, Beta = 10)

  fit <- fit_gompertz_dummy(df, x = x, y = y, dummy = d, start = start)
  expect_s3_class(fit, "nls")
})
