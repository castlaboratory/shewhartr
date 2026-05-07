# autoplot methods --------------------------------------------------------
#
# Each chart subclass dispatches to the right plotting routine. All
# routines use a shared theme and respect the chart's `metadata$locale`
# for axis labels.

#' Editorial-style ggplot2 theme used by every `autoplot.shewhart_*`
#'
#' Shared across the package so charts look like one family. The
#' visual choices are inspired by data-journalism graphics (FT, Pew
#' Research, The Economist): off-white background, only horizontal
#' grid lines, axis line on the data side, left-aligned title block,
#' and tonal grey for non-data ink.
#'
#' Use it from your own layers when you want a chart that matches
#' the package's identity:
#'
#' ```
#' ggplot(d, aes(x, y)) + geom_line() + shewhart_theme()
#' ```
#'
#' @param base_size Base font size, in points.
#' @param base_family Base font family. Empty string uses the system
#'   default sans-serif. We do not hard-code a Google Font so the
#'   theme works in offline / CRAN-check environments.
#'
#' @return A `ggplot2::theme()` object.
#'
#' @examples
#' library(ggplot2)
#' df <- data.frame(x = 1:50, y = cumsum(rnorm(50)))
#' ggplot(df, aes(x, y)) + geom_line() + shewhart_theme()
#' @export
shewhart_theme <- function(base_size = 10.5, base_family = "") {
  pal <- shewhart_palette("neutral")
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      # Surfaces
      plot.background  = ggplot2::element_rect(fill = pal["bg_plot"], colour = NA),
      panel.background = ggplot2::element_rect(fill = pal["bg_panel"], colour = NA),

      # Grid: a single horizontal whisper, matched to the data axis.
      panel.grid.major.y = ggplot2::element_line(colour = pal["grid"], linewidth = 0.4),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.minor   = ggplot2::element_blank(),

      # Axes: line on the data side only, short ticks, muted text.
      axis.line.x  = ggplot2::element_line(colour = pal["axis_line"], linewidth = 0.4),
      axis.line.y  = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_line(colour = pal["axis_line"], linewidth = 0.4),
      axis.ticks.y = ggplot2::element_blank(),
      axis.ticks.length = ggplot2::unit(3, "pt"),
      axis.text  = ggplot2::element_text(colour = pal["text_med"],
                                         size   = ggplot2::rel(0.82)),
      axis.title = ggplot2::element_text(colour = pal["text_med"],
                                         size   = ggplot2::rel(0.85)),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 6)),
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 6)),

      # Title block: left-aligned to the plot edge (FT/Pew style).
      plot.title = ggplot2::element_text(
        colour = pal["text_high"], face = "bold",
        size = ggplot2::rel(1.18),
        margin = ggplot2::margin(b = 4),
        hjust = 0
      ),
      plot.subtitle = ggplot2::element_text(
        colour = pal["text_low"],
        size = ggplot2::rel(0.9),
        margin = ggplot2::margin(b = 12),
        hjust = 0
      ),
      plot.caption = ggplot2::element_text(
        colour = pal["text_xlow"],
        size = ggplot2::rel(0.74),
        hjust = 0,
        margin = ggplot2::margin(t = 10)
      ),
      plot.title.position    = "plot",
      plot.caption.position  = "plot",

      # Legend: top-left, bold title, slightly smaller than data text.
      legend.background    = ggplot2::element_blank(),
      legend.key           = ggplot2::element_blank(),
      legend.title         = ggplot2::element_text(colour = pal["text_med"],
                                                   size   = ggplot2::rel(0.82),
                                                   face   = "bold"),
      legend.text          = ggplot2::element_text(colour = pal["text_med"],
                                                   size   = ggplot2::rel(0.8)),
      legend.position      = "top",
      legend.justification = "left",
      legend.box.spacing   = ggplot2::unit(2, "pt"),

      # Strip (facets): no panel, just a bold label.
      strip.background = ggplot2::element_blank(),
      strip.text       = ggplot2::element_text(colour = pal["text_med"],
                                               face   = "bold"),

      plot.margin = ggplot2::margin(t = 12, r = 16, b = 10, l = 12)
    )
}

#' Build the two ggplot2 layers that mark a violation
#'
#' Centralised so every autoplot in the package uses the same shape,
#' size and colour for an out-of-control point. Returns two layers in
#' a list: a solid white halo, then a hollow ring in the package's
#' `out_of_control` colour.
#'
#' @param data A data frame already filtered to the violating rows.
#' @param y A bare column name (passed via tidy-eval) for the
#'   y-aesthetic. Defaults to `.value`.
#' @param halo,ring,stroke Numeric scalars overriding the default
#'   sizes when needed (e.g. the regression chart with shaded bands
#'   wants slightly different sizing). Defaults match the rest of
#'   the family.
#'
#' @keywords internal
#' @noRd
violation_layers <- function(data, y_col = ".value",
                             halo = 1.7, ring = 1.4, stroke = 0.7) {
  signal <- shewhart_palette("signal")
  list(
    ggplot2::geom_point(
      data = data,
      ggplot2::aes(y = .data[[y_col]]),
      colour = "white", size = halo, stroke = 0
    ),
    ggplot2::geom_point(
      data = data,
      ggplot2::aes(y = .data[[y_col]]),
      colour = signal["out_of_control"], fill = NA,
      shape = 21, size = ring, stroke = stroke
    )
  )
}

#' @keywords internal
#' @noRd
shewhart_phase_label <- function(phase, locale = "en") {
  # Localised label like "Phase 1" / "Fase 1"; phase 0 (the baseline /
  # calibration window) becomes "Phase 0 - Baseline" so the legend tells
  # the reader what is happening.
  template <- tr("phase_n", locale)
  out <- vapply(phase,
                function(p) sprintf(template, as.integer(p)),
                character(1L))
  out
}

#' @keywords internal
#' @noRd
get_index_col <- function(aug, fallback = ".obs", chart = NULL) {
  # If the chart object has metadata, use the index column the user
  # named when constructing it. Otherwise fall back to the first
  # non-internal column, then to .obs. Note that "internal" only
  # excludes columns the package adds itself (.value, .center, .upper,
  # ...); a user index column may legitimately start with a dot
  # (cvd_recife has a `.t` column), so we never reject it on shape.
  if (!is.null(chart) && !is.null(chart$metadata$index_name) &&
      chart$metadata$index_name %in% names(aug)) {
    return(chart$metadata$index_name)
  }
  internal <- c(".obs", ".value", ".center", ".sigma", ".upper", ".lower",
                ".fitted", ".phase", ".phase_f", ".phase_label", ".N",
                ".ewma", ".cusum_pos", ".cusum_neg", ".t2",
                ".mr", ".mr_center", ".mr_upper", ".mr_lower",
                ".range", ".r_center", ".r_upper", ".r_lower",
                ".s", ".s_center", ".s_upper", ".s_lower",
                ".flag_signal", ".flag_any")
  candidates <- setdiff(names(aug), internal)
  candidates <- candidates[!grepl("^\\.flag_", candidates) &
                           !grepl("^\\.contrib_", candidates)]
  if (length(candidates) > 0L) candidates[1L] else fallback
}

#' Plot a Shewhart chart with ggplot2
#'
#' Generic `autoplot` method that dispatches on chart subclass. All
#' versions return a `ggplot` object that the user can further
#' customise with the usual ggplot2 grammar.
#'
#' @param object A [shewhart_chart] object.
#' @param show_violations Logical. Highlight violations with red points?
#'   Default `TRUE`.
#' @param show_sigma_zones Logical. Show 1- and 2-sigma zones as
#'   shaded bands? Default `FALSE`.
#' @param locale Optional override for the chart's stored locale.
#' @param ... Passed to subclass-specific methods.
#'
#' @return A `ggplot` object (or, for I-MR / Xbar-R / Xbar-S charts,
#'   a list of two `ggplot` objects with class `shewhart_plot_pair`
#'   that prints them stacked).
#'
#' @examples
#' \donttest{
#' fit <- shewhart_i_mr(data.frame(y = rnorm(50)), value = y)
#' ggplot2::autoplot(fit)
#' }
#'
#' @exportS3Method ggplot2::autoplot shewhart_chart
autoplot.shewhart_chart <- function(object,
                                    show_violations  = TRUE,
                                    show_sigma_zones = FALSE,
                                    locale = NULL, ...) {
  assert_chart(object)
  locale <- locale %||% object$metadata$locale %||%
            getOption("shewhart.locale", "en")

  NextMethod()
}

# Single-panel charts -----------------------------------------------------

#' @keywords internal
#' @noRd
plot_single_panel <- function(object, title_key, y_key, locale,
                              show_violations, show_sigma_zones, ...) {

  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]], y = .data$.value)) +
    ggplot2::geom_line(colour = ink["text_low"], linewidth = 0.25, alpha = 0.45) +
    ggplot2::geom_point(colour = signal["in_control"], size = 1.2, alpha = 0.95)

  if (show_sigma_zones) {
    p <- p +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = .data$.center - .data$.sigma,
                     ymax = .data$.center + .data$.sigma),
        fill = signal["in_control"], alpha = 0.06, colour = NA) +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = .data$.center - 2 * .data$.sigma,
                     ymax = .data$.center + 2 * .data$.sigma),
        fill = signal["in_control"], alpha = 0.04, colour = NA)
  }

  p <- p +
    ggplot2::geom_line(ggplot2::aes(y = .data$.center),
                       colour = signal["in_control"], linewidth = 0.7,
                       lineend = "round") +
    ggplot2::geom_line(ggplot2::aes(y = .data$.upper),
                       colour = signal["out_of_control"],
                       linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.lower),
                       colour = signal["out_of_control"],
                       linetype = "dashed", linewidth = 0.4, alpha = 0.7)

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) p <- p + violation_layers(viol)
  }

  p +
    ggplot2::labs(
      title = tr(title_key, locale),
      x     = tr("label_index", locale),
      y     = tr(y_key, locale)
    ) +
    shewhart_theme()
}

#' @exportS3Method ggplot2::autoplot shewhart_p
autoplot.shewhart_p <- function(object, show_violations = TRUE,
                                show_sigma_zones = FALSE,
                                locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_single_panel(object, "title_p", "label_proportion",
                    locale, show_violations, show_sigma_zones, ...)
}

#' @exportS3Method ggplot2::autoplot shewhart_np
autoplot.shewhart_np <- function(object, show_violations = TRUE,
                                 show_sigma_zones = FALSE,
                                 locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_single_panel(object, "title_np", "label_count",
                    locale, show_violations, show_sigma_zones, ...)
}

#' @exportS3Method ggplot2::autoplot shewhart_c
autoplot.shewhart_c <- function(object, show_violations = TRUE,
                                show_sigma_zones = FALSE,
                                locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_single_panel(object, "title_c", "label_count",
                    locale, show_violations, show_sigma_zones, ...)
}

#' @exportS3Method ggplot2::autoplot shewhart_u
autoplot.shewhart_u <- function(object, show_violations = TRUE,
                                show_sigma_zones = FALSE,
                                locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_single_panel(object, "title_u", "label_count_per_unit",
                    locale, show_violations, show_sigma_zones, ...)
}

# Two-panel charts (I-MR, Xbar-R, Xbar-S) ---------------------------------

#' @keywords internal
#' @noRd
plot_two_panel <- function(object, title_key, top_key, bottom_key,
                           bottom_value_col, bottom_center_col,
                           bottom_upper_col, bottom_lower_col,
                           locale, show_violations, ...) {

  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")

  panel <- function(y_col, centre_col, upper_col, lower_col,
                    title = NULL, ylab) {
    g <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]],
                                           y = .data[[y_col]])) +
      ggplot2::geom_line(colour = ink["text_low"],
                         linewidth = 0.25, alpha = 0.45) +
      ggplot2::geom_point(colour = signal["in_control"],
                          size = 1.2, alpha = 0.95) +
      ggplot2::geom_line(ggplot2::aes(y = .data[[centre_col]]),
                         colour = signal["in_control"],
                         linewidth = 0.7, lineend = "round") +
      ggplot2::geom_line(ggplot2::aes(y = .data[[upper_col]]),
                         colour = signal["out_of_control"],
                         linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
      ggplot2::geom_line(ggplot2::aes(y = .data[[lower_col]]),
                         colour = signal["out_of_control"],
                         linetype = "dashed", linewidth = 0.4, alpha = 0.7)
    g + ggplot2::labs(title = title,
                      x = tr("label_index", locale),
                      y = ylab) +
      shewhart_theme()
  }

  p1 <- panel(".value", ".center", ".upper", ".lower",
              title = tr(title_key, locale),
              ylab  = tr(top_key, locale))

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) p1 <- p1 + violation_layers(viol)
  }

  p2 <- panel(bottom_value_col, bottom_center_col,
              bottom_upper_col, bottom_lower_col,
              ylab = tr(bottom_key, locale))

  out <- list(top = p1, bottom = p2)
  class(out) <- "shewhart_plot_pair"
  out
}

#' @exportS3Method ggplot2::autoplot shewhart_i_mr
autoplot.shewhart_i_mr <- function(object, show_violations = TRUE,
                                   show_sigma_zones = FALSE,
                                   locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_two_panel(
    object,
    title_key         = "title_i_mr",
    top_key           = "label_individual",
    bottom_key        = "label_moving_range",
    bottom_value_col  = ".mr",
    bottom_center_col = ".mr_center",
    bottom_upper_col  = ".mr_upper",
    bottom_lower_col  = ".mr_lower",
    locale            = locale,
    show_violations   = show_violations,
    ...
  )
}

#' @exportS3Method ggplot2::autoplot shewhart_xbar_r
autoplot.shewhart_xbar_r <- function(object, show_violations = TRUE,
                                     show_sigma_zones = FALSE,
                                     locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_two_panel(
    object,
    title_key         = "title_xbar_r",
    top_key           = "label_mean",
    bottom_key        = "label_range",
    bottom_value_col  = ".range",
    bottom_center_col = ".r_center",
    bottom_upper_col  = ".r_upper",
    bottom_lower_col  = ".r_lower",
    locale            = locale,
    show_violations   = show_violations,
    ...
  )
}

#' @exportS3Method ggplot2::autoplot shewhart_xbar_s
autoplot.shewhart_xbar_s <- function(object, show_violations = TRUE,
                                     show_sigma_zones = FALSE,
                                     locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  plot_two_panel(
    object,
    title_key         = "title_xbar_s",
    top_key           = "label_mean",
    bottom_key        = "label_std_dev",
    bottom_value_col  = ".s",
    bottom_center_col = ".s_center",
    bottom_upper_col  = ".s_upper",
    bottom_lower_col  = ".s_lower",
    locale            = locale,
    show_violations   = show_violations,
    ...
  )
}

# Regression chart with phases --------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_regression
autoplot.shewhart_regression <- function(object, show_violations = TRUE,
                                         show_sigma_zones = FALSE,
                                         locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)

  # Build localised phase factor: "Phase 0", "Phase 1", "Fase 0", etc.
  ph_lvls   <- sort(unique(aug$.phase))
  ph_labels <- shewhart_phase_label(ph_lvls, locale)
  aug$.phase_f <- factor(shewhart_phase_label(aug$.phase, locale),
                         levels = ph_labels)
  pal <- shewhart_phase_palette(length(ph_lvls))
  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]]))

  # Per-phase ribbon (alpha 0.07 -- quieter than v1.2) + dashed limits
  # + solid centre line. Limits and centre are drawn before the data
  # so the points sit on top.
  for (i in seq_along(ph_lvls)) {
    ph  <- ph_lvls[i]
    sub <- aug[aug$.phase == ph, , drop = FALSE]
    if (nrow(sub) < 1L) next
    col <- pal[i]
    p <- p +
      ggplot2::geom_ribbon(
        data = sub,
        ggplot2::aes(ymin = .data$.lower, ymax = .data$.upper),
        fill = col, alpha = 0.07, colour = NA
      ) +
      ggplot2::geom_line(
        data = sub, ggplot2::aes(y = .data$.upper),
        colour = col, linetype = "dashed", linewidth = 0.4, alpha = 0.65
      ) +
      ggplot2::geom_line(
        data = sub, ggplot2::aes(y = .data$.lower),
        colour = col, linetype = "dashed", linewidth = 0.4, alpha = 0.65
      ) +
      ggplot2::geom_line(
        data = sub, ggplot2::aes(y = .data$.center,
                                 colour = .data$.phase_f),
        linewidth = 0.7, lineend = "round"
      )
  }

  # Observations: a thin tonal line connecting them, then small dots
  # coloured by phase. The line is *very* subtle (alpha 0.45) so the
  # phased structure stays the dominant visual element.
  p <- p +
    ggplot2::geom_line(ggplot2::aes(y = .data$.value),
                       colour = ink["text_low"],
                       linewidth = 0.25, alpha = 0.45) +
    ggplot2::geom_point(ggplot2::aes(y = .data$.value,
                                     colour = .data$.phase_f),
                        size = 1.2, alpha = 0.95)

  # Out-of-control points: hollow ring + white halo, sized so they
  # read against any phase colour underneath.
  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- aug[aug$.flag_any, , drop = FALSE]
    if (nrow(viol) > 0L) p <- p + violation_layers(viol)
  }

  # Subtitle that summarises the chart configuration the way a
  # data-journalism caption would: model + rule + alarm count.
  rule_lbl <- if (length(object$rules)) {
    paste(object$rules, collapse = ", ")
  } else NA_character_
  n_phases <- length(object$fits)
  n_viol   <- nrow(object$violations)
  subtitle <- sprintf(
    "%s model, rule(s): %s \u2014 %d phase%s, %d violation%s",
    object$metadata$model %||% "linear",
    rule_lbl %||% "(none)",
    n_phases, if (n_phases == 1L) "" else "s",
    n_viol,   if (n_viol   == 1L) "" else "s"
  )

  p +
    ggplot2::scale_colour_manual(
      name   = tr("legend_phases", locale),
      values = stats::setNames(pal, ph_labels)
    ) +
    ggplot2::guides(
      colour = ggplot2::guide_legend(
        nrow = 1, byrow = TRUE,
        override.aes = list(linewidth = 0, size = 2.4, alpha = 1)
      )
    ) +
    ggplot2::labs(
      title    = tr("title_regression", locale),
      subtitle = subtitle,
      x        = tr("label_index", locale),
      y        = tr("label_value", locale)
    ) +
    shewhart_theme()
}

#' Sequential phase palette
#'
#' Returns the first `n` colours from the package's sequential phase
#' palette (`shewhart_palette("phase_seq")`), interpolating smoothly
#' if `n` exceeds the base length.
#'
#' @keywords internal
#' @noRd
shewhart_phase_palette <- function(n) {
  shewhart_palette("phase_seq", n = max(1L, as.integer(n)))
}

# EWMA chart --------------------------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_ewma
autoplot.shewhart_ewma <- function(object, show_violations = TRUE,
                                   show_sigma_zones = FALSE,
                                   locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]])) +
    ggplot2::geom_point(ggplot2::aes(y = .data$.value),
                        colour = ink["text_xlow"], size = 1.0, alpha = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.ewma),
                       colour = signal["in_control"], linewidth = 0.7,
                       lineend = "round") +
    ggplot2::geom_point(ggplot2::aes(y = .data$.ewma),
                        colour = signal["in_control"], size = 1.2,
                        alpha = 0.95) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.center),
                       colour = signal["in_control"], linewidth = 0.4,
                       alpha = 0.45) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.upper),
                       colour = signal["out_of_control"], linetype = "dashed",
                       linewidth = 0.4, alpha = 0.7) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.lower),
                       colour = signal["out_of_control"], linetype = "dashed",
                       linewidth = 0.4, alpha = 0.7)

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) p <- p + violation_layers(viol, y_col = ".ewma")
  }

  p +
    ggplot2::labs(
      title    = tr("title_ewma", locale),
      subtitle = sprintf("lambda = %.2f, L = %.2f",
                         object$metadata$lambda, object$metadata$L),
      x        = tr("label_index", locale),
      y        = tr("label_ewma", locale)
    ) +
    shewhart_theme()
}

# CUSUM chart -------------------------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_cusum
autoplot.shewhart_cusum <- function(object, show_violations = TRUE,
                                    show_sigma_zones = FALSE,
                                    locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  decision <- object$metadata$decision

  # CUSUM is plotted with C+ as positive bars and C- as negative,
  # so a single panel makes the symmetric decision interval visible.
  long <- tibble::tibble(
    !!x_col      := rep(aug[[x_col]], 2L),
    cusum_kind    = rep(c("Positive", "Negative"), each = nrow(aug)),
    cusum_value   = c(aug$.cusum_pos, -aug$.cusum_neg),
    flag          = c(aug$.cusum_pos > decision,
                      aug$.cusum_neg > decision)
  )

  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")
  fam    <- shewhart_palette("family")

  p <- ggplot2::ggplot(long, ggplot2::aes(x = .data[[x_col]],
                                          y = .data$cusum_value)) +
    ggplot2::geom_hline(yintercept = 0, colour = ink["axis_line"],
                        linewidth = 0.4) +
    ggplot2::geom_segment(
      ggplot2::aes(xend = .data[[x_col]], yend = 0,
                   colour = .data$cusum_kind),
      linewidth = 0.45, alpha = 0.85, lineend = "round") +
    ggplot2::geom_point(ggplot2::aes(colour = .data$cusum_kind),
                        size = 1.2, alpha = 0.95) +
    ggplot2::geom_hline(yintercept =  decision,
                        colour = signal["out_of_control"],
                        linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
    ggplot2::geom_hline(yintercept = -decision,
                        colour = signal["out_of_control"],
                        linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
    ggplot2::scale_colour_manual(
      name   = NULL,
      values = c(Positive = unname(signal["in_control"]),
                 Negative = unname(fam["memory_based"])))

  if (show_violations && any(long$flag)) {
    p <- p + violation_layers(long[long$flag, , drop = FALSE],
                              y_col = "cusum_value")
  }

  p +
    ggplot2::labs(
      title    = tr("title_cusum", locale),
      subtitle = sprintf("k = %.2f, h = %.2f, decision = %.3f",
                         object$metadata$k,
                         object$metadata$h,
                         decision),
      x = tr("label_index", locale),
      y = tr("label_cusum", locale)
    ) +
    shewhart_theme()
}

# Hotelling T-squared chart -----------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_hotelling
autoplot.shewhart_hotelling <- function(object, show_violations = TRUE,
                                        show_sigma_zones = FALSE,
                                        locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  ucl    <- aug$.upper[1L]

  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]],
                                         y = .data$.t2)) +
    ggplot2::geom_line(colour = ink["text_low"],
                       linewidth = 0.25, alpha = 0.45) +
    ggplot2::geom_point(colour = signal["in_control"],
                        size = 1.2, alpha = 0.95) +
    ggplot2::geom_hline(yintercept = ucl,
                        colour = signal["out_of_control"],
                        linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 0, colour = ink["axis_line"],
                        linewidth = 0.3, alpha = 0.6)

  if (show_violations && any(aug$.flag_signal)) {
    viol <- dplyr::filter(aug, .data$.flag_signal)
    p <- p + violation_layers(viol, y_col = ".t2")
  }

  meta <- object$metadata
  p +
    ggplot2::labs(
      title    = tr("title_hotelling", locale),
      subtitle = sprintf("p = %d, m = %d, n = %d, phase = %s, alpha = %.4f",
                         meta$p, meta$m, meta$n,
                         object$phase, meta$alpha),
      x        = tr("label_index", locale),
      y        = tr("label_t2", locale)
    ) +
    shewhart_theme()
}

# Multivariate EWMA chart -------------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_mewma
autoplot.shewhart_mewma <- function(object, show_violations = TRUE,
                                    show_sigma_zones = FALSE,
                                    locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")
  ucl    <- aug$.upper[1L]

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]],
                                         y = .data$.t2)) +
    ggplot2::geom_line(colour = ink["text_low"],
                       linewidth = 0.25, alpha = 0.45) +
    ggplot2::geom_point(colour = signal["in_control"],
                        size = 1.2, alpha = 0.95) +
    ggplot2::geom_hline(yintercept = ucl,
                        colour = signal["out_of_control"],
                        linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 0, colour = ink["axis_line"],
                        linewidth = 0.3, alpha = 0.6)

  if (show_violations && any(aug$.flag_signal)) {
    viol <- dplyr::filter(aug, .data$.flag_signal)
    p <- p + violation_layers(viol, y_col = ".t2")
  }

  meta <- object$metadata
  p +
    ggplot2::labs(
      title    = tr("title_mewma", locale),
      subtitle = sprintf("p = %d, lambda = %.2f, h = %.2f",
                         meta$p, meta$lambda, meta$h),
      x = tr("label_index", locale),
      y = tr("label_t2", locale)
    ) +
    shewhart_theme()
}

# Multivariate CUSUM chart ------------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_mcusum
autoplot.shewhart_mcusum <- function(object, show_violations = TRUE,
                                     show_sigma_zones = FALSE,
                                     locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)
  signal <- shewhart_palette("signal")
  ink    <- shewhart_palette("neutral")
  ucl    <- aug$.upper[1L]

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]],
                                         y = .data$.y)) +
    ggplot2::geom_line(colour = ink["text_low"],
                       linewidth = 0.25, alpha = 0.45) +
    ggplot2::geom_point(colour = signal["in_control"],
                        size = 1.2, alpha = 0.95) +
    ggplot2::geom_hline(yintercept = ucl,
                        colour = signal["out_of_control"],
                        linetype = "dashed", linewidth = 0.4, alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 0, colour = ink["axis_line"],
                        linewidth = 0.3, alpha = 0.6)

  if (show_violations && any(aug$.flag_signal)) {
    viol <- dplyr::filter(aug, .data$.flag_signal)
    p <- p + violation_layers(viol, y_col = ".y")
  }

  meta <- object$metadata
  p +
    ggplot2::labs(
      title    = tr("title_mcusum", locale),
      subtitle = sprintf("p = %d, k = %.2f, h = %.2f",
                         meta$p, meta$k, meta$h),
      x = tr("label_index", locale),
      y = tr("label_mcusum", locale)
    ) +
    shewhart_theme()
}

# Print method for two-panel charts ---------------------------------------

#' @exportS3Method print shewhart_plot_pair
print.shewhart_plot_pair <- function(x, ...) {
  if (requireNamespace("patchwork", quietly = TRUE)) {
    print(patchwork::wrap_plots(x$top, x$bottom, ncol = 1L))
  } else {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(layout = grid::grid.layout(2, 1)))
    print(x$top,
          vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
    print(x$bottom,
          vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
  }
  invisible(x)
}
