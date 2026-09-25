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
  expect_equal(shewhartr:::mewma_h_lookup(0.10, 2L, TRUE), 8.65)   # P&R 8.64
  expect_equal(shewhartr:::mewma_h_lookup(0.10, 4L, TRUE), 12.73)  # P&R 12.73
  expect_equal(shewhartr:::mewma_h_lookup(0.10, 2L), 8.76)
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

test_that("MEWMA default h gives ARL_0 ~ 200 for p >= 3 (audit finding 6)", {
  testthat::skip_on_cran()
  # Vectorised in-control simulation with the tabulated h, for both
  # covariance modes; by affine invariance Sigma = I is enough. The
  # 1.3.0 table gave ARL_0 ~ 136 at lambda = 0.1, p = 4 (time-varying).
  sim_arl <- function(p, lambda, h, steady_state,
                      n = 3000L, max_run = 5000L) {
    ratio <- lambda / (2 - lambda)
    Z <- matrix(0, n, p); rl <- rep(NA_integer_, n)
    for (t in seq_len(max_run)) {
      Z <- lambda * matrix(stats::rnorm(n * p), n, p) + (1 - lambda) * Z
      v <- if (steady_state) ratio else ratio * (1 - (1 - lambda)^(2 * t))
      hit <- is.na(rl) & rowSums(Z^2) / v > h
      rl[hit] <- t
      if (!anyNA(rl)) break
    }
    rl[is.na(rl)] <- max_run
    mean(rl)
  }
  set.seed(20260925)
  cells <- list(list(p = 4L, lambda = 0.10, ss = FALSE),
                list(p = 6L, lambda = 0.20, ss = TRUE))
  for (cl in cells) {
    h   <- shewhartr:::mewma_h_lookup(cl$lambda, cl$p, cl$ss)
    arl <- sim_arl(cl$p, cl$lambda, h, cl$ss)
    expect_gt(arl, 200 * 0.85)
    expect_lt(arl, 200 * 1.15)
  }
})

test_that("MEWMA picks the h table matching steady_state (audit finding 6)", {
  set.seed(8)
  X  <- matrix(stats::rnorm(90), 30, 3)
  df <- data.frame(a = X[, 1], b = X[, 2], c = X[, 3])
  tv <- shewhart_mewma(df, vars = c(a, b, c), target = c(0, 0, 0),
                       cov = diag(3), lambda = 0.1)
  ss <- shewhart_mewma(df, vars = c(a, b, c), target = c(0, 0, 0),
                       cov = diag(3), lambda = 0.1, steady_state = TRUE)
  expect_equal(tv$metadata$h, shewhartr:::mewma_h_lookup(0.1, 3L, FALSE))
  expect_equal(ss$metadata$h, shewhartr:::mewma_h_lookup(0.1, 3L, TRUE))
})

test_that("MEWMA Phase II continues Z from Phase I (audit finding 16)", {
  set.seed(12)
  Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  all_x <- as.data.frame(MASS::mvrnorm(70, c(0, 0), Sigma))
  names(all_x) <- c("a", "b")
  all_x$a[41:70] <- all_x$a[41:70] + 0.8
  # One long Phase I chart is the reference for the continued recursion.
  ref <- shewhart_mewma(all_x, vars = c(a, b), target = c(0, 0),
                        cov = Sigma, lambda = 0.1)
  cal <- calibrate(all_x[1:40, ], vars = c(a, b), chart = "mewma",
                   target = c(0, 0), cov = Sigma, lambda = 0.1)
  mon <- monitor(all_x[41:70, ], cal)
  expect_equal(mon$augmented$.t2, ref$augmented$.t2[41:70])
  # ... and chained batches match one batch.
  m1 <- monitor(all_x[41:50, ], cal)
  m2 <- monitor(all_x[51:70, ], m1)
  expect_equal(m2$augmented$.t2, ref$augmented$.t2[51:70])
})
