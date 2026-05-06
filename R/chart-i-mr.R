# I-MR chart --------------------------------------------------------------
#
# Individuals and Moving Range chart. The most common chart for
# individual measurements (no rational subgroups). Sigma is estimated
# from the moving range:
#
#   sigma_hat = MR_bar / d2(2)  with d2(2) = 1.128
#
# I-chart limits: x_bar +/- 3 * sigma_hat  (equivalently +/- 2.66 * MR_bar)
# MR-chart limits: 0  to  D4(2) * MR_bar  with D4(2) = 3.267
#
# Robust alternative (sigma_method = "biweight") uses the Tukey
# biweight scale of the deviations. Robust sigma based on the median
# of moving ranges (sigma_method = "median_mr") is also offered, with
# the unbiased correction derived from MR ~ Range distribution.

#' Individuals and Moving Range (I-MR) control chart
#'
#' Constructs an I-MR chart for a single column of individual
#' measurements. Returns a [shewhart_chart] object that supports
#' `print()`, `summary()`, `autoplot()`, `tidy()`, `glance()` and
#' `augment()`.
#'
#' Sigma is estimated from the moving range with `d2(2) = 1.128`; the
#' classical 3-sigma limits are equivalent to
#' `x_bar +/- 2.660 * MR_bar`. The MR chart limits are
#' `[0, D4(2) * MR_bar]` with `D4(2) = 3.267`.
#'
#' @param data A data frame.
#' @param value Tidy-eval column reference for the measurement.
#' @param index Optional tidy-eval column reference for the x-axis
#'   (date or integer). If `NULL` (default), the row index is used.
#' @param sigma_method One of `"mr"` (default; classical moving range),
#'   `"median_mr"` (Tukey-style robust: median of moving ranges, with
#'   bias correction), `"biweight"` (Tukey biweight midvariance),
#'   `"sd"` (sample SD).
#' @param rules Character vector of rule keys to apply. See
#'   [shewhart_rules_available()]. Default applies Nelson 1 and 2.
#' @param locale One of `"en"`, `"pt"`, `"es"`, `"fr"`. Affects plot
#'   labels and informative messages.
#' @param verbose Logical. Print progress messages? Defaults to the
#'   `shewhart.verbose` option.
#'
#' @return A [shewhart_chart] object of subclass `shewhart_i_mr`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 6.
#'
#' Wheeler, D. J., & Chambers, D. S. (1992). *Understanding Statistical
#' Process Control* (2nd ed.). SPC Press.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   day = seq.Date(as.Date("2024-01-01"), by = "day", length.out = 60),
#'   y   = c(rnorm(40, mean = 100, sd = 2),
#'           rnorm(20, mean = 103, sd = 2))   # shift after position 40
#' )
#' fit <- shewhart_i_mr(df, value = y, index = day)
#' print(fit)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
#'
#' @export
shewhart_i_mr <- function(data, value, index = NULL,
                          sigma_method = c("mr", "median_mr", "biweight", "sd"),
                          rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
                          locale = getOption("shewhart.locale", "en"),
                          verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  sigma_method <- rlang::arg_match(sigma_method)

  value_q <- rlang::enquo(value)
  index_q <- rlang::enquo(index)

  value_name <- rlang::as_name(value_q)
  check_column(data, value_name, arg = "value")
  v <- dplyr::pull(data, !!value_q)
  check_numeric(v, arg = "value")

  if (is_quo_null(index_q)) {
    idx <- seq_along(v)
    index_name <- "index"
  } else {
    index_name <- rlang::as_name(index_q)
    check_column(data, index_name, arg = "index")
    idx <- dplyr::pull(data, !!index_q)
  }

  if (length(v) < 10L) {
    cli::cli_warn(c(
      "I-MR chart with only {.val {length(v)}} observation{?s}.",
      "i" = "Estimating limits from fewer than 20 points is unreliable; consider Phase II monitoring against pre-calibrated limits."
    ))
  }

  inform_step("Estimating sigma via {.val {sigma_method}}.", verbose = verbose)

  # Estimate centre and sigma ----------------------------------------------
  centre   <- mean(v, na.rm = TRUE)

  sigma_hat <- switch(
    sigma_method,
    mr        = mr_bar(v) / 1.128,
    median_mr = stats::median(moving_range(v), na.rm = TRUE) / 0.954,
    # 0.954 is the bias-correction factor for median MR under normality
    # (see Cryer & Ryan 1990, JQT 22:187-192)
    biweight  = unname(biweight(v - stats::median(v, na.rm = TRUE))["scale"]),
    sd        = stats::sd(v, na.rm = TRUE)
  )

  if (!is.finite(sigma_hat) || sigma_hat <= 0) {
    cli::cli_abort(c(
      "Estimated sigma is {.val {sigma_hat}}.",
      "i" = "Check for zero variance or all-NA values in {.arg value}."
    ))
  }

  # I chart -----------------------------------------------------------------
  i_center <- centre
  i_upper  <- centre + 3 * sigma_hat
  i_lower  <- centre - 3 * sigma_hat

  # MR chart ----------------------------------------------------------------
  mr      <- moving_range(v)
  mr_mean <- mean(mr, na.rm = TRUE)
  mr_upper <- 3.267 * mr_mean   # D4(2)
  mr_lower <- 0                 # D3(2) = 0

  # Flags -------------------------------------------------------------------
  flags <- flag_rules(v, rep(i_center, length(v)),
                      rep(sigma_hat, length(v)), rules)

  augmented <- tibble::tibble(
    !!index_name  := idx,
    .obs           = seq_along(v),
    .value         = v,
    .center        = i_center,
    .sigma         = sigma_hat,
    .upper         = i_upper,
    .lower         = i_lower,
    .mr            = mr,
    .mr_center     = mr_mean,
    .mr_upper      = mr_upper,
    .mr_lower      = mr_lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  limits <- tibble::tibble(
    chart  = c("I", "I", "I", "MR", "MR", "MR"),
    line   = c("CL", "UCL", "LCL", "CL", "UCL", "LCL"),
    value  = c(i_center, i_upper, i_lower, mr_mean, mr_upper, mr_lower)
  )

  violations <- shewhart_runs(v,
                              rules  = rules,
                              center = i_center,
                              sigma  = sigma_hat)

  new_shewhart_chart(
    type         = "i_mr",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = rules,
    sigma_hat    = sigma_hat,
    sigma_method = sigma_method,
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      value_name = value_name,
      index_name = index_name,
      locale     = locale
    )
  )
}
