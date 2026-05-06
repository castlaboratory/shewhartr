test_that("Linear regression chart fits without error", {
  set.seed(1)
  df <- data.frame(t = 1:60, y = 0.1 * (1:60) + rnorm(60))
  fit <- shewhart_regression(df, value = y, index = t, model = "linear")
  expect_s3_class(fit, c("shewhart_regression", "shewhart_chart"))
  expect_gte(length(fit$fits), 1L)
  expect_true(all(c(".center", ".upper", ".lower", ".phase") %in%
                  names(fit$augmented)))
})

test_that("Phase changes are detected when shift is large", {
  set.seed(1)
  df <- data.frame(
    t = 1:120,
    y = c( 1:60 * 0.5  + rnorm(60, sd = 0.5),
           30 + 1:60 * 0.1 + rnorm(60, sd = 0.5))
  )
  fit <- shewhart_regression(df, value = y, index = t,
                             model = "linear",
                             phase_rule = "nelson_2_nine_same")
  expect_gte(length(unique(fit$augmented$.phase)), 2L)
})

test_that("we_seven_same is more permissive than nelson_2_nine_same", {
  set.seed(1)
  df <- data.frame(
    t = 1:80,
    y = c(rnorm(40), rnorm(40, mean = 1.2))
  )
  f_we <- shewhart_regression(df, value = y, index = t,
                              model = "linear",
                              phase_rule = "we_seven_same")
  f_n2 <- shewhart_regression(df, value = y, index = t,
                              model = "linear",
                              phase_rule = "nelson_2_nine_same")
  expect_gte(length(f_we$fits), length(f_n2$fits))
})

test_that("Custom formula overrides model menu", {
  set.seed(1)
  df <- data.frame(t = 1:50, y = log(1:50) + rnorm(50, sd = 0.1))
  fit <- shewhart_regression(df, value = y, index = t,
                             formula = y ~ log(t))
  expect_s3_class(fit, "shewhart_regression")
})
