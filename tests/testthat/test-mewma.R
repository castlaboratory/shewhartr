test_that("MEWMA chart returns expected augmented columns", {
  set.seed(1)
  Sigma <- matrix(c(1, 0.6, 0.6, 1), 2, 2)
  Z     <- MASS::mvrnorm(80, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:80, x1 = Z[, 1], x2 = Z[, 2])
  fit   <- shewhart_mewma(df, vars = c(x1, x2), index = t,
                          target = c(0, 0), cov = Sigma,
                          lambda = 0.1)
  expect_s3_class(fit, c("shewhart_mewma", "shewhart_chart"))
  expect_equal(fit$metadata$p, 2L)
  expect_equal(fit$metadata$lambda, 0.1)
  expect_true(all(c(".t2", ".upper", ".flag_signal") %in%
                  names(fit$augmented)))
  # First T2 has Z_1 = lambda * (X_1 - target); easy to compute by hand.
  ratio    <- 0.1 / (2 - 0.1)
  sigma_z1 <- ratio * (1 - (1 - 0.1)^2) * Sigma
  z1       <- 0.1 * (df$x1[1] - 0)
  z2       <- 0.1 * (df$x2[1] - 0)
  expected <- as.numeric(t(c(z1, z2)) %*% solve(sigma_z1) %*% c(z1, z2))
  expect_equal(fit$augmented$.t2[1], expected, tolerance = 1e-10)
})

test_that("MEWMA detects a small persistent multivariate shift", {
  set.seed(2)
  Sigma <- matrix(c(1, 0.7, 0.7, 1), 2, 2)
  base  <- MASS::mvrnorm(60, c(0, 0), Sigma)
  shift <- MASS::mvrnorm(40, c(0.6, 0.6), Sigma)        # small shift
  df    <- tibble::tibble(
    t  = 1:100,
    x1 = c(base[, 1], shift[, 1]),
    x2 = c(base[, 2], shift[, 2])
  )
  fit  <- shewhart_mewma(df, vars = c(x1, x2), index = t,
                         target = c(0, 0), cov = Sigma,
                         lambda = 0.1)
  expect_gt(sum(fit$augmented$.flag_signal), 0)
  # Alarms should be in the post-shift segment.
  hits <- which(fit$augmented$.flag_signal)
  expect_gt(median(hits), 60)
})

test_that("steady_state = TRUE produces a constant T2 covariance", {
  set.seed(3)
  Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  Z     <- MASS::mvrnorm(80, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:80, a = Z[, 1], b = Z[, 2])
  fit_t <- shewhart_mewma(df, vars = c(a, b), index = t,
                          target = c(0, 0), cov = Sigma,
                          lambda = 0.1, steady_state = FALSE)
  fit_s <- shewhart_mewma(df, vars = c(a, b), index = t,
                          target = c(0, 0), cov = Sigma,
                          lambda = 0.1, steady_state = TRUE)
  # In steady-state mode, the early observations should give *smaller*
  # T2 (the implicit warm-up factor (1 - (1-lambda)^(2i)) shrinks the
  # variance before the asymptote, making T2 *larger* in the time-
  # varying mode).
  expect_gte(fit_t$augmented$.t2[1], fit_s$augmented$.t2[1])
})

test_that("MEWMA UCL lookup returns NA outside the table", {
  expect_equal(shewhartr:::mewma_h_lookup(0.10, 2L), 8.64)
  expect_true(is.na(shewhartr:::mewma_h_lookup(0.30, 2L)))
  expect_true(is.na(shewhartr:::mewma_h_lookup(0.10, 8L)))
})

test_that("MEWMA aborts when (lambda, p) outside table and h is NULL", {
  set.seed(4)
  Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  Z     <- MASS::mvrnorm(40, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:40, a = Z[, 1], b = Z[, 2])
  expect_error(
    shewhart_mewma(df, vars = c(a, b), index = t,
                   target = c(0, 0), cov = Sigma, lambda = 0.30),
    "tabulated"
  )
})

test_that("MEWMA Phase II monitoring inherits limits", {
  set.seed(5)
  Sigma <- matrix(c(1, 0.6, 0.6, 1), 2, 2)
  base  <- as.data.frame(MASS::mvrnorm(80, c(0, 0), Sigma))
  names(base) <- c("a", "b")
  cal   <- calibrate(base, vars = c(a, b), chart = "mewma",
                     target = c(0, 0), cov = Sigma, lambda = 0.1)
  new   <- as.data.frame(MASS::mvrnorm(40, c(0, 0), Sigma))
  names(new) <- c("a", "b")
  mon   <- monitor(new, cal)
  expect_s3_class(mon, c("shewhart_mewma", "shewhart_chart"))
  expect_equal(mon$phase, "phase_2")
  expect_equal(mon$augmented$.upper[1], cal$metadata$h)
})
