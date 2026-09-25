test_that("shewhart_capability returns the four indices", {
  set.seed(1)
  x <- rnorm(200, mean = 50, sd = 1)
  cap <- shewhart_capability(x, lsl = 47, usl = 53,
                             ci_level = NA)   # skip bootstrap for speed
  expect_s3_class(cap, "shewhart_capability")
  expect_true(all(c("Cp", "Cpk", "Pp", "Ppk") %in% names(cap)))
  expect_true(is.finite(cap$Cp))
  expect_true(is.finite(cap$Cpk))
})

test_that("Cp = Pp when within == total sigma (raw vector)", {
  set.seed(1)
  x <- rnorm(200, mean = 50, sd = 1)
  cap <- shewhart_capability(x, lsl = 47, usl = 53, ci_level = NA)
  expect_equal(cap$Cp, cap$Pp, tolerance = 1e-6)
})

test_that("Bootstrap CI works", {
  set.seed(1)
  x <- rnorm(200, mean = 50, sd = 1)
  cap <- shewhart_capability(x, lsl = 47, usl = 53,
                             ci_level = 0.95, n_boot = 200, seed = 1)
  expect_false(is.null(cap$ci))
  expect_equal(dim(cap$ci), c(2L, 4L))
  # Lower bound less than point estimate, upper greater
  expect_lt(cap$ci[1L, "Cp"], cap$Cp)
  expect_gt(cap$ci[2L, "Cp"], cap$Cp)
})

test_that("tidy method returns a tibble with the right columns", {
  cap <- shewhart_capability(rnorm(100), lsl = -3, usl = 3,
                             ci_level = 0.95, n_boot = 200, seed = 1)
  td <- broom::tidy(cap)
  expect_s3_class(td, "tbl_df")
  expect_true(all(c("index", "estimate") %in% names(td)))
  expect_equal(nrow(td), 4L)
})

test_that("Missing both lsl and usl errors", {
  expect_error(
    shewhart_capability(rnorm(50)),
    "At least one of"
  )
})

# Audit 2026-09-25, finding 2 ------------------------------------------------

test_that("capability on Xbar-R uses sigma_hat directly and individual data", {
  set.seed(11)
  df <- data.frame(batch = rep(1:30, each = 5),
                   y     = rnorm(150, mean = 50, sd = 1.5))
  fit <- shewhart_xbar_r(df, value = y, subgroup = batch)
  cap <- suppressWarnings(
    shewhart_capability(fit, lsl = 45, usl = 55, ci_level = NA)
  )
  # Cp uses the chart's per-individual sigma (R-bar / d2), not * sqrt(n)
  expect_equal(cap$sigma_w, fit$sigma_hat)
  expect_equal(cap$Cp, 10 / (6 * fit$sigma_hat))
  # Pp / mean from the 150 individual measurements, not the 30 means
  expect_equal(cap$n, 150L)
  expect_equal(cap$sigma_t, stats::sd(df$y))
  expect_equal(cap$mean, mean(df$y))
  expect_gt(cap$Cp, 0.9)            # true Cp = 1.11; old code gave ~0.5
})

test_that("capability on Xbar-S with identical subgroup means is finite", {
  # Every subgroup has the same mean, so Pp based on the means was Inf
  set.seed(10)
  df <- data.frame(batch = rep(1:12, each = 4),
                   y     = 10 + rep(c(-1, -0.3, 0.3, 1), 12) *
                                rep(runif(12, 0.5, 1.5), each = 4))
  fit <- shewhart_xbar_s(df, value = y, subgroup = batch)
  cap <- suppressWarnings(
    shewhart_capability(fit, lsl = 7, usl = 13, ci_level = NA)
  )
  expect_true(is.finite(cap$Pp))
  expect_equal(cap$sigma_t, stats::sd(df$y))
  expect_equal(cap$sigma_w, fit$sigma_hat)
})

test_that("capability on a Phase II Xbar chart uses the monitored data", {
  set.seed(12)
  base <- data.frame(g = rep(1:20, each = 5), y = rnorm(100, 10, 1))
  new  <- data.frame(g = rep(1:10, each = 5), y = rnorm(50, 10, 1))
  calib <- calibrate(base, value = y, subgroup = g, chart = "xbar_r")
  mon   <- monitor(new, calib)
  cap <- suppressWarnings(
    shewhart_capability(mon, lsl = 6, usl = 14, ci_level = NA)
  )
  expect_equal(cap$n, 50L)
  expect_equal(cap$mean, mean(new$y))
})

test_that("capability rejects chart types where it is undefined", {
  df <- data.frame(d = c(3, 4, 5, 2, 6, 4, 3, 5, 4, 2), n = 100)
  fit <- shewhart_p(df, defects = d, n = n)
  expect_error(shewhart_capability(fit, lsl = 0, usl = 0.1, ci_level = NA),
               "not defined")
})

# Audit 2026-09-25, finding 24 -----------------------------------------------

test_that("bootstrap CI for Cp re-estimates sigma within (I-MR)", {
  # Slow drift: MR-based sigma within is much smaller than the overall SD,
  # so an SD-based bootstrap puts the whole Cp interval below the point.
  set.seed(3)
  y   <- 50 + seq(-2, 2, length.out = 120) + rnorm(120, sd = 0.3)
  fit <- shewhart_i_mr(data.frame(y = y), value = y)
  cap <- suppressWarnings(
    shewhart_capability(fit, lsl = 45, usl = 55, n_boot = 400, seed = 1)
  )
  expect_gt(cap$Cp, cap$Pp * 2)
  expect_lt(cap$ci[1L, "Cp"], cap$Cp)
  expect_gt(cap$ci[2L, "Cp"], cap$Cp)
  expect_lt(cap$ci[1L, "Cpk"], cap$Cpk)
  expect_gt(cap$ci[2L, "Cpk"], cap$Cpk)
})

test_that("bootstrap CI for Cp re-estimates sigma within (Xbar-R)", {
  # Large between-subgroup variation: sigma within << overall SD
  set.seed(4)
  shift <- rep(rnorm(25, sd = 2), each = 5)
  df <- data.frame(g = rep(1:25, each = 5), y = 100 + shift + rnorm(125, sd = 0.5))
  fit <- shewhart_xbar_r(df, value = y, subgroup = g)
  cap <- suppressWarnings(
    shewhart_capability(fit, lsl = 95, usl = 105, n_boot = 400, seed = 1)
  )
  expect_gt(cap$Cp, cap$Pp * 2)
  expect_lt(cap$ci[1L, "Cp"], cap$Cp)
  expect_gt(cap$ci[2L, "Cp"], cap$Cp)
})
