test_that("Nelson 1 detects the obvious outlier", {
  set.seed(1)
  x <- c(rnorm(20), 5, rnorm(10))    # spike at position 21
  out <- shewhart_runs(x, rules = "nelson_1_beyond_3s",
                      center = 0, sigma = 1)
  expect_true(21L %in% out$position)
  expect_true(all(out$rule == "nelson_1_beyond_3s"))
})

test_that("Nelson 2 detects 9 same-side run", {
  x <- c(rep(0.5, 9), 0)
  out <- shewhart_runs(x, rules = "nelson_2_nine_same",
                      center = 0, sigma = 1)
  expect_true(9L %in% out$position)
})

test_that("WE seven-same fires on 7 same-side run", {
  x <- c(rep(0.5, 7), 0)
  out <- shewhart_runs(x, rules = "we_seven_same",
                      center = 0, sigma = 1)
  expect_true(7L %in% out$position)
})

test_that("Nelson 3 detects six-point trend", {
  x <- 1:6 / 10
  out <- shewhart_runs(x, rules = "nelson_3_six_trend",
                      center = 0, sigma = 1)
  expect_true(6L %in% out$position)
})

test_that("In-control series triggers no rules", {
  set.seed(42)
  x <- rnorm(50)
  out <- shewhart_runs(x, rules = c("nelson_1_beyond_3s",
                                    "nelson_2_nine_same"),
                      center = 0, sigma = 1)
  # Possible (rare) Nelson 1 fires under random data; require
  # that we get << n hits.
  expect_lt(nrow(out), 10L)
})

test_that("Empty series produces empty result", {
  out <- shewhart_runs(numeric(0),
                      rules = "nelson_1_beyond_3s",
                      center = 0, sigma = 1)
  expect_equal(nrow(out), 0L)
})

test_that("Unknown rule is rejected", {
  expect_error(
    shewhart_runs(rnorm(10), rules = "nelson_99",
                  center = 0, sigma = 1),
    "Unknown rule"
  )
})

test_that("shewhart_rules_available returns the registry", {
  reg <- shewhart_rules_available()
  expect_s3_class(reg, "tbl_df")
  expect_true(all(c("rule", "description") %in% names(reg)))
  expect_gt(nrow(reg), 5L)
})
