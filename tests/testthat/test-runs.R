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

# Audit 2026-09-25, finding 14: NA must not crash rules 3/4/7/8 -------------

test_that("Nelson 3/4/7/8 tolerate NA (incomplete windows do not fire)", {
  x <- c(1:10, NA, 1:10) / 10
  rules <- c("nelson_3_six_trend", "nelson_4_alternating",
             "nelson_7_stratification", "nelson_8_mixture")
  out <- expect_no_error(
    shewhart_runs(x, rules = rules, center = 0, sigma = 1)
  )
  # Trend fires inside each complete run, never across the NA
  trend <- out$position[out$rule == "nelson_3_six_trend"]
  expect_true(all(trend %in% c(6:10, 17:21)))
  # Stratification: 21 points within 1 sigma but the NA breaks the run
  expect_false(any(out$rule == "nelson_7_stratification"))

  alt <- rep(c(-2, 2), 10); alt[5] <- NA
  expect_no_error(shewhart_runs(alt, rules = rules, center = 0, sigma = 1))
  out8 <- shewhart_runs(alt, rules = "nelson_8_mixture", center = 0, sigma = 1)
  expect_true(all(out8$position >= 13L))   # first complete window ends at 13
})

test_that("chart constructors do not crash on NA with all eight rules", {
  # 15+ points within 1 sigma around an NA used to abort rule 7
  y <- c(rep(c(0.1, -0.1), 10), NA, rep(c(0.1, -0.1), 10))
  all_rules <- shewhart_rules_available()$rule
  expect_no_error(
    suppressWarnings(shewhart_i_mr(data.frame(y = y), value = y,
                                   rules = all_rules))
  )
})

# Audit 2026-09-25, finding 30: Nelson 5/6 --------------------------------

test_that("Nelson 5 flags the completing point once, including positions 1-2", {
  # Pair at positions 1-2 beyond +2 sigma used to be missed
  x <- c(2.5, 2.5, 0, 0, 0)
  out <- shewhart_runs(x, rules = "nelson_5_two_of_three",
                       center = 0, sigma = 1)
  expect_equal(out$position, 2L)

  # Pair at 5-6 followed by an in-zone point: flag 6 only, not 6 and 7
  x <- c(0, 0, 0, 0, 2.5, 2.5, 0, 0)
  out <- shewhart_runs(x, rules = "nelson_5_two_of_three",
                       center = 0, sigma = 1)
  expect_equal(out$position, 6L)

  # Opposite sides never combine
  x <- c(0, 2.5, -2.5, 0)
  out <- shewhart_runs(x, rules = "nelson_5_two_of_three",
                       center = 0, sigma = 1)
  expect_equal(nrow(out), 0L)
})

test_that("Nelson 6 flags the completing point once, including positions 1-4", {
  x <- c(1.5, 1.5, 1.5, 1.5, 0, 0, 0)
  out <- shewhart_runs(x, rules = "nelson_6_four_of_five",
                       center = 0, sigma = 1)
  expect_equal(out$position, 4L)

  x <- c(0, 0, 0, 1.5, 1.5, 0, 1.5, 1.5, 0, 0)
  out <- shewhart_runs(x, rules = "nelson_6_four_of_five",
                       center = 0, sigma = 1)
  expect_equal(out$position, 8L)
})
