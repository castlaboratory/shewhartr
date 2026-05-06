test_that("shewhart_i_mr returns a properly-classed object", {
  set.seed(1)
  df <- data.frame(y = rnorm(50, mean = 100, sd = 2))
  fit <- shewhart_i_mr(df, value = y)
  expect_s3_class(fit, c("shewhart_i_mr", "shewhart_chart"))
  expect_true(is_shewhart_chart(fit))
  expect_equal(fit$type, "i_mr")
  expect_equal(fit$n, 50L)
})

test_that("Limits are roughly correct for a simulated normal series", {
  set.seed(1)
  df <- data.frame(y = rnorm(500, mean = 100, sd = 2))
  fit <- shewhart_i_mr(df, value = y)

  expect_equal(unique(fit$augmented$.center), 100, tolerance = 0.5)
  expect_equal(fit$sigma_hat, 2, tolerance = 0.3)
  # Rate of out-of-control points under N(0,1) noise + Nelson 1 should be
  # about 0.27% (1 / 370). Accept 0-3% in 500 points.
  rate <- nrow(fit$violations) / fit$n
  expect_lt(rate, 0.05)
})

test_that("Outlier is flagged", {
  set.seed(1)
  df <- data.frame(y = c(rnorm(30), 10, rnorm(30)))   # huge spike at position 31
  fit <- shewhart_i_mr(df, value = y)
  expect_true(31L %in% fit$violations$position)
})

test_that("All sigma_method options run", {
  set.seed(1)
  df <- data.frame(y = rnorm(50))
  for (m in c("mr", "median_mr", "biweight", "sd")) {
    fit <- shewhart_i_mr(df, value = y, sigma_method = m)
    expect_s3_class(fit, "shewhart_i_mr")
    expect_true(is.finite(fit$sigma_hat))
    expect_gt(fit$sigma_hat, 0)
  }
})

test_that("Locale validation", {
  df <- data.frame(y = rnorm(30))
  expect_error(
    shewhart_i_mr(df, value = y, locale = "xx"),
    "not supported"
  )
  expect_silent(shewhart_i_mr(df, value = y, locale = "pt"))
})

test_that("broom methods work", {
  df <- data.frame(y = rnorm(30))
  fit <- shewhart_i_mr(df, value = y)
  expect_s3_class(broom::tidy(fit),    "tbl_df")
  expect_s3_class(broom::glance(fit),  "tbl_df")
  expect_s3_class(broom::augment(fit), "tbl_df")
  expect_equal(nrow(broom::glance(fit)), 1L)
  expect_equal(nrow(broom::augment(fit)), 30L)
})
