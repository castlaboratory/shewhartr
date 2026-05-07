test_that("MCUSUM chart returns expected augmented columns", {
  set.seed(1)
  Sigma <- matrix(c(1, 0.6, 0.6, 1), 2, 2)
  Z     <- MASS::mvrnorm(80, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:80, x1 = Z[, 1], x2 = Z[, 2])
  fit   <- shewhart_mcusum(df, vars = c(x1, x2), index = t,
                           target = c(0, 0), cov = Sigma)
  expect_s3_class(fit, c("shewhart_mcusum", "shewhart_chart"))
  expect_equal(fit$metadata$p, 2L)
  expect_equal(fit$metadata$k, 0.5)
  expect_equal(fit$metadata$h, 5.50)         # Crosier 1988 Tab 1, p=2
  expect_true(all(c(".y", ".upper", ".flag_signal") %in%
                  names(fit$augmented)))
  expect_true(all(fit$augmented$.y >= 0))
})

test_that("MCUSUM behaves in-control on a stable series", {
  # ARL_0 ~ 200 with h = 5.5 gives roughly 1 expected alarm per 200
  # observations under H_0. A few false alarms are acceptable; we
  # check that the alarm rate is much lower than 5 percent (the
  # Hotelling-equivalent rate under 3-sigma) and that the chart
  # statistic resets to zero at least sometimes.
  set.seed(2)
  Sigma <- matrix(c(1, 0.4, 0.4, 1), 2, 2)
  Z     <- MASS::mvrnorm(200, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:200, x1 = Z[, 1], x2 = Z[, 2])
  fit   <- shewhart_mcusum(df, vars = c(x1, x2), index = t,
                           target = c(0, 0), cov = Sigma)
  expect_lt(sum(fit$augmented$.flag_signal), 5)
  expect_gt(sum(fit$augmented$.y == 0), 0)
})

test_that("MCUSUM detects a sustained vector shift", {
  set.seed(3)
  Sigma <- matrix(c(1, 0.7, 0.7, 1), 2, 2)
  base  <- MASS::mvrnorm(60, c(0, 0), Sigma)
  shift <- MASS::mvrnorm(60, c(0.8, 0.8), Sigma)
  df    <- tibble::tibble(
    t  = 1:120,
    x1 = c(base[, 1], shift[, 1]),
    x2 = c(base[, 2], shift[, 2])
  )
  fit  <- shewhart_mcusum(df, vars = c(x1, x2), index = t,
                          target = c(0, 0), cov = Sigma)
  expect_gt(sum(fit$augmented$.flag_signal), 0)
  hits <- which(fit$augmented$.flag_signal)
  expect_gte(min(hits), 60L)         # signal lands in the post-shift segment
})

test_that("MCUSUM h-lookup returns NA outside the table", {
  expect_equal(shewhartr:::mcusum_h_lookup(0.5, 2L), 5.50)
  expect_equal(shewhartr:::mcusum_h_lookup(0.5, 10L), 10.43)
  expect_true(is.na(shewhartr:::mcusum_h_lookup(0.25, 2L)))
  expect_true(is.na(shewhartr:::mcusum_h_lookup(0.5, 11L)))
})

test_that("MCUSUM aborts with non-default k unless h is supplied", {
  set.seed(4)
  Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  Z     <- MASS::mvrnorm(40, c(0, 0), Sigma)
  df    <- tibble::tibble(t = 1:40, a = Z[, 1], b = Z[, 2])
  expect_error(
    shewhart_mcusum(df, vars = c(a, b), index = t,
                    target = c(0, 0), cov = Sigma, k = 0.25),
    "tabulated"
  )
  # But works when h is given explicitly:
  fit <- shewhart_mcusum(df, vars = c(a, b), index = t,
                         target = c(0, 0), cov = Sigma,
                         k = 0.25, h = 6)
  expect_equal(fit$metadata$h, 6)
})

test_that("MCUSUM Phase II continues from the calibration's last_S", {
  set.seed(5)
  Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  base  <- as.data.frame(MASS::mvrnorm(80, c(0, 0), Sigma))
  names(base) <- c("a", "b")
  cal   <- calibrate(base, vars = c(a, b), chart = "mcusum",
                     target = c(0, 0), cov = Sigma)
  # In-control new data: should not alarm
  set.seed(6)
  new_in <- as.data.frame(MASS::mvrnorm(40, c(0, 0), Sigma))
  names(new_in) <- c("a", "b")
  mon_in <- monitor(new_in, cal)
  expect_s3_class(mon_in, c("shewhart_mcusum", "shewhart_chart"))
  expect_equal(mon_in$phase, "phase_2")
  expect_lt(mean(mon_in$augmented$.flag_signal), 0.20)

  # Shifted new data: should alarm
  set.seed(7)
  new_bad <- as.data.frame(MASS::mvrnorm(40, c(1, 1), Sigma))
  names(new_bad) <- c("a", "b")
  mon_bad <- monitor(new_bad, cal)
  expect_gt(sum(mon_bad$augmented$.flag_signal), 0)
})
