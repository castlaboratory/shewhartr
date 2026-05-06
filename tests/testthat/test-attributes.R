test_that("p chart with constant n", {
  set.seed(1)
  df <- data.frame(
    day     = 1:30,
    defects = rbinom(30, size = 100, prob = 0.05),
    n       = 100
  )
  fit <- shewhart_p(df, defects = defects, n = n, index = day)
  expect_s3_class(fit, c("shewhart_p", "shewhart_chart"))
  expect_equal(unique(fit$augmented$.center), 0.05, tolerance = 0.02)
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
