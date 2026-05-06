# Phase II monitoring tests. These exercise the `monitor()` dispatcher
# for the chart types added in v1.0.0: np, u, xbar_r, xbar_s, regression
# (the i_mr / p / c paths are exercised in their respective test files).

test_that("monitor() dispatches for all eight chart types", {
  set.seed(1)
  expected <- c("i_mr", "p", "c", "np", "u", "xbar_r", "xbar_s", "regression")

  # i_mr -------------------------------------------------------------
  d1   <- data.frame(y = rnorm(50, 0, 1))
  cal1 <- calibrate(d1, value = y, chart = "i_mr")
  m1   <- monitor(data.frame(y = rnorm(20)), cal1)
  expect_equal(m1$phase, "phase_2")

  # p -----------------------------------------------------------------
  d2 <- data.frame(d = rbinom(30, 100, 0.05), n = 100L)
  cal2 <- calibrate(d2, defects = d, n = n, chart = "p")
  m2 <- monitor(data.frame(d = rbinom(15, 100, 0.05), n = 100L), cal2)
  expect_equal(m2$phase, "phase_2")

  # c -----------------------------------------------------------------
  d3 <- data.frame(d = rpois(40, 6))
  cal3 <- calibrate(d3, defects = d, chart = "c")
  m3 <- monitor(data.frame(d = rpois(15, 6)), cal3)
  expect_equal(m3$phase, "phase_2")

  # np ----------------------------------------------------------------
  d4 <- data.frame(d = rbinom(30, 50, 0.1))
  cal4 <- calibrate(d4, defects = d, n = 50L, chart = "np")
  m4 <- monitor(data.frame(d = rbinom(15, 50, 0.1)), cal4)
  expect_equal(m4$phase, "phase_2")

  # u -----------------------------------------------------------------
  exp_v  <- runif(30, 0.5, 1.5)
  d5     <- data.frame(d = rpois(30, 4 * exp_v), e = exp_v)
  cal5   <- calibrate(d5, defects = d, exposure = e, chart = "u")
  exp_v2 <- runif(15, 0.5, 1.5)
  m5     <- monitor(data.frame(d = rpois(15, 4 * exp_v2), e = exp_v2), cal5)
  expect_equal(m5$phase, "phase_2")

  # xbar_r ------------------------------------------------------------
  d6 <- data.frame(
    g = rep(1:25, each = 5),
    y = rnorm(125, 50, 2)
  )
  cal6 <- calibrate(d6, value = y, subgroup = g, chart = "xbar_r")
  d6n  <- data.frame(g = rep(1:10, each = 5), y = rnorm(50, 50, 2))
  m6   <- monitor(d6n, cal6)
  expect_equal(m6$phase, "phase_2")
  expect_true(all(c(".xbar", ".range", ".r_center") %in% names(m6$augmented)))

  # xbar_s ------------------------------------------------------------
  d7 <- data.frame(
    g = rep(1:25, each = 8),
    y = rnorm(200, 50, 2)
  )
  cal7 <- calibrate(d7, value = y, subgroup = g, chart = "xbar_s")
  d7n  <- data.frame(g = rep(1:10, each = 8), y = rnorm(80, 50, 2))
  m7   <- monitor(d7n, cal7)
  expect_equal(m7$phase, "phase_2")
  expect_true(all(c(".xbar", ".s", ".s_center") %in% names(m7$augmented)))

  # regression --------------------------------------------------------
  d8 <- data.frame(
    t = 1:60,
    y = 2 + 0.3 * (1:60) + rnorm(60, 0, 1)
  )
  cal8 <- calibrate(d8, value = y, index = t, chart = "regression",
                    model = "linear")
  d8n  <- data.frame(t = 61:80, y = 2 + 0.3 * (61:80) + rnorm(20, 0, 1))
  m8   <- monitor(d8n, cal8)
  expect_equal(m8$phase, "phase_2")
  expect_true(all(c(".value", ".fitted", ".residual") %in% names(m8$augmented)))

  expect_setequal(c(m1$type, m2$type, m3$type, m4$type,
                    m5$type, m6$type, m7$type, m8$type), expected)
})

test_that("Phase II detects an injected mean shift (i_mr)", {
  set.seed(2)
  base <- data.frame(y = rnorm(100, 0, 1))
  cal  <- calibrate(base, value = y, chart = "i_mr")
  shift <- data.frame(y = rnorm(50, 3, 1))   # 3-sigma shift
  m    <- monitor(shift, cal)
  expect_gt(nrow(m$violations), 0L)
})

test_that("Phase II respects new data column names from calibration", {
  set.seed(3)
  d   <- data.frame(measurement = rnorm(50))
  cal <- calibrate(d, value = measurement, chart = "i_mr")
  # Wrong column name => clean error
  bad <- data.frame(other = rnorm(20))
  expect_error(monitor(bad, cal))
})
