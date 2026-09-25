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

# Audit 2026-09-25 regressions --------------------------------------------

test_that("start_base is honoured together with phase_changes (audit #21)", {
  set.seed(1)
  d <- data.frame(t = 1:60, y = rnorm(60))
  explicit <- shewhart_regression(d, value = y, index = t, model = "linear",
                                  phase_changes = 40, start_base = 10)
  expect_equal(as.vector(table(explicit$augmented$.phase)), c(10L, 29L, 21L))

  # Without start_base the base phase ends at the first supplied change
  implicit <- shewhart_regression(d, value = y, index = t, model = "linear",
                                  phase_changes = 40)
  expect_equal(as.vector(table(implicit$augmented$.phase)), c(39L, 21L))
})

test_that("model = 'auto' maps Box-Cox lambda to the nearest menu rung (audit #22)", {
  grid <- seq(-2, 2, by = 0.1)
  lam_m01 <- grid[abs(grid + 0.1) < 1e-9]
  lam_p01 <- grid[abs(grid - 0.1) < 1e-9]
  # Floating-point grid points must fall on the same side of the window
  expect_equal(auto_model_from_lambda(lam_m01), "log")
  expect_equal(auto_model_from_lambda(lam_p01), "log")
  expect_equal(auto_model_from_lambda(0), "log")
  expect_equal(auto_model_from_lambda(-1), "log")
  # Square-root lambda: never the (stronger-than-log) loglog model
  expect_equal(auto_model_from_lambda(0.5), "linear")
  expect_equal(auto_model_from_lambda(1), "linear")

  # End to end: a square-root-scale series is fitted as linear
  set.seed(5)
  d <- data.frame(t = 1:40, y = (5 + 0.4 * (1:40) + rnorm(40, sd = 0.3))^2)
  lam <- shewhart_box_cox_lambda(d$y + 1)
  expect_gt(lam, 0.25)
  fit <- shewhart_regression(d, value = y, index = t, model = "auto",
                             phase_changes = 999)
  expect_false(any(vapply(fit$fits, function(f) f$.shewhart_model,
                          character(1L)) == "loglog"))
})

test_that("build_phases keeps one fit per phase when a fit is NULL (audit #34)", {
  set.seed(2)
  d <- data.frame(t = 1:30, y = 0.2 * (1:30) + rnorm(30))
  # Base phase has 2 rows: its fit is NULL; later phases must keep their slot
  fit <- shewhart_regression(d, value = y, index = t, model = "linear",
                             phase_changes = c(3, 15))
  expect_length(fit$fits, 3L)
  expect_null(fit$fits[[1]])
  expect_s3_class(fit$fits[[2]], "lm")
  expect_s3_class(fit$fits[[3]], "lm")
  expect_length(fit$metadata$phase_sigma, 3L)
})

test_that("a phase too short to fit extrapolates the previous one (audit #1, #34)", {
  set.seed(3)
  d <- data.frame(t = 1:22, y = 10 + 2 * (1:22) + rnorm(22, sd = 0.3))
  fit <- shewhart_regression(d, value = y, index = t, model = "linear",
                             phase_changes = c(11, 21))
  last <- fit$augmented[fit$augmented$.phase == 2L, ]
  expect_equal(fit$metadata$phase_n_end, c(10L, 10L, 12L))
  # Continuation of phase 1 (t = 11..20 -> .N = 1..10), not a restart
  expect_equal(last$.fitted, c(52, 54), tolerance = 0.02)
  expect_equal(fit$metadata$phase_sigma[3], fit$metadata$phase_sigma[2])
})

test_that("growth-curve first increment drops the cumsum offset (audit #35)", {
  t   <- 1:40
  cum <- 1000 / (1 + exp(-(t - 20) / 4))
  d   <- data.frame(t = t, y = c(cum[1], diff(cum)) + c(0.3, -0.3))
  fit <- shewhart_regression(d, value = y, index = t, model = "logistic",
                             phase_changes = 999)
  f  <- fit$fits[[1]]
  C1 <- as.vector(stats::predict(f, newdata = data.frame(.N = 1)))
  C2 <- as.vector(stats::predict(f, newdata = data.frame(.N = 2)))
  # The model is fitted to cumsum(y) + 1, so the first increment is C(1) - 1
  expect_equal(fit$augmented$.fitted[1], C1 - 1)
  expect_equal(fit$augmented$.fitted[2], C2 - C1)
})

test_that("build_phases has no undeclared global variables (audit #31)", {
  skip_if_not_installed("codetools")
  find_globals <- get("findGlobals", envir = asNamespace("codetools"))
  g <- find_globals(build_phases, merge = FALSE)$variables
  expect_false(".phase" %in% g)
})
