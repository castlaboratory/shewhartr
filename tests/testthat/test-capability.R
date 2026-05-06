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
