# Numerical validation against the qcc package on its canonical
# example datasets. qcc has been the de-facto SPC package on CRAN for
# 15 years, so its limit calculations are well-vetted reference values
# for the classical Shewhart charts. Any divergence here is either a
# bug in shewhartr or a deliberate, documented design choice; in either
# case it should be made visible by these tests.
#
# All tests skip silently when qcc is not installed, since qcc is a
# Suggests dependency.

skip_if_not_installed("qcc")

# qcc datasets are lazy-loaded; not exported. Pull them into a local env
# without polluting the global one.
qcc_data <- function(name) {
  e <- new.env(parent = emptyenv())
  utils::data(list = name, package = "qcc", envir = e)
  e[[name]]
}

# Helper to collapse pistonrings into a wide matrix, like qcc::qcc.groups()
prepare_pistonrings <- function() {
  pr <- qcc_data("pistonrings")
  pr[pr$trial, ]
}

test_that("shewhart_xbar_r matches qcc on the pistonrings dataset", {
  pr <- prepare_pistonrings()
  qref <- qcc::qcc(qcc::qcc.groups(pr$diameter, pr$sample),
                   type = "xbar", plot = FALSE)
  fit <- shewhart_xbar_r(pr, value = diameter, subgroup = sample)

  expect_equal(unname(unique(fit$augmented$.center)), unname(qref$center),
               tolerance = 1e-5)
  expect_equal(unname(unique(fit$augmented$.upper)), unname(qref$limits[1, 2]),
               tolerance = 1e-3)
  expect_equal(unname(unique(fit$augmented$.lower)), unname(qref$limits[1, 1]),
               tolerance = 1e-3)
})

test_that("shewhart_xbar_r R-component matches qcc R chart", {
  pr <- prepare_pistonrings()
  qref <- qcc::qcc(qcc::qcc.groups(pr$diameter, pr$sample),
                   type = "R", plot = FALSE)
  fit <- shewhart_xbar_r(pr, value = diameter, subgroup = sample)

  expect_equal(unname(unique(fit$augmented$.r_center)), unname(qref$center),
               tolerance = 1e-4)
  expect_equal(unname(unique(fit$augmented$.r_upper)), unname(qref$limits[1, 2]),
               tolerance = 1e-3)
  expect_equal(unname(unique(fit$augmented$.r_lower)), unname(qref$limits[1, 1]),
               tolerance = 1e-4)
})

test_that("shewhart_xbar_s matches qcc on pistonrings (S chart)", {
  pr <- prepare_pistonrings()
  qref_xbar <- qcc::qcc(qcc::qcc.groups(pr$diameter, pr$sample),
                        type = "xbar.one", plot = FALSE,
                        std.dev = "SD")
  qref_s    <- qcc::qcc(qcc::qcc.groups(pr$diameter, pr$sample),
                        type = "S", plot = FALSE)
  fit <- shewhart_xbar_s(pr, value = diameter, subgroup = sample)

  expect_equal(unname(unique(fit$augmented$.s_center)),
               unname(qref_s$center), tolerance = 1e-4)
  expect_equal(unname(unique(fit$augmented$.s_upper)),
               unname(qref_s$limits[1, 2]), tolerance = 1e-3)
  expect_equal(unname(unique(fit$augmented$.s_lower)),
               unname(qref_s$limits[1, 1]), tolerance = 1e-4)
})

test_that("shewhart_p matches qcc on the orangejuice dataset", {
  oj <- qcc_data("orangejuice")[qcc_data("orangejuice")$trial, ]
  qref <- qcc::qcc(oj$D, sizes = oj$size, type = "p", plot = FALSE)
  fit  <- shewhart_p(oj, defects = D, n = size, index = sample)

  expect_equal(unname(unique(fit$augmented$.center)),
               unname(qref$center), tolerance = 1e-5)
  # Upper / lower limits depend on n (constant here -> single value)
  expect_equal(unname(unique(fit$augmented$.upper))[1L],
               unname(qref$limits[1L, 2L]), tolerance = 1e-4)
  expect_equal(unname(unique(fit$augmented$.lower))[1L],
               unname(qref$limits[1L, 1L]), tolerance = 1e-4)
})

test_that("shewhart_np matches qcc on the orangejuice dataset", {
  oj <- qcc_data("orangejuice")[qcc_data("orangejuice")$trial, ]
  qref <- qcc::qcc(oj$D, sizes = oj$size, type = "np", plot = FALSE)
  fit  <- shewhart_np(oj, defects = D, n = oj$size[1L], index = sample)

  expect_equal(unname(unique(fit$augmented$.center)),
               unname(qref$center), tolerance = 1e-4)
  expect_equal(unname(unique(fit$augmented$.upper))[1L],
               unname(qref$limits[1L, 2L]), tolerance = 1e-3)
})

test_that("shewhart_c (3sigma) matches qcc on the circuit dataset", {
  cc <- qcc_data("circuit")[qcc_data("circuit")$trial, ]
  qref <- qcc::qcc(cc$x, type = "c", plot = FALSE)
  cc$row <- seq_len(nrow(cc))
  fit  <- shewhart_c(cc, defects = x, index = row, limits = "3sigma")

  expect_equal(unname(unique(fit$augmented$.center)),
               unname(qref$center), tolerance = 1e-4)
  expect_equal(unname(unique(fit$augmented$.upper)),
               unname(qref$limits[1L, 2L]), tolerance = 1e-3)
  expect_equal(unname(unique(fit$augmented$.lower)),
               unname(qref$limits[1L, 1L]), tolerance = 1e-3)
})

test_that("shewhart_i_mr matches qcc xbar.one on a single series", {
  set.seed(42)
  v   <- rnorm(60, mean = 100, sd = 2)
  df  <- data.frame(t = seq_along(v), y = v)
  qref <- qcc::qcc(v, type = "xbar.one", plot = FALSE)
  fit  <- shewhart_i_mr(df, value = y, index = t)

  expect_equal(unname(unique(fit$augmented$.center)),
               unname(qref$center), tolerance = 1e-6)
  expect_equal(unname(unique(fit$augmented$.upper)),
               unname(qref$limits[1L, 2L]), tolerance = 1e-3)
  expect_equal(unname(unique(fit$augmented$.lower)),
               unname(qref$limits[1L, 1L]), tolerance = 1e-3)
})
