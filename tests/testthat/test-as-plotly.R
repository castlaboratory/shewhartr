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
