test_that("Hotelling individual chart returns the expected structure", {
  set.seed(1)
  Sigma <- matrix(c(1, 0.7, 0.7, 1), 2, 2)
  Z     <- MASS::mvrnorm(60, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:60, x1 = Z[, 1], x2 = Z[, 2])
  fit   <- shewhart_hotelling(df, vars = c(x1, x2), index = t)

  expect_s3_class(fit, c("shewhart_hotelling", "shewhart_chart"))
  expect_equal(fit$metadata$p, 2L)
  expect_equal(fit$metadata$m, 60L)
  expect_equal(fit$metadata$n, 1L)
  expect_true(all(c(".t2", ".upper", ".flag_signal",
                    ".contrib_x1", ".contrib_x2") %in%
                  names(fit$augmented)))
  # T2 statistic is non-negative and matches the manual formula at one row
  X <- as.matrix(df[, c("x1", "x2")])
  xbar <- colMeans(X)
  Sinv <- solve(stats::cov(X))
  expected_t2_first <- as.numeric(t(X[1, ] - xbar) %*% Sinv %*% (X[1, ] - xbar))
  expect_equal(fit$augmented$.t2[1], expected_t2_first, tolerance = 1e-10)
})

test_that("Hotelling chart catches a correlation-breaking shift", {
  set.seed(2)
  # Baseline with a strong positive correlation
  Sigma_in  <- matrix(c(1,  0.95, 0.95, 1), 2, 2)
  base      <- MASS::mvrnorm(80, c(0, 0), Sigma_in)
  # Shift that breaks the correlation: same marginals, opposite sign
  Sigma_out <- matrix(c(1, -0.95,-0.95, 1), 2, 2)
  shifted   <- MASS::mvrnorm(20, c(0, 0), Sigma_out)

  df <- tibble::tibble(
    t  = 1:100,
    x1 = c(base[, 1], shifted[, 1]),
    x2 = c(base[, 2], shifted[, 2])
  )
  fit <- shewhart_hotelling(df, vars = c(x1, x2), index = t)
  hits <- which(fit$augmented$.flag_signal)
  expect_true(any(hits > 80L))
})

test_that("Hotelling subgrouped chart matches the expected formula", {
  set.seed(3)
  m <- 25; n <- 4; p <- 3
  Sigma <- diag(p)
  rows  <- list()
  for (i in seq_len(m)) {
    rows[[i]] <- cbind(
      subgroup = i,
      MASS::mvrnorm(n, mu = rep(0, p), Sigma = Sigma)
    )
  }
  raw <- do.call(rbind, rows)
  df  <- tibble::as_tibble(raw, .name_repair = "minimal")
  names(df)[2:4] <- c("a", "b", "c")
  fit <- shewhart_hotelling(df, vars = c(a, b, c),
                            subgroup = subgroup,
                            phase = "phase_1")

  expect_equal(fit$metadata$p, 3L)
  expect_equal(fit$metadata$m, m)
  expect_equal(fit$metadata$n, n)
  # UCL should equal p(m-1)(n-1)/(mn-m-p+1) * F(0.0027, p, mn-m-p+1)
  df2 <- m * n - m - p + 1L
  fq  <- stats::qf(1 - 0.0027, df1 = p, df2 = df2)
  expected_ucl <- p * (m - 1) * (n - 1) / df2 * fq
  expect_equal(fit$augmented$.upper[1], expected_ucl, tolerance = 1e-10)
})

test_that("Phase II UCL is wider than Phase I (subgrouped)", {
  set.seed(4)
  m <- 20; n <- 5; p <- 2
  rows <- list()
  for (i in seq_len(m)) {
    rows[[i]] <- cbind(
      subgroup = i,
      MASS::mvrnorm(n, c(0, 0), diag(2))
    )
  }
  raw <- do.call(rbind, rows)
  df  <- tibble::as_tibble(raw, .name_repair = "minimal")
  names(df)[2:3] <- c("a", "b")

  ph1 <- shewhart_hotelling(df, vars = c(a, b),
                            subgroup = subgroup, phase = "phase_1")
  ph2 <- shewhart_hotelling(df, vars = c(a, b),
                            subgroup = subgroup, phase = "phase_2")
  expect_gt(ph2$augmented$.upper[1], ph1$augmented$.upper[1])
})

test_that("Hotelling errors on too few rows / wrong vars / unequal subgroups", {
  set.seed(5)
  small <- tibble::tibble(x1 = rnorm(3), x2 = rnorm(3))
  expect_error(shewhart_hotelling(small, vars = c(x1, x2)), "rows")

  one_var <- tibble::tibble(x1 = rnorm(20))
  expect_error(shewhart_hotelling(one_var, vars = x1), "at least 2")

  # Unequal subgroup sizes
  uneven <- tibble::tibble(
    g  = c(rep(1, 3), rep(2, 5)),
    x1 = rnorm(8), x2 = rnorm(8)
  )
  expect_error(shewhart_hotelling(uneven, vars = c(x1, x2),
                                  subgroup = g),
               "same size")
})

test_that("Per-variable contributions sum to a meaningful share of T²", {
  set.seed(6)
  Sigma <- matrix(c(1, 0.7, 0.7, 1), 2, 2)
  Z     <- MASS::mvrnorm(80, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:80, x1 = Z[, 1], x2 = Z[, 2])
  fit   <- shewhart_hotelling(df, vars = c(x1, x2), index = t)
  contribs <- fit$augmented[, c(".contrib_x1", ".contrib_x2")]
  expect_true(all(contribs$.contrib_x1 >= 0))
  expect_true(all(contribs$.contrib_x2 >= 0))
  # On observations that signal, contributions should not all be zero
  signals <- which(fit$augmented$.flag_signal)
  if (length(signals) > 0L) {
    sums <- rowSums(contribs[signals, , drop = FALSE])
    expect_true(all(sums > 0))
  }
})
