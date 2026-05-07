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
get_index_col <- function(aug, fallback = "index") {
  # Looks for a non-dot column to use as x-axis. Falls back to .obs.
  user_cols <- setdiff(names(aug), grep("^\\.", names(aug), value = TRUE))
  if (length(user_cols) > 0L) user_cols[1L] else ".obs"
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
  x_col <- get_index_col(aug)

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
  x_col <- get_index_col(aug)

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
  x_col  <- get_index_col(aug)

  p <- ggplot2::ggplot(aug, ggplot2::aes(x = .data[[x_col]], y = .data$.value)) +
    ggplot2::geom_line(colour = "grey70") +
    ggplot2::geom_point(size = 1.5)

  # Per-phase fits (drawn separately so each segment is connected)
  for (ph in unique(aug$.phase)) {
    sub <- dplyr::filter(aug, .data$.phase == ph)
    p <- p +
      ggplot2::geom_line(data = sub, ggplot2::aes(y = .data$.center,
                                                  colour = factor(.data$.phase)),
                         linewidth = 0.7) +
      ggplot2::geom_line(data = sub, ggplot2::aes(y = .data$.upper,
                                                  colour = factor(.data$.phase)),
                         linetype = "dashed") +
      ggplot2::geom_line(data = sub, ggplot2::aes(y = .data$.lower,
                                                  colour = factor(.data$.phase)),
                         linetype = "dashed")
  }

  if (show_violations && ".flag_any" %in% names(aug)) {
    viol <- dplyr::filter(aug, .data$.flag_any)
    if (nrow(viol) > 0L) {
      p <- p + ggplot2::geom_point(
        data = viol, colour = "firebrick", fill = "firebrick",
        size = 2.5, shape = 21, stroke = 0.8)
    }
  }

  p +
    ggplot2::scale_colour_brewer(name = tr("legend_phase", locale),
                                 palette = "Set2") +
    ggplot2::labs(
      title = tr("title_regression", locale),
      x     = tr("label_index", locale),
      y     = tr("label_value", locale)
    ) +
    shewhart_theme()
}

# EWMA chart --------------------------------------------------------------

#' @exportS3Method ggplot2::autoplot shewhart_ewma
autoplot.shewhart_ewma <- function(object, show_violations = TRUE,
                                   show_sigma_zones = FALSE,
                                   locale = NULL, ...) {
  locale <- locale %||% object$metadata$locale %||% "en"
  aug    <- object$augmented
  x_col  <- get_index_col(aug)

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
  x_col  <- get_index_col(aug)
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
