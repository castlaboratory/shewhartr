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

test_that("EWMA default L gives ARL_0 ~ 370 (audit finding 7)", {
  expect_equal(formals(shewhart_ewma)$L, 2.86)
  testthat::skip_on_cran()
  # Vectorised in-control simulation with the package's default limits
  # (time-varying, lambda = 0.2, L = 2.86); Lucas & Saccucci (1990).
  # With L = 2.7 the same simulation gives ~ 235.
  set.seed(20260925)
  n <- 4000L; lambda <- 0.2; L <- formals(shewhart_ewma)$L
  z <- numeric(n); rl <- rep(NA_integer_, n)
  r <- lambda / (2 - lambda)
  for (t in seq_len(5000L)) {
    z  <- lambda * stats::rnorm(n) + (1 - lambda) * z
    se <- sqrt(r * (1 - (1 - lambda)^(2 * t)))
    hit <- is.na(rl) & abs(z) > L * se
    rl[hit] <- t
    if (!anyNA(rl)) break
  }
  rl[is.na(rl)] <- 5000L
  expect_gt(mean(rl), 370 * 0.85)
  expect_lt(mean(rl), 370 * 1.15)
})

test_that("EWMA rule 1 fires exactly at the plotted limits (audit finding 8)", {
  mk <- function(jump) {
    data.frame(t = 1:40, y = c(rep(0, 20), jump, rep(0, 19)))
  }
  # For any L, flags must agree with .ewma against .upper / .lower.
  for (L in c(2.5, 2.86, 3.5)) {
    fit <- shewhart_ewma(mk(4), value = y, index = t, target = 0,
                         sigma = 1, lambda = 0.2, L = L)
    a <- fit$augmented
    outside <- a$.ewma > a$.upper | a$.ewma < a$.lower
    expect_identical(a$.flag_nelson_1_beyond_3s, outside)
    expect_identical(sort(unique(fit$violations$position)), which(outside))
  }
  # z_21 / se_21 = 3.0 > L = 2.86 must flag; 2.7 < 2.86 must not. The
  # 1.3.0 rule (alarm at 9 * se / L = 3.15 se) missed the first case.
  se21 <- sqrt(0.2 / 1.8 * (1 - 0.8^42))
  hi <- shewhart_ewma(mk(3.0 * se21 / 0.2), value = y, index = t,
                      target = 0, sigma = 1, lambda = 0.2, L = 2.86)
  expect_true(hi$augmented$.flag_any[21])
  lo <- shewhart_ewma(mk(2.7 * se21 / 0.2), value = y, index = t,
                      target = 0, sigma = 1, lambda = 0.2, L = 2.86)
  expect_false(lo$augmented$.flag_any[21])

  # Phase II uses the same boundary (steady-state limits).
  cal <- shewhart_ewma(mk(0), value = y, index = t, target = 0,
                       sigma = 1, lambda = 0.2, L = 2.86)
  se_ss <- sqrt(0.2 / 1.8)
  mon <- monitor(data.frame(t = 41:42, y = c(3.0 * se_ss / 0.2, 0)), cal)
  expect_true(mon$augmented$.ewma[1] > mon$augmented$.upper[1])
  expect_true(mon$augmented$.flag_any[1])
})

test_that("EWMA rejects missing values (audit finding 13)", {
  set.seed(1)
  df <- data.frame(t = 1:30, y = c(rnorm(10), NA, rnorm(19)))
  expect_error(shewhart_ewma(df, value = y, index = t), "missing")
  base <- data.frame(y = rnorm(30))
  cal  <- calibrate(base, value = y, chart = "ewma")
  expect_error(monitor(data.frame(y = c(1, NA, 2, 3, 4)), cal), "missing")
})
