# c chart -----------------------------------------------------------------
#
# Number of nonconformities per inspection unit (Poisson process).
# Standard 3-sigma limits: c_bar +/- 3 sqrt(c_bar). Exact Poisson limits
# (limits = "poisson") use the 0.00135 / 0.99865 quantiles, honest for
# small means where the normal approximation breaks down.
#
# Box would approve of "poisson" limits: model the right distribution
# rather than transform.

#' c chart for the number of nonconformities
#'
#' Constructs a c chart for counts of nonconformities (defects) per
#' inspection unit, where the unit (area, length, time, etc.) is
#' constant across observations. For variable inspection size use
#' [shewhart_u()].
#'
#' @inheritParams shewhart_p
#' @param defects Tidy-eval column reference for the count of
#'   nonconformities per inspection unit.
#' @param limits One of `"3sigma"` (default; classical normal
#'   approximation) or `"poisson"` (exact Poisson 0.00135 / 0.99865
#'   quantiles, recommended when `c_bar < 10`).
#'
#' @return A [shewhart_chart] object of subclass `shewhart_c`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 7.3.
#'
#' Ryan, T. P. (2011). *Statistical Methods for Quality Improvement*
#' (3rd ed.). Wiley. Chapter 6 (on the inadequacy of 3-sigma limits
#' for low-mean Poisson counts).
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   unit    = 1:40,
#'   defects = rpois(40, lambda = 6)
#' )
#' fit <- shewhart_c(df, defects = defects, index = unit)
#' fit_exact <- shewhart_c(df, defects = defects, index = unit,
#'                         limits = "poisson")
#'
#' @export
shewhart_c <- function(data, defects, index = NULL,
                       limits = c("3sigma", "poisson"),
                       rules  = c("nelson_1_beyond_3s"),
                       locale = getOption("shewhart.locale", "en"),
                       verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  limits <- rlang::arg_match(limits)

  d_q <- rlang::enquo(defects); d_n <- rlang::as_name(d_q)
  i_q <- rlang::enquo(index)
  check_column(data, d_n, arg = "defects")
  defects_v <- dplyr::pull(data, !!d_q); check_count(defects_v, arg = "defects")

  if (is_quo_null(i_q)) {
    idx <- seq_along(defects_v); index_name <- "index"
  } else {
    index_name <- rlang::as_name(i_q)
    check_column(data, index_name, arg = "index")
    idx <- dplyr::pull(data, !!i_q)
  }

  c_bar <- mean(defects_v)
  sigma <- sqrt(c_bar)

  inform_step("c_bar = {.val {round(c_bar, 3)}}; using {.val {limits}} limits.",
              verbose = verbose)

  if (limits == "3sigma") {
    upper <- c_bar + 3 * sigma
    lower <- max(0, c_bar - 3 * sigma)
    if (c_bar < 10) {
      cli::cli_warn(c(
        "c_bar = {.val {round(c_bar, 2)}} is small; the normal approximation is poor.",
        "i" = "Consider {.code limits = \"poisson\"} for exact limits."
      ))
    }
  } else {
    upper <- stats::qpois(0.99865, lambda = c_bar)
    lower <- stats::qpois(0.00135, lambda = c_bar)
  }

  flags <- flag_rules(defects_v,
                      rep(c_bar, length(defects_v)),
                      rep(sigma, length(defects_v)),
                      rules)

  augmented <- tibble::tibble(
    !!index_name := idx,
    .obs          = seq_along(defects_v),
    .value        = defects_v,
    .center       = c_bar,
    .sigma        = sigma,
    .upper        = upper,
    .lower        = lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  lim_tbl <- tibble::tibble(
    chart = "c",
    line  = c("CL", "UCL", "LCL"),
    value = c(c_bar, upper, lower)
  )

  violations <- shewhart_runs(defects_v, rules = rules,
                              center = c_bar, sigma = sigma)

  new_shewhart_chart(
    type         = "c",
    augmented    = augmented,
    limits       = lim_tbl,
    violations   = violations,
    rules        = rules,
    sigma_hat    = sigma,
    sigma_method = limits,
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      defects_name = d_n,
      index_name   = index_name,
      c_bar        = c_bar,
      locale       = locale
    )
  )
}
