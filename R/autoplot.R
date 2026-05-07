# autoplot methods --------------------------------------------------------
#
# Each chart subclass dispatches to the right plotting routine. All
# routines use a shared theme and respect the chart's `metadata$locale`
# for axis labels.

#' @keywords internal
#' @noRd
shewhart_theme <- function() {
  ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor   = ggplot2::element_blank(),
      strip.background   = ggplot2::element_rect(fill = "grey90", colour = NA),
      legend.position    = "bottom",
      plot.title         = ggplot2::element_text(face = "bold")
    )
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

  aug   <- object$augmented
  x_col <- get_index_col(aug, chart = object)

  # Line layers for centre and limits
  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]], y = .data$.value)) +
    ggplot2::geom_line(colour = "grey70") +
    ggplot2::geom_point(size = 1.5)

  if (show_sigma_zones) {
    p <- p +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = .data$.center - .data$.sigma,
                     ymax = .data$.center + .data$.sigma),
        fill = "steelblue", alpha = 0.08, colour = NA) +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = .data$.center - 2 * .data$.sigma,
                     ymax = .data$.center + 2 * .data$.sigma),
        fill = "steelblue", alpha = 0.05, colour = NA)
  }

  p <- p +
    ggplot2::geom_line(ggplot2::aes(y = .data$.center), colour = "steelblue4",
                       linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.upper), colour = "firebrick",
                       linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.lower), colour = "firebrick",
                       linetype = "dashed", linewidth = 0.6)

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) {
      p <- p + ggplot2::geom_point(
        data   = viol,
        colour = "firebrick",
        fill   = "firebrick",
        size   = 2.5,
        shape  = 21,
        stroke = 0.8
      )
    }
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

  aug   <- object$augmented
  x_col <- get_index_col(aug, chart = object)

  # Top panel: individuals / Xbar
  p1 <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]], y = .data$.value)) +
    ggplot2::geom_line(colour = "grey70") +
    ggplot2::geom_point(size = 1.5) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.center), colour = "steelblue4",
                       linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.upper), colour = "firebrick",
                       linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.lower), colour = "firebrick",
                       linetype = "dashed", linewidth = 0.6) +
    ggplot2::labs(title = tr(title_key, locale),
                  x = tr("label_index", locale),
                  y = tr(top_key, locale)) +
    shewhart_theme()

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) {
      p1 <- p1 + ggplot2::geom_point(
        data = viol, colour = "firebrick", fill = "firebrick",
        size = 2.5, shape = 21, stroke = 0.8)
    }
  }

  # Bottom panel: MR / R / S
  p2 <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]],
                                          y = .data[[bottom_value_col]])) +
    ggplot2::geom_line(colour = "grey70") +
    ggplot2::geom_point(size = 1.5) +
    ggplot2::geom_line(ggplot2::aes(y = .data[[bottom_center_col]]),
                       colour = "steelblue4", linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data[[bottom_upper_col]]),
                       colour = "firebrick", linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data[[bottom_lower_col]]),
                       colour = "firebrick", linetype = "dashed", linewidth = 0.6) +
    ggplot2::labs(x = tr("label_index", locale), y = tr(bottom_key, locale)) +
    shewhart_theme()

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

  # One ribbon + centre + limit triplet per phase. Ferraz et al. (2020)
  # use a coloured band per phase as a visual band so the chart stays
  # legible even with many short phases (the "regra do deslocamento"
  # produces them naturally on epidemic data).
  ph_lvls <- sort(unique(aug$.phase))
  aug$.phase_f <- factor(aug$.phase, levels = ph_lvls)
  pal <- shewhart_phase_palette(length(ph_lvls))

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]]))

  for (i in seq_along(ph_lvls)) {
    ph  <- ph_lvls[i]
    sub <- aug[aug$.phase == ph, , drop = FALSE]
    if (nrow(sub) < 1L) next
    col <- pal[i]
    p <- p +
      ggplot2::geom_ribbon(
        data = sub,
        ggplot2::aes(ymin = .data$.lower, ymax = .data$.upper),
        fill = col, alpha = 0.10, colour = NA
      ) +
      ggplot2::geom_line(
        data = sub, ggplot2::aes(y = .data$.upper),
        colour = col, linetype = "dashed", linewidth = 0.5, alpha = 0.7
      ) +
      ggplot2::geom_line(
        data = sub, ggplot2::aes(y = .data$.lower),
        colour = col, linetype = "dashed", linewidth = 0.5, alpha = 0.7
      ) +
      ggplot2::geom_line(
        data = sub, ggplot2::aes(y = .data$.center,
                                 colour = .data$.phase_f),
        linewidth = 0.85
      )
  }

  # Observations (single grey series across all phases keeps the eye
  # on the trajectory, not on per-phase line clutter).
  p <- p +
    ggplot2::geom_line(ggplot2::aes(y = .data$.value), colour = "grey55",
                       linewidth = 0.35) +
    ggplot2::geom_point(ggplot2::aes(y = .data$.value,
                                     colour = .data$.phase_f),
                        size = 1.7)

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- aug[aug$.flag_any, , drop = FALSE]
    if (nrow(viol) > 0L) {
      p <- p + ggplot2::geom_point(
        data = viol,
        ggplot2::aes(y = .data$.value),
        colour = "firebrick", fill = "firebrick",
        size = 2.6, shape = 21, stroke = 0.8)
    }
  }

  p +
    ggplot2::scale_colour_manual(
      name   = tr("legend_phase", locale),
      values = stats::setNames(pal, as.character(ph_lvls))
    ) +
    ggplot2::labs(
      title = tr("title_regression", locale),
      x     = tr("label_index", locale),
      y     = tr("label_value", locale)
    ) +
    shewhart_theme()
}

#' Sequential phase palette
#'
#' Soft, ordered palette so the eye reads phases in time order rather
#' than as unrelated categories. Baseline (phase 0) is always
#' `steelblue4` to match the rest of the package; subsequent phases
#' interpolate through warmer hues.
#'
#' @keywords internal
#' @noRd
shewhart_phase_palette <- function(n) {
  if (n <= 1L) return("steelblue4")
  base <- c("#1F4E79", "#2E75B6", "#5B9BD5",
            "#A9D18E", "#E2C45F", "#ED7D31",
            "#C00000", "#7030A0", "#404040")
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::colorRampPalette(base)(n)
}

# EWMA chart --------------------------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_ewma
autoplot.shewhart_ewma <- function(object, show_violations = TRUE,
                                   show_sigma_zones = FALSE,
                                   locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug, chart = object)

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]])) +
    # Raw observations as faded grey dots, EWMA as the foreground series
    ggplot2::geom_point(ggplot2::aes(y = .data$.value),
                        colour = "grey70", size = 1.2) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.ewma),
                       colour = "steelblue4", linewidth = 0.7) +
    ggplot2::geom_point(ggplot2::aes(y = .data$.ewma),
                        colour = "steelblue4", size = 1.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.center),
                       colour = "steelblue4", linewidth = 0.5,
                       alpha = 0.5) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.upper),
                       colour = "firebrick", linetype = "dashed",
                       linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = .data$.lower),
                       colour = "firebrick", linetype = "dashed",
                       linewidth = 0.6)

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) {
      p <- p + ggplot2::geom_point(
        data = viol,
        ggplot2::aes(y = .data$.ewma),
        colour = "firebrick", fill = "firebrick",
        size = 2.6, shape = 21, stroke = 0.8)
    }
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

  p <- ggplot2::ggplot(long, ggplot2::aes(x = .data[[x_col]],
                                          y = .data$cusum_value)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey70") +
    ggplot2::geom_segment(
      ggplot2::aes(xend = .data[[x_col]], yend = 0,
                   colour = .data$cusum_kind),
      linewidth = 0.6, alpha = 0.85) +
    ggplot2::geom_point(ggplot2::aes(colour = .data$cusum_kind), size = 1.6) +
    ggplot2::geom_hline(yintercept =  decision, colour = "firebrick",
                        linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_hline(yintercept = -decision, colour = "firebrick",
                        linetype = "dashed", linewidth = 0.6) +
    ggplot2::scale_colour_manual(
      name   = NULL,
      values = c(Positive = "steelblue4", Negative = "darkorange3"))

  if (show_violations && any(long$flag)) {
    p <- p + ggplot2::geom_point(
      data   = long[long$flag, , drop = FALSE],
      colour = "firebrick", fill = "firebrick",
      size   = 2.6, shape = 21, stroke = 0.8)
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

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]],
                                         y = .data$.t2)) +
    ggplot2::geom_line(colour = "grey70") +
    ggplot2::geom_point(size = 1.6, colour = "steelblue4") +
    ggplot2::geom_hline(yintercept = ucl, colour = "firebrick",
                        linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey80")

  if (show_violations && any(aug$.flag_signal)) {
    viol <- dplyr::filter(aug, .data$.flag_signal)
    p <- p + ggplot2::geom_point(
      data   = viol,
      colour = "firebrick", fill = "firebrick",
      size   = 2.6, shape = 21, stroke = 0.8)
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
