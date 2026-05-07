# Interactive plotly charts -----------------------------------------------
#
# A thin layer that converts the ggplot2 objects returned by
# `autoplot.shewhart_*()` into interactive plotly charts. Plotly is in
# `Suggests`, so the function fails informatively (rather than missing
# silently) when the user has not installed it.
#
# Strategy:
#
#   * For single-panel charts (p, np, c, u, regression, ewma,
#     hotelling), pass the ggplot through `plotly::ggplotly()`.
#   * For two-panel charts (i_mr, xbar_r, xbar_s) the autoplot method
#     returns a `shewhart_plot_pair` object with `$top` and `$bottom`
#     ggplots; we convert each panel and stack them with
#     `plotly::subplot()` so the resulting figure preserves the
#     synchronised x-axis interaction.
#   * For CUSUM the autoplot uses `geom_segment` for the bars; that
#     translates fine to plotly without special handling.

#' Convert a Shewhart chart to an interactive plotly figure
#'
#' Produces an interactive HTML plotly version of the chart that
#' [ggplot2::autoplot()] would build for the same object. Useful for
#' dashboards, reports, and any context where hovering, zooming and
#' panning matters.
#'
#' This is a separate function rather than an `autoplot()` argument
#' so that loading `shewhartr` does not pull `plotly` (and its full
#' transitive dependency tree) into every R session that uses the
#' package. `plotly` lives in `Suggests`; install it explicitly if
#' you want to use this function.
#'
#' @param x A [shewhart_chart] object.
#' @param tooltip Character vector of aesthetics to display in the
#'   hover tooltip, as accepted by [plotly::ggplotly()]. Defaults to
#'   `c("x", "y")`.
#' @param ... Additional arguments forwarded to [plotly::ggplotly()].
#'
#' @return A `plotly` object (S3 class `plotly` / `htmlwidget`) ready
#'   to print, embed in a Shiny app, or save with
#'   [htmlwidgets::saveWidget()].
#'
#' @examples
#' \donttest{
#' if (requireNamespace("plotly", quietly = TRUE)) {
#'   set.seed(1)
#'   df  <- data.frame(t = 1:50, y = rnorm(50, mean = 100, sd = 2))
#'   fit <- shewhart_i_mr(df, value = y, index = t)
#'   as_plotly(fit)
#' }
#' }
#' @export
as_plotly <- function(x, ...) UseMethod("as_plotly")

#' @rdname as_plotly
#' @export
as_plotly.default <- function(x, ...) {
  cli::cli_abort(c(
    "No {.fn as_plotly} method for objects of class {.cls {class(x)[1L]}}.",
    "i" = "{.fn as_plotly} is defined for objects of class {.cls shewhart_chart}."
  ))
}

#' @rdname as_plotly
#' @export
as_plotly.shewhart_chart <- function(x, tooltip = c("x", "y"), ...) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    cli::cli_abort(c(
      "Install {.pkg plotly} to use {.fn as_plotly}.",
      "i" = "{.code install.packages(\"plotly\")}"
    ))
  }
  obj <- ggplot2::autoplot(x)

  if (inherits(obj, "shewhart_plot_pair")) {
    p1 <- plotly::ggplotly(obj$top,    tooltip = tooltip, ...)
    p2 <- plotly::ggplotly(obj$bottom, tooltip = tooltip, ...)
    plotly::subplot(p1, p2, nrows = 2L, shareX = TRUE,
                    titleX = TRUE, titleY = TRUE,
                    margin = 0.06)
  } else {
    plotly::ggplotly(obj, tooltip = tooltip, ...)
  }
}
