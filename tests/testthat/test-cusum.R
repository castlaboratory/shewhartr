test_that("CUSUM chart returns expected augmented columns", {
  set.seed(1)
  df <- data.frame(t = 1:60, y = rnorm(60, 100, 2))
  fit <- shewhart_cusum(df, value = y, index = t)
  expect_s3_class(fit, c("shewhart_cusum", "shewhart_chart"))
  expect_true(all(c(".value", ".cusum_pos", ".cusum_neg",
                    ".upper", ".lower", ".flag_signal") %in%
                  names(fit$augmented)))
})

test_that("CUSUM accumulators are non-negative and reset at zero", {
  set.seed(1)
  df  <- data.frame(t = 1:50, y = rnorm(50, 100, 2))
  fit <- shewhart_cusum(df, value = y, index = t)
  expect_true(all(fit$augmented$.cusum_pos >= 0))
  expect_true(all(fit$augmented$.cusum_neg >= 0))
})

test_that("CUSUM signals on a sustained upward shift", {
  set.seed(2)
  df  <- data.frame(t = 1:80,
                    y = c(rnorm(40, 0, 1), rnorm(40, 1.5, 1)))
  fit <- shewhart_cusum(df, value = y, index = t,
                        target = 0, sigma = 1, k = 0.5, h = 4)
  hits <- which(fit$augmented$.flag_signal)
  expect_gt(length(hits), 0)
  expect_gte(min(hits), 41L)         # alarm only after the shift
})

test_that("CUSUM with no shift does not alarm at h = 5 over 80 obs", {
  set.seed(3)
  df  <- data.frame(t = 1:80, y = rnorm(80, 100, 2))
  fit <- shewhart_cusum(df, value = y, index = t, h = 5)
  expect_equal(sum(fit$augmented$.flag_signal), 0L)
})

test_that("CUSUM validates k and h", {
  df <- data.frame(t = 1:30, y = rnorm(30))
  expect_error(shewhart_cusum(df, value = y, k = 0),  "k")
  expect_error(shewhart_cusum(df, value = y, h = -1), "h")
})

test_that("CUSUM violations table has one row per signalling observation", {
  set.seed(4)
  df  <- data.frame(t = 1:60,
                    y = c(rnorm(20, 0, 1), rnorm(40, 2, 1)))
  fit <- shewhart_cusum(df, value = y, index = t,
                        target = 0, sigma = 1, k = 0.5, h = 4)
  expect_equal(nrow(fit$violations), sum(fit$augmented$.flag_signal))
  expect_true(all(fit$violations$rule == "cusum_decision"))
})
