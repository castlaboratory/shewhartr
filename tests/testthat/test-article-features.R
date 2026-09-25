# Features for reproducing Ferraz et al. (2020) -- issues #2 and #3 ------

exp_counts <- function(n = 60, seed = 11) {
  set.seed(seed)
  t <- seq_len(n)
  data.frame(
    t = t,
    date = as.Date("2020-03-17") + t - 1L,
    y = stats::rpois(n, lambda = exp(1 + 0.06 * t))
  )
}

test_that("limits_scale = 'model' builds multiplicative, asymmetric log bands", {
  d   <- exp_counts()
  fit <- shewhart_regression(d, value = y, index = t, model = "log",
                             limits_scale = "model", phase_changes = 31)
  a <- fit$augmented
  pos <- a$.center > 0
  expect_true(all((a$.upper - a$.center)[pos] > (a$.center - a$.lower)[pos]))
  # No lower_bound needed: the back-transformed lower limit is >= 0
  expect_true(all(a$.lower >= 0))
  expect_equal(fit$metadata$limits_scale, "model")
  expect_true(all(c(".model_value", ".model_center") %in% names(a)))

  # Hand computation of the base phase (Perla et al. 2020, steps i-v)
  base <- d[1:30, ]
  base$N <- seq_len(30)
  lf <- stats::lm(log(y + 1) ~ N, data = base)
  e  <- stats::residuals(lf)
  s  <- mean(abs(diff(e))) / 1.128
  g  <- stats::fitted(lf)
  expect_equal(a$.sigma[1:30], rep(s, 30))
  expect_equal(a$.center[1:30], unname(exp(g) - 1))
  expect_equal(a$.upper[1:30], unname(exp(g + 3 * s) - 1))
  expect_equal(a$.lower[1:30], unname(pmax(0, exp(g - 3 * s) - 1)))
  expect_equal(fit$metadata$phase_sigma[1], s)

  # The default keeps the symmetric, original-scale band
  orig <- shewhart_regression(d, value = y, index = t, model = "log",
                              phase_changes = 31)
  expect_equal(orig$metadata$limits_scale, "original")
  expect_equal(orig$augmented$.upper - orig$augmented$.center,
               orig$augmented$.center - orig$augmented$.lower)
  expect_false(".model_value" %in% names(orig$augmented))
})

test_that("limits_scale is a no-op for models without a transformed response", {
  set.seed(2)
  d <- data.frame(t = 1:50, y = 0.3 * (1:50) + rnorm(50))
  a <- shewhart_regression(d, value = y, index = t, model = "linear",
                           phase_changes = 26)
  b <- shewhart_regression(d, value = y, index = t, model = "linear",
                           phase_changes = 26, limits_scale = "model")
  expect_equal(a$augmented$.upper, b$augmented$.upper)
  expect_equal(a$augmented$.lower, b$augmented$.lower)
  expect_equal(a$augmented$.sigma, b$augmented$.sigma)
})

test_that("runs rules run on the model scale with limits_scale = 'model'", {
  d <- exp_counts()
  d$y[40] <- d$y[40] * 4L
  fit <- shewhart_regression(d, value = y, index = t, model = "log",
                             limits_scale = "model", phase_changes = 31,
                             rules = "nelson_1_beyond_3s")
  a <- fit$augmented
  outside <- a$.value > a$.upper | a$.value < a$.lower
  expect_equal(a$.flag_nelson_1_beyond_3s, outside)
  expect_true(40L %in% fit$violations$position)
})

test_that("a formula with a log left-hand side matches model = 'log'", {
  d <- exp_counts()
  menu <- shewhart_regression(d, value = y, index = t, model = "log",
                              limits_scale = "model", phase_changes = 31)
  frm  <- shewhart_regression(d, value = y, index = t,
                              formula = log(y + 1) ~ .N,
                              limits_scale = "model", phase_changes = 31)
  expect_equal(frm$augmented$.center, menu$augmented$.center)
  expect_equal(frm$augmented$.upper,  menu$augmented$.upper)
  # log10 gives the same chart: the base of the logarithm cancels
  f10 <- shewhart_regression(d, value = y, index = t,
                             formula = I(log10(1 + y)) ~ .N,
                             limits_scale = "model", phase_changes = 31)
  expect_equal(f10$augmented$.upper, menu$augmented$.upper)
  expect_equal(f10$augmented$.lower[menu$augmented$.lower > 0],
               menu$augmented$.lower[menu$augmented$.lower > 0])

  expect_error(
    shewhart_regression(d, value = y, index = t, formula = exp(y) ~ .N,
                        limits_scale = "model", phase_changes = 31),
    "invertible"
  )
})

test_that("parse_lhs_transform() inverts what it recognises", {
  y <- c(0, 1, 5, 40)
  for (f in list(log(y) ~ .N, log(y + 2) ~ .N, I(log(1 + y, base = 10)) ~ .N,
                 log2(y + 1) ~ .N, log1p(y) ~ .N, sqrt(y) ~ .N,
                 log(y - -3) ~ .N)) {
    tf <- parse_lhs_transform(f, "y")
    expect_true(tf$known)
    yy <- if (identical(f[[2L]], quote(log(y)))) y[-1] else y
    expect_equal(tf$inverse(tf$forward(yy)), yy)
  }
  expect_true(parse_lhs_transform(y ~ .N, "y")$identity)
  expect_false(parse_lhs_transform(log(x) ~ .N, "y")$known)
  expect_false(parse_lhs_transform(exp(y) ~ .N, "y")$known)
})

test_that("monitor() continues the model-scale band exactly (audit #2 / #4)", {
  d   <- exp_counts(70)
  # A last phase of 2 rows inherits the previous fit and sigma: it is
  # the constructor's own projection of phase 1.
  full <- shewhart_regression(d, value = y, index = t, model = "log",
                              limits_scale = "model", lower_bound = 1,
                              phase_changes = c(31, 69))
  cal  <- calibrate(d[1:68, ], chart = "regression", value = y, index = t,
                    model = "log", limits_scale = "model", lower_bound = 1,
                    phase_changes = 31)
  mon  <- monitor(d[69:70, ], cal)
  proj <- full$augmented[69:70, ]
  expect_equal(mon$augmented$.center, proj$.center)
  expect_equal(mon$augmented$.upper,  proj$.upper)
  expect_equal(mon$augmented$.lower,  proj$.lower)
  expect_equal(mon$augmented$.sigma,  proj$.sigma)
  expect_equal(mon$augmented$.model_center, proj$.model_center)

  # The same projection, checked against the stored fit by hand
  mon2 <- monitor(d[69:70, ], cal)
  k    <- length(cal$fits)
  s    <- cal$metadata$phase_sigma[k]
  g    <- unname(stats::predict(cal$fits[[k]],
                                newdata = data.frame(.N = 38 + 1:2)))
  expect_equal(mon2$augmented$.upper, exp(g + 3 * s) - 1)
  expect_equal(mon2$augmented$.lower, pmax(1, exp(g - 3 * s) - 1))
})

test_that("a single-phase calibration drives a prospective replay", {
  d   <- exp_counts(40)
  cal <- calibrate(d[1:10, ], chart = "regression", value = y, index = date,
                   model = "log", limits_scale = "model",
                   phase_changes = integer(0), rules = "we_seven_same")
  expect_length(cal$fits, 1L)
  expect_equal(cal$metadata$phase_n_end, 10L)
  mon <- monitor(d[11:40, ], cal)
  expect_true(".flag_we_seven_same" %in% names(mon$augmented))
  g <- unname(stats::predict(cal$fits[[1]], newdata = data.frame(.N = 11:40)))
  expect_equal(mon$augmented$.center, exp(g) - 1)
  # Fewer than 3 rows cannot fit a phase
  expect_error(
    shewhart_regression(d[1:2, ], value = y, index = t,
                        phase_changes = integer(0)),
    "at least"
  )
})

test_that("log-type models reject negative counts with a clear error", {
  d <- exp_counts()
  d$y[45] <- -37L
  for (m in c("log", "loglog")) {
    expect_error(shewhart_regression(d, value = y, index = date, model = m),
                 "non-negative", class = "rlang_error")
  }
  expect_error(
    shewhart_regression(d, value = y, index = date, model = "log"),
    "2020-04-30"
  )
  pe <- cvd_brazil[cvd_brazil$region == "PE", ]
  expect_error(shewhart_regression(pe, value = new_deaths, index = date,
                                   model = "log"), "-37")
  expect_error(shewhart_regression(pe, value = new_deaths, index = date,
                                   model = "auto"), "non-negative")
  # Phase II too
  cal <- calibrate(exp_counts()[1:40, ], chart = "regression", value = y,
                   index = t, model = "log", phase_changes = 21)
  bad <- exp_counts()[41:45, ]
  bad$y[2] <- -1L
  expect_error(monitor(bad, cal), "non-negative")
})

test_that(".phase_label carries end dates for a Date index", {
  d   <- exp_counts()
  fit <- shewhart_regression(d, value = y, index = date, model = "log",
                             phase_changes = as.Date(c("2020-04-06",
                                                       "2020-04-26")))
  lbl <- unique(fit$augmented$.phase_label)
  expect_equal(lbl, c("Base (until 2020-04-05)",
                      "Phase 1 (until 2020-04-25)",
                      "Monitoring"))
  fit_pt <- shewhart_regression(d, value = y, index = date, model = "log",
                                phase_changes = as.Date("2020-04-06"),
                                locale = "pt")
  expect_equal(unique(fit_pt$augmented$.phase_label),
               c("Base (at\u00e9 2020-04-05)", "Monitoramento"))
  expect_equal(tr("phase_until", "es", "Fase 1", "x"), "Fase 1 (hasta x)")
  expect_equal(tr("phase_until", "fr", "Phase 1", "x"),
               "Phase 1 (jusqu'au x)")

  # Numeric index: no dates by default
  num <- shewhart_regression(d, value = y, index = t, model = "log",
                             phase_changes = 21)
  expect_equal(unique(num$augmented$.phase_label), c("Base", "Monitoring"))
})

test_that("autoplot() phase_dates and legend_position", {
  d   <- exp_counts()
  fit <- shewhart_regression(d, value = y, index = date, model = "log",
                             limits_scale = "model",
                             phase_changes = as.Date(c("2020-04-06",
                                                       "2020-04-26")))
  p <- ggplot2::autoplot(fit)
  expect_equal(levels(p$data$.phase_f)[1], "Base (until 2020-04-05)")
  p0 <- ggplot2::autoplot(fit, phase_dates = FALSE)
  expect_equal(levels(p0$data$.phase_f), c("Base", "Phase 1", "Monitoring"))
  p_pt <- ggplot2::autoplot(fit, locale = "pt")
  expect_equal(levels(p_pt$data$.phase_f)[2], "Fase 1 (at\u00e9 2020-04-25)")
  num <- shewhart_regression(d, value = y, index = t, model = "log",
                             phase_changes = 21)
  p_num <- ggplot2::autoplot(num, phase_dates = TRUE)
  expect_equal(levels(p_num$data$.phase_f), c("Base (until 20)", "Monitoring"))
  expect_error(ggplot2::autoplot(fit, phase_dates = NA), "phase_dates")

  pin <- ggplot2::autoplot(fit, legend_position = "inside")
  expect_equal(pin$theme$legend.position, "inside")
  expect_equal(pin$theme$legend.justification.inside, c(0, 1))
  expect_error(ggplot2::autoplot(fit, legend_position = "left"))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(ggplot2::ggplotGrob(pin))
})

test_that("dated legends of many phases wrap and fit a 7-inch device", {
  set.seed(1)
  df <- data.frame(date = as.Date("2020-03-01") + 0:99,
                   y = 50 + cumsum(rnorm(100, 0.5, 1)))
  fit <- shewhart_regression(df, value = y, index = date, model = "linear",
                             phase_changes = df$date[seq(11, 91, by = 10)])
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (loc in c("en", "pt", "fr")) {
    g   <- ggplot2::ggplotGrob(ggplot2::autoplot(fit, locale = loc))
    box <- g$grobs[[which(g$layout$name == "guide-box-top")]]
    w   <- grid::convertWidth(sum(box$widths), "in", valueOnly = TRUE)
    expect_lt(w, 7)
  }
  gi <- ggplot2::ggplotGrob(ggplot2::autoplot(fit, legend_position = "inside"))
  expect_true("guide-box-inside" %in% gi$layout$name)
  expect_equal(legend_nrow(10, 3L), 4L)
})

test_that("cvd_brazil has the documented shape", {
  expect_s3_class(cvd_brazil, "tbl_df")
  expect_named(cvd_brazil, c("date", "region", "new_deaths"))
  expect_s3_class(cvd_brazil$date, "Date")
  expect_equal(levels(cvd_brazil$region), c("BR", "PE", "SP"))
  expect_type(cvd_brazil$new_deaths, "integer")
  expect_equal(nrow(cvd_brazil), 917L)
  expect_equal(range(cvd_brazil$date), as.Date(c("2020-02-25", "2020-12-31")))
  expect_false(anyDuplicated(cvd_brazil[c("region", "date")]) > 0)
  neg <- cvd_brazil[cvd_brazil$new_deaths < 0, ]
  expect_equal(nrow(neg), 1L)
  expect_equal(as.character(neg$region), "PE")
  expect_equal(neg$new_deaths, -37L)
})
