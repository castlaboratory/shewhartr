
# Audit 2026-09-25: broom findings 17, 18 ---------------------------------

test_that("glance()$pct_violations is the share of flagged points", {
  # A single spike trips Nelson 1 and Nelson 5 at the same points
  y <- c(rep(c(-0.2, 0.2), 10), 8, 8, rep(c(-0.2, 0.2), 4))
  fit <- shewhart_i_mr(data.frame(y = y), value = y,
                       rules = c("nelson_1_beyond_3s", "nelson_5_two_of_three",
                                 "nelson_6_four_of_five"))
  gl <- broom::glance(fit)
  expect_gt(gl$n_violations, sum(fit$augmented$.flag_any))
  expect_equal(gl$pct_violations, mean(fit$augmented$.flag_any))
  expect_lte(gl$pct_violations, 1)
})

test_that("tidy() of a regression chart follows the chart/line/value schema", {
  set.seed(1)
  df  <- data.frame(t = 1:60, y = 10 + 0.5 * (1:60) + rnorm(60))
  fit <- shewhart_regression(df, value = y, index = t, model = "linear",
                             phase_changes = c(21, 41))
  td <- broom::tidy(fit)
  expect_true(all(c("chart", "line", "value", ".phase", "endpoint") %in% names(td)))
  expect_setequal(unique(td$line), c("CL", "UCL", "LCL"))
  expect_equal(nrow(td), 3L * 2L * 3L)
  a0 <- fit$augmented[fit$augmented$.phase == 0L, ]
  expect_equal(td$value[td$.phase == 0L & td$endpoint == "first" & td$line == "UCL"],
               a0$.upper[1])
  expect_equal(td$value[td$.phase == 0L & td$endpoint == "last" & td$line == "CL"],
               a0$.center[nrow(a0)])
})
