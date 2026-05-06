# Xbar-S chart ------------------------------------------------------------
#
# Preferred over Xbar-R for n > 10, or when subgroup sizes differ.
# Sigma is estimated either from S-bar / c4(n) (default) or from the
# pooled within-subgroup variance.

#' Xbar-S control chart for rational subgroups
#'
#' Like [shewhart_xbar_r()], but uses the subgroup standard deviation
#' (S) instead of the range. Recommended for subgroup sizes greater
#' than 10, or when subgroup sizes differ.
#'
#' Xbar-chart limits use `A3(n)`; S-chart limits use `B3(n)` and
#' `B4(n)`. When `sigma_method = "pooled_sd"`, sigma is estimated as
#' the pooled within-subgroup standard deviation.
#'
#' @inheritParams shewhart_xbar_r
#' @param sigma_method One of `"sbar"` (default; classical S-bar /
#'   c4(n)) or `"pooled_sd"` (pooled within-subgroup SD; preferred
#'   when subgroups have different sizes).
#'
#' @return A [shewhart_chart] object of subclass `shewhart_xbar_s`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 6.4.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   batch = rep(1:30, each = 12),
#'   y     = rnorm(360, mean = 80, sd = 0.6)
#' )
#' fit <- shewhart_xbar_s(df, value = y, subgroup = batch)
#' print(fit)
#'
#' @export
shewhart_xbar_s <- function(data, value, subgroup,
                            sigma_method = c("sbar", "pooled_sd"),
                            rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
                            locale = getOption("shewhart.locale", "en"),
                            verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  sigma_method <- rlang::arg_match(sigma_method)

  value_q <- rlang::enquo(value)
  group_q <- rlang::enquo(subgroup)
  value_name <- rlang::as_name(value_q)
  group_name <- rlang::as_name(group_q)
  check_column(data, value_name, arg = "value")
  check_column(data, group_name, arg = "subgroup")

  d <- dplyr::select(data, !!group_q, !!value_q)
  names(d) <- c(".group", ".value")
  check_numeric(d$.value, arg = "value")

  per <- d |>
    dplyr::group_by(.data$.group) |>
    dplyr::summarise(
      n     = sum(!is.na(.data$.value)),
      xbar  = mean(.data$.value, na.rm = TRUE),
      s     = stats::sd(.data$.value, na.rm = TRUE),
      ss    = sum((.data$.value - mean(.data$.value, na.rm = TRUE))^2, na.rm = TRUE),
      .groups = "drop"
    )

  if (any(per$n < 2L)) {
    cli::cli_abort("All subgroups must have at least 2 observations for an S chart.")
  }

  inform_step(
    "Computing Xbar-S chart for {.val {nrow(per)}} subgroup{?s} via {.val {sigma_method}}.",
    verbose = verbose
  )

  # Estimate sigma ---------------------------------------------------------
  if (sigma_method == "sbar") {
    n_common <- unique(per$n)
    if (length(n_common) > 1L) {
      cli::cli_abort(c(
        "Subgroups have unequal sizes: {.val {n_common}}.",
        "i" = "Use {.code sigma_method = \"pooled_sd\"} for unequal subgroups."
      ))
    }
    n   <- n_common
    cons <- shewhart_constants(n)
    A3 <- cons$A3; B3 <- cons$B3; B4 <- cons$B4; c4 <- cons$c4
    s_bar      <- mean(per$s)
    sigma_hat  <- s_bar / c4
    xbar_bar   <- mean(per$xbar)
    xbar_upper <- xbar_bar + A3 * s_bar
    xbar_lower <- xbar_bar - A3 * s_bar
    s_upper    <- B4 * s_bar
    s_lower    <- B3 * s_bar
    s_center   <- s_bar

  } else { # pooled_sd
    pooled_var <- sum(per$ss) / sum(per$n - 1)
    sigma_hat  <- sqrt(pooled_var)
    xbar_bar   <- weighted.mean(per$xbar, per$n)
    n_avg      <- mean(per$n)
    cons       <- shewhart_constants(round(n_avg))
    A3         <- cons$A3; B3 <- cons$B3; B4 <- cons$B4; c4 <- cons$c4

    # For variable n, use per-subgroup limits (could be implemented;
    # here we use average n for simplicity, with a warning).
    if (length(unique(per$n)) > 1L) {
      cli::cli_warn(c(
        "Using average subgroup size for limit calculation.",
        "i" = "For per-subgroup limits with variable n, see Montgomery (2019), Section 6.4.2."
      ))
    }
    xbar_upper <- xbar_bar + 3 * sigma_hat / sqrt(n_avg)
    xbar_lower <- xbar_bar - 3 * sigma_hat / sqrt(n_avg)
    s_center   <- c4 * sigma_hat
    s_upper    <- B4 * s_center
    s_lower    <- B3 * s_center
    n          <- n_avg
  }

  flags <- flag_rules(
    per$xbar,
    rep(xbar_bar, nrow(per)),
    rep(sigma_hat / sqrt(mean(per$n)), nrow(per)),
    rules
  )

  augmented <- tibble::tibble(
    !!group_name := per$.group,
    .obs          = seq_len(nrow(per)),
    .n            = per$n,
    .xbar         = per$xbar,
    .s            = per$s,
    .center       = xbar_bar,
    .sigma        = sigma_hat / sqrt(mean(per$n)),
    .upper        = xbar_upper,
    .lower        = xbar_lower,
    .s_center     = s_center,
    .s_upper      = s_upper,
    .s_lower      = s_lower
  )
  augmented$.value <- augmented$.xbar
  augmented <- dplyr::bind_cols(augmented, flags)

  limits <- tibble::tibble(
    chart = c("Xbar", "Xbar", "Xbar", "S", "S", "S"),
    line  = c("CL", "UCL", "LCL", "CL", "UCL", "LCL"),
    value = c(xbar_bar, xbar_upper, xbar_lower, s_center, s_upper, s_lower)
  )

  violations <- shewhart_runs(
    per$xbar,
    rules  = rules,
    center = xbar_bar,
    sigma  = sigma_hat / sqrt(mean(per$n))
  )

  new_shewhart_chart(
    type         = "xbar_s",
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
      group_name = group_name,
      n          = n,
      locale     = locale,
      constants  = cons
    )
  )
}
