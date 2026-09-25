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

test_that("monitor on regression chart returns phase_2 with stored fit", {
  set.seed(1)
  df  <- data.frame(t = 1:50, y = 0.1 * (1:50) + rnorm(50))
  cal <- shewhart_regression(df, value = y, index = t, model = "linear")
  new <- data.frame(t = 51:60, y = 0.1 * (51:60) + rnorm(10))
  mon <- monitor(new, cal)
  expect_equal(mon$phase, "phase_2")
  expect_s3_class(mon, c("shewhart_regression", "shewhart_chart"))
})

test_that("trim_outliers never re-admits a dropped observation (audit #4)", {
  set.seed(1)
  x <- rnorm(60, 100, 2)
  # Row 40 only stands out once row 1 has been trimmed. Before the fix,
  # iteration 2 dropped original row 39 and re-admitted row 1, and the
  # loop oscillated until max_trim_iter.
  x[c(1, 40)] <- c(160, 108)
  df <- data.frame(y = x)
  cal <- suppressMessages(
    calibrate(df, value = y, chart = "i_mr", trim_outliers = TRUE,
              max_trim_iter = 10L)
  )
  expect_equal(nrow(cal$violations), 0L)
  expect_false(any(c(160, 108) %in% cal$augmented$.value))
  expect_equal(cal$n, 58L)
})

test_that("trim_outliers drops whole subgroups for Xbar-R (audit #4)", {
  set.seed(2)
  d <- data.frame(g = rep(sprintf("S%02d", 1:25), each = 5),
                  y = rnorm(125, 50, 1))
  d$y[d$g == "S07"] <- d$y[d$g == "S07"] + 6
  cal <- suppressMessages(
    calibrate(d, value = y, subgroup = g, chart = "xbar_r",
              trim_outliers = TRUE)
  )
  expect_false("S07" %in% cal$augmented$g)
  # Every remaining subgroup keeps its full size (no "unequal sizes" abort)
  expect_true(all(cal$augmented$.n == 5L))
})
