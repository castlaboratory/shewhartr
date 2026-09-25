
# Audit 2026-09-25: plotting findings 12, 20, 36 ----------------------------

ten_phase_fit <- function(locale = "en") {
  set.seed(1)
  df <- data.frame(t = 1:100, y = 50 + cumsum(rnorm(100, 0.5, 1)))
  shewhart_regression(df, value = y, index = t, model = "linear",
                      phase_changes = seq(11, 91, by = 10), locale = locale)
}

test_that("issue #1: a 10-phase legend fits in a 7-inch device", {
  fit <- ten_phase_fit()
  p   <- ggplot2::autoplot(fit)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  g   <- ggplot2::ggplotGrob(p)
  box <- g$grobs[[which(g$layout$name == "guide-box-top")]]
  w   <- grid::convertWidth(sum(box$widths), "in", valueOnly = TRUE)
  expect_lt(w, 7)
  expect_equal(legend_nrow(10), 2L)
  expect_equal(legend_nrow(5), 1L)
})

test_that("regression legend uses .phase_label", {
  fit <- ten_phase_fit()
  p   <- ggplot2::autoplot(fit)
  b   <- ggplot2::ggplot_build(p)
  lbls <- levels(p$data$.phase_f)
  expect_equal(lbls[1], "Base")
  expect_equal(lbls[length(lbls)], "Monitoring")
  expect_setequal(lbls, unique(fit$augmented$.phase_label))

  # Locale override rebuilds the labels in the requested language
  p_pt <- ggplot2::autoplot(fit, locale = "pt")
  expect_equal(levels(p_pt$data$.phase_f)[c(1, 10)],
               c(tr("phase_base", "pt"), tr("phase_monitoring", "pt")))
})

test_that("regression subtitle and CUSUM legend are localised", {
  fit <- ten_phase_fit(locale = "pt")
  p   <- ggplot2::autoplot(fit)
  expect_match(p$labels$subtitle, "modelo linear", fixed = TRUE)
  expect_match(p$labels$subtitle, "10 fases", fixed = TRUE)

  set.seed(2)
  cs <- shewhart_cusum(data.frame(y = rnorm(40)), value = y, locale = "pt")
  pc <- ggplot2::autoplot(cs)
  expect_setequal(unique(pc$data$cusum_kind), c("Positivo", "Negativo"))
  pc_en <- ggplot2::autoplot(cs, locale = "en")
  expect_setequal(unique(pc_en$data$cusum_kind), c("Positive", "Negative"))
})

test_that("show_sigma_zones draws zones on the top panel of two-panel charts", {
  set.seed(3)
  n_ribbons <- function(p) {
    sum(vapply(p$layers, function(l) inherits(l$geom, "GeomRibbon"),
               logical(1L)))
  }
  fi <- shewhart_i_mr(data.frame(y = rnorm(40)), value = y)
  fx <- shewhart_xbar_r(data.frame(g = rep(1:20, each = 4), y = rnorm(80)),
                        value = y, subgroup = g)
  fs <- shewhart_xbar_s(data.frame(g = rep(1:20, each = 4), y = rnorm(80)),
                        value = y, subgroup = g)
  for (fit in list(fi, fx, fs)) {
    on  <- ggplot2::autoplot(fit, show_sigma_zones = TRUE)
    off <- ggplot2::autoplot(fit)
    expect_equal(n_ribbons(on$top), 2L)
    expect_equal(n_ribbons(off$top), 0L)
    expect_equal(n_ribbons(on$bottom), 0L)
  }
})
