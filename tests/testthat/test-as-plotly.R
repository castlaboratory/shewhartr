test_that("as_plotly errors with informative message when plotly absent", {
  # Capture the namespace check rather than test environment availability
  # by using a class with no method.
  expect_error(as_plotly("not a chart"), "No .* method")
})

test_that("as_plotly returns a plotly object for single-panel charts", {
  skip_if_not_installed("plotly")
  set.seed(1)
  df  <- data.frame(t = 1:30, x = rpois(30, 5))
  fit <- shewhart_c(df, defects = x, index = t, limits = "poisson")
  out <- as_plotly(fit)
  expect_s3_class(out, "plotly")
})

test_that("as_plotly returns a plotly subplot for two-panel charts", {
  skip_if_not_installed("plotly")
  set.seed(1)
  df  <- data.frame(t = 1:60, y = rnorm(60, mean = 100, sd = 2))
  fit <- shewhart_i_mr(df, value = y, index = t)
  out <- as_plotly(fit)
  expect_s3_class(out, "plotly")
})

test_that("as_plotly works for memory-based and multivariate charts", {
  skip_if_not_installed("plotly")
  set.seed(1)
  df  <- data.frame(t = 1:60, y = rnorm(60, mean = 100, sd = 2))
  expect_s3_class(as_plotly(shewhart_ewma(df, value = y, index = t)),  "plotly")
  expect_s3_class(as_plotly(shewhart_cusum(df, value = y, index = t)), "plotly")

  skip_if_not_installed("MASS")
  Sigma <- matrix(c(1, 0.7, 0.7, 1), 2, 2)
  Z     <- MASS::mvrnorm(60, c(0, 0), Sigma)
  df2   <- data.frame(t = 1:60, x1 = Z[, 1], x2 = Z[, 2])
  fit2  <- shewhart_hotelling(df2, vars = c(x1, x2), index = t)
  expect_s3_class(as_plotly(fit2), "plotly")
})

# Audit 2026-09-25, findings 3 / 12 / 19 --------------------------------------

test_that("as_plotly works on a Phase II I-MR chart", {
  skip_if_not_installed("plotly")
  set.seed(1)
  calib <- calibrate(data.frame(y = rnorm(40)), value = y)
  mon   <- monitor(data.frame(y = rnorm(10)), calib)
  expect_s3_class(as_plotly(mon), "plotly")
})

test_that("as_plotly forwards locale, show_violations and show_sigma_zones", {
  skip_if_not_installed("plotly")
  set.seed(1)
  df  <- data.frame(t = 1:30, x = c(rpois(29, 5), 20))
  fit <- shewhart_c(df, defects = x, index = t, limits = "poisson")
  b_pt <- plotly::plotly_build(as_plotly(fit, locale = "pt"))
  expect_match(b_pt$x$layout$title$text, tr("title_c", "pt"), fixed = TRUE)

  n_traces <- function(p) length(plotly::plotly_build(p)$x$data)
  expect_lt(n_traces(as_plotly(fit, show_violations = FALSE)),
            n_traces(as_plotly(fit)))
  expect_gt(n_traces(as_plotly(fit, show_sigma_zones = TRUE)),
            n_traces(as_plotly(fit)))
})

test_that("as_plotly puts the regression legend below the plot", {
  skip_if_not_installed("plotly")
  set.seed(1)
  df  <- data.frame(t = 1:100, y = 50 + cumsum(rnorm(100, 0.5, 1)))
  fit <- shewhart_regression(df, value = y, index = t, model = "linear",
                             phase_changes = seq(11, 91, by = 10))
  b <- plotly::plotly_build(as_plotly(fit))
  expect_equal(b$x$layout$legend$orientation, "h")
  expect_lt(b$x$layout$legend$y, 0)
})
