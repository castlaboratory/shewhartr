test_that("EWMA chart returns expected augmented columns", {
  set.seed(1)
  df <- data.frame(t = 1:60, y = rnorm(60, 100, 2))
  fit <- shewhart_ewma(df, value = y, index = t)
  expect_s3_class(fit, c("shewhart_ewma", "shewhart_chart"))
  expect_true(all(c(".value", ".ewma", ".center", ".upper", ".lower") %in%
                  names(fit$augmented)))
  expect_equal(fit$augmented$.center[1], mean(df$y))
})

test_that("EWMA recursion satisfies z[i] = lambda*x[i] + (1-lambda)*z[i-1]", {
  set.seed(1)
  df <- data.frame(t = 1:50, y = rnorm(50, 100, 2))
  fit <- shewhart_ewma(df, value = y, index = t, lambda = 0.3)
  z <- fit$augmented$.ewma
  mu <- mean(df$y)
  expected <- numeric(50L)
  prev <- mu
  for (i in seq_len(50L)) {
    expected[i] <- 0.3 * df$y[i] + 0.7 * prev
    prev <- expected[i]
  }
  expect_equal(z, expected, tolerance = 1e-12)
})

test_that("EWMA time-varying limits widen toward the asymptotic ones", {
  set.seed(1)
  df <- data.frame(t = 1:100, y = rnorm(100, 100, 2))
  fit <- shewhart_ewma(df, value = y, index = t, lambda = 0.2, L = 2.7)
  upr <- fit$augmented$.upper
  expect_lt(upr[1], upr[length(upr)])
  # Asymptotic distance from centre: L * sigma * sqrt(lambda / (2 - lambda))
  asym_se <- 2.7 * fit$sigma_hat * sqrt(0.2 / 1.8)
  expect_equal(upr[length(upr)] - fit$augmented$.center[length(upr)],
               asym_se, tolerance = 1e-3)
})

test_that("EWMA detects a sustained 1-sigma shift faster than I-MR", {
  set.seed(7)
  shift <- c(rnorm(40, 0, 1), rnorm(60, 1, 1))
  df    <- data.frame(t = seq_along(shift), y = shift)

  ewma <- shewhart_ewma(df, value = y, index = t, lambda = 0.2, L = 2.7)
  imr  <- shewhart_i_mr(df, value = y, index = t,
                        rules = "nelson_1_beyond_3s")

  first_alarm <- function(fit) {
    hits <- which(fit$augmented$.flag_any)
    if (length(hits) == 0L) Inf else min(hits)
  }
  expect_lt(first_alarm(ewma), first_alarm(imr) + 1)
})

test_that("EWMA validates lambda and L", {
  df <- data.frame(t = 1:30, y = rnorm(30))
  expect_error(shewhart_ewma(df, value = y, lambda = 0),  "lambda")
  expect_error(shewhart_ewma(df, value = y, lambda = 2),  "lambda")
  expect_error(shewhart_ewma(df, value = y, L = -1),      "L")
})

test_that("steady_state = TRUE gives flat limits", {
  set.seed(1)
  df  <- data.frame(t = 1:60, y = rnorm(60, 100, 2))
  fit <- shewhart_ewma(df, value = y, index = t, steady_state = TRUE)
  expect_equal(length(unique(round(fit$augmented$.upper, 8))), 1L)
})
