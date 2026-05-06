test_that("loglog and iloglog roundtrip", {
  x <- c(0, 1, 5, 10, 100, 1000)
  expect_equal(iloglog(loglog(x)), x, tolerance = 1e-8)
})

test_that("box_cox and inv_box_cox roundtrip", {
  x <- 1:50
  for (lambda in c(-1, -0.5, 0, 0.5, 1, 2)) {
    expect_equal(inv_box_cox(box_cox(x, lambda), lambda), x,
                 tolerance = 1e-8)
  }
})

test_that("box_cox rejects non-positive input", {
  expect_error(box_cox(c(1, 2, 0), lambda = 0.5), "positive")
  expect_error(box_cox(c(1, -2),   lambda = 0.5), "positive")
})

test_that("shewhart_box_cox finds known lambda for log-normal data", {
  set.seed(1)
  x <- rlnorm(500, meanlog = 0, sdlog = 0.5)
  bc <- shewhart_box_cox(x, lambda_grid = seq(-1, 1, 0.05))
  expect_lt(abs(bc$lambda_hat), 0.2)   # ~0
})

test_that("locale fallback", {
  expect_equal(shewhartr:::tr("label_value", "en"), "Value")
  expect_equal(shewhartr:::tr("label_value", "pt"), "Valor")
  expect_equal(shewhartr:::tr("label_value", "es"), "Valor")
  expect_equal(shewhartr:::tr("label_value", "xx"), "Value")  # falls back
})

test_that("phase_n parameterised translation", {
  expect_equal(shewhartr:::tr("phase_n", "en", 3), "Phase 3")
  expect_equal(shewhartr:::tr("phase_n", "pt", 3), "Fase 3")
})
