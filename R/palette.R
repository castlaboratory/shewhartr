# Palettes ----------------------------------------------------------------
#
# Centralised colour decisions for every autoplot in the package. The
# guiding principles, in order:
#
#   1. *Sequential* palettes for ordered information (phase index, time
#      bucket) so the eye reads order from the colour itself, not from
#      a legend lookup.
#   2. *Categorical* palettes for unordered information (chart family,
#      rule key) using hues that stay distinguishable in greyscale and
#      pass common colour-blindness checks (deuteranopia and protanopia).
#   3. A single, fixed *signal* pair so an out-of-control point looks
#      the same on every chart.
#
# The palette inventory is exposed via `shewhart_palette()` so users
# can reuse the same colours in custom plots.

.shewhart_palettes <- list(

  # Sequential phase palette: cool -> neutral -> warm. Designed for the
  # multi-phase regression chart where phase index is *time-ordered*
  # and the visual progression should reflect that. The tail bends
  # warm (terracotta / brick) to give the eye an unmistakable "later
  # phase" cue without ever using saturated red (which we reserve for
  # out-of-control violations).
  phase_seq = c(
    "#0F4C81",  # 1 — baseline navy
    "#2A6BA0",
    "#4F8DBE",
    "#7AAFD3",
    "#ACCFE1",  # 5 — pale steel
    "#E1CFAB",  # 6 — neutral warm
    "#D2A98E",
    "#B6764E",
    "#8B4226"   # 9 — deep terracotta
  ),

  # Categorical chart-family palette: matched to the architecture
  # diagram so the same hue means the same family everywhere.
  family = c(
    variables    = "#0054AD",
    attributes   = "#16A34A",
    memory_based = "#D97706",
    multivariate = "#7030A0"
  ),

  # Signal pair: a small, fixed alphabet for "in control" and "out of
  # control" that we use across every chart subclass.
  signal = c(
    in_control     = "#1F4068",
    out_of_control = "#C3423F"
  ),

  # Neutral structural palette used by `shewhart_theme()`.
  neutral = c(
    bg_plot   = "#FAFAFA",
    bg_panel  = "#FAFAFA",
    grid      = "#E5E7EB",
    axis_line = "#9CA3AF",
    text_high = "#111827",
    text_med  = "#4B5563",
    text_low  = "#6B7280",
    text_xlow = "#9CA3AF"
  )
)

#' Access the package's named colour palettes
#'
#' Returns one of the curated colour vectors that every chart in the
#' package draws from. Useful when extending an `autoplot()` chart
#' with your own layers and you want them to match the rest of the
#' package's visual identity.
#'
#' @param name One of `"phase_seq"`, `"family"`, `"signal"`,
#'   `"neutral"`. See *Details* for the contents and intended use of
#'   each.
#' @param n Optional integer. Number of colours to return. If `NULL`
#'   (default) the full palette is returned. If `n` exceeds the
#'   palette length, a smooth ramp (`grDevices::colorRampPalette()`)
#'   is interpolated.
#'
#' @details
#' \describe{
#'   \item{`phase_seq`}{Sequential palette for time-ordered phase
#'     indices in regression / multi-phase charts. Cool blues at the
#'     baseline, warming through neutral to terracotta as phase index
#'     grows. Avoids saturated red (reserved for `signal`).}
#'   \item{`family`}{Named categorical palette for the four chart
#'     families: variables, attributes, memory-based, multivariate.
#'     Identical to the colours used in the architecture diagram.}
#'   \item{`signal`}{Two-colour palette: `in_control` (deep blue)
#'     and `out_of_control` (firebrick). Used to colour violation
#'     points on every chart so the alarm signal is consistent.}
#'   \item{`neutral`}{Structural greys used by `shewhart_theme()` for
#'     backgrounds, gridlines and text colour.}
#' }
#'
#' @return A character vector of colour hex codes; for `family` and
#'   `signal`, the vector is named.
#'
#' @examples
#' shewhart_palette("phase_seq", n = 4)
#' shewhart_palette("family")["multivariate"]
#' shewhart_palette("signal")
#' @export
shewhart_palette <- function(name = c("phase_seq", "family", "signal", "neutral"),
                             n = NULL) {
  name <- match.arg(name)
  pal  <- .shewhart_palettes[[name]]
  if (is.null(n)) return(pal)
  if (!is.numeric(n) || length(n) != 1L || n < 1L) {
    cli::cli_abort("{.arg n} must be a positive integer.")
  }
  if (n <= length(pal)) return(pal[seq_len(n)])
  grDevices::colorRampPalette(unname(pal))(n)
}
