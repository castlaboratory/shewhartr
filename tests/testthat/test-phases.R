test_that("calibrate flags phase as phase_1", {
  set.seed(1)
  df  <- data.frame(y = rnorm(60))
  cal <- calibrate(df, value = y, chart = "i_mr")
  expect_equal(cal$phase, "phase_1")
})

test_that("monitor inherits limits and tags phase as phase_2", {
  set.seed(1)
  base <- data.frame(y = rnorm(60, 100, 2))
  new  <- data.frame(y = rnorm(20, 102, 2))
  cal  <- calibrate(base, value = y, chart = "i_mr")
  mon  <- monitor(new, cal)
  expect_equal(mon$phase, "phase_2")
  expect_equal(mon$augmented$.center[1], cal$augmented$.center[1])
  expect_equal(mon$sigma_hat, cal$sigma_hat)
})

test_that("trim_outliers iteratively drops violations", {
  set.seed(1)
  contaminated <- c(rnorm(60, 100, 2), 200)   # one wild outlier
  df <- data.frame(y = contaminated)
  cal_no_trim <- calibrate(df, value = y, chart = "i_mr")
  cal_trim    <- calibrate(df, value = y, chart = "i_mr",
                           trim_outliers = TRUE)
  expect_lt(cal_trim$sigma_hat, cal_no_trim$sigma_hat)
})

test_that("monitor errors on unsupported chart type", {
  set.seed(1)
  df <- data.frame(t = 1:50, y = rnorm(50))
  cal <- shewhart_regression(df, value = y, index = t, model = "linear")
  expect_error(monitor(df, cal), "not yet implemented")
})
