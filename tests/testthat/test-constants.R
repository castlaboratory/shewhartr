test_that("shewhart_constants returns Montgomery (2019) values", {
  # Spot-check key values for n = 5 (Montgomery, Appendix VI)
  k <- shewhart_constants(5)
  expect_equal(k$A2, 0.577, tolerance = 1e-3)
  expect_equal(k$A3, 1.427, tolerance = 1e-3)
  expect_equal(k$c4, 0.9400, tolerance = 1e-4)
  expect_equal(k$d2, 2.326, tolerance = 1e-3)
  expect_equal(k$D3, 0,     tolerance = 1e-3)
  expect_equal(k$D4, 2.114, tolerance = 1e-3)
  expect_equal(k$B3, 0,     tolerance = 1e-3)
  expect_equal(k$B4, 2.089, tolerance = 1e-3)
})

test_that("c4_exact agrees with the tabulated values", {
  for (n in 2:25) {
    expected <- shewhart_constants(n)$c4
    expect_equal(shewhartr:::c4_exact(n), expected, tolerance = 1e-3)
  }
})

test_that("vector input works", {
  k <- shewhart_constants(c(2, 5, 10))
  expect_equal(nrow(k), 3L)
  expect_equal(k$n, c(2L, 5L, 10L))
})

test_that("invalid input is rejected", {
  expect_error(shewhart_constants(1),     "at least 2")
  expect_error(shewhart_constants("foo"), "must be numeric")
})
