test_that("p chart with constant n", {
  set.seed(1)
  df <- data.frame(
    day     = 1:30,
    defects = rbinom(30, size = 100, prob = 0.05),
    n       = 100
  )
  fit <- shewhart_p(df, defects = defects, n = n, index = day)
  expect_s3_class(fit, c("shewhart_p", "shewhart_chart"))
  expect_equal(unique(fit$augmented$.center), 0.05, tolerance = 0.05)
})

test_that("p chart rejects defects > n", {
  df <- data.frame(day = 1, defects = 150, n = 100)
  expect_error(
    shewhart_p(df, defects = defects, n = n, index = day),
    "cannot exceed"
  )
})

test_that("c chart with poisson limits is integer-valued", {
  set.seed(1)
  df <- data.frame(unit = 1:30, defects = rpois(30, 4))
  fit <- shewhart_c(df, defects = defects, index = unit, limits = "poisson")
  expect_equal(unique(fit$augmented$.upper),
               round(unique(fit$augmented$.upper)))
})

test_that("c chart warns at low c_bar with 3sigma", {
  set.seed(1)
  df <- data.frame(unit = 1:30, defects = rpois(30, 3))
  expect_warning(
    shewhart_c(df, defects = defects, index = unit, limits = "3sigma"),
    "small"
  )
})

test_that("u chart respects variable exposure", {
  set.seed(1)
  df <- data.frame(
    roll    = 1:25,
    defects = rpois(25, lambda = 4 * runif(25, 0.5, 1.5)),
    m2      = runif(25, 0.5, 1.5)
  )
  fit <- shewhart_u(df, defects = defects, exposure = m2, index = roll)
  # Limits vary with exposure -> not a single value
  expect_gt(length(unique(fit$augmented$.upper)), 1L)
})

test_that("np chart with constant n is integer-valued", {
  set.seed(1)
  df <- data.frame(day = 1:25, defects = rbinom(25, 200, 0.04))
  fit <- shewhart_np(df, defects = defects, n = 200, index = day)
  expect_s3_class(fit, "shewhart_np")
  expect_equal(unique(fit$augmented$.n), 200L)
})

# Audit 2026-09-25, finding 10: exact limits drive the flags -------------

test_that("c chart with Poisson limits flags against the plotted limits", {
  # c_bar = 2.07: 3-sigma UCL = 6.38, exact Poisson UCL = 7 (7 is in control)
  x <- c(rep(2, 29), 7)
  x[1:3] <- c(1, 1, 1)
  df <- data.frame(defects = x)
  fit3 <- suppressWarnings(shewhart_c(df, defects = defects))
  fitp <- shewhart_c(df, defects = defects, limits = "poisson")
  expect_true(fit3$augmented$.flag_any[30])
  ucl <- fitp$augmented$.upper[30]
  expect_equal(ucl, 7)
  expect_false(fitp$augmented$.flag_any[30])
  expect_equal(nrow(fitp$violations), 0L)

  # A value equal to the exact UCL is in control; one above it is not
  df2 <- data.frame(defects = c(x[1:28], ucl, ucl + 1))
  fit2 <- shewhart_c(df2, defects = defects, limits = "poisson")
  u2 <- fit2$augmented$.upper[1]
  expect_identical(fit2$augmented$.flag_any,
                   fit2$augmented$.value > u2 | fit2$augmented$.value < fit2$augmented$.lower[1])
  expect_identical(fit2$violations$position, which(fit2$augmented$.flag_any))
})

test_that("p chart with binomial limits flags against the plotted limits", {
  # p_bar = 0.1, n = 20: 3-sigma UCL = 0.301, exact binomial UCL = 0.35
  df <- data.frame(d = c(rep(2, 34), rep(1, 5), 7), n = 20)
  fit3 <- shewhart_p(df, defects = d, n = n)
  fit  <- shewhart_p(df, defects = d, n = n, limits = "binomial")
  expect_true(fit3$augmented$.flag_any[40])
  expect_false(fit$augmented$.flag_any[40])
  a <- fit$augmented
  expect_identical(a$.flag_any, a$.value > a$.upper | a$.value < a$.lower)
})

test_that("u chart with Poisson limits flags against the plotted limits", {
  set.seed(6)
  df <- data.frame(d = rpois(40, 2), e = runif(40, 0.8, 1.2))
  df$d[40] <- 7
  fit <- shewhart_u(df, defects = d, exposure = e, limits = "poisson")
  a <- fit$augmented
  expect_identical(a$.flag_any, a$.value > a$.upper | a$.value < a$.lower)
})

test_that("monitor() keeps the exact method of p / u / c charts", {
  set.seed(7)
  base <- data.frame(d = rbinom(30, 20, 0.1), n = 20)
  calib <- calibrate(base, defects = d, n = n, chart = "p",
                     limits = "binomial")
  mon <- monitor(data.frame(d = c(1, 2, 5), n = 20), calib)
  expect_equal(unique(mon$augmented$.upper), unique(calib$augmented$.upper))
  expect_equal(unique(mon$augmented$.lower), unique(calib$augmented$.lower))
  a <- mon$augmented
  expect_identical(a$.flag_any, a$.value > a$.upper | a$.value < a$.lower)

  base_u <- data.frame(d = rpois(30, 2), e = 1)
  cal_u  <- calibrate(base_u, defects = d, exposure = e, chart = "u",
                      limits = "poisson")
  mon_u  <- monitor(data.frame(d = c(1, 6, 8), e = 1), cal_u)
  expect_equal(unique(mon_u$augmented$.upper), unique(cal_u$augmented$.upper))
  a <- mon_u$augmented
  expect_identical(a$.flag_any, a$.value > a$.upper | a$.value < a$.lower)

  cal_c <- calibrate(data.frame(d = c(1, 1, 1, rep(2, 27))), defects = d,
                     chart = "c", limits = "poisson")
  mon_c <- monitor(data.frame(d = c(2, 7, 9)), cal_c)
  a <- mon_c$augmented
  expect_identical(a$.flag_any, a$.value > a$.upper | a$.value < a$.lower)
  expect_false(a$.flag_any[2])        # 7 is not above the exact UCL of 7
})

# Audit 2026-09-25, finding 32: p chart with n = 0 ---------------------------

test_that("p chart rejects n = 0 instead of producing NaN", {
  df <- data.frame(d = c(1, 0, 2), n = c(50, 0, 50))
  expect_error(shewhart_p(df, defects = d, n = n), "strictly positive")
  calib <- shewhart_p(data.frame(d = c(1, 2, 3), n = 50), defects = d, n = n)
  expect_error(monitor(df, calib), "strictly positive")
})
