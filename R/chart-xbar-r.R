# Xbar-R chart ------------------------------------------------------------
#
# For rational subgroups of size 2..10 (typically 4-6). Sigma is
# estimated from the average range (R-bar / d2(n)).
#
# Xbar limits: x_bar_bar +/- A2(n) * R_bar
# R limits:    [D3(n), D4(n)] * R_bar

#' Xbar-R control chart for rational subgroups
#'
#' Constructs a paired Xbar (subgroup mean) and R (subgroup range)
#' chart for measurements organised in rational subgroups of size 2 to
#' 10. Sigma is estimated from the average within-subgroup range.
#'
#' Xbar-chart limits use `A2(n)`; R-chart limits use `D3(n)` and
#' `D4(n)`. See [shewhart_constants()] for the tabulated values.
#'
#' @inheritParams shewhart_i_mr
#' @param subgroup Tidy-eval column reference identifying the subgroup
#'   (e.g. shift, batch, hour). All subgroups must have equal size.
#'
#' @return A [shewhart_chart] object of subclass `shewhart_xbar_r`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 6.
#'
#' Shewhart, W. A. (1931). *Economic Control of Quality of Manufactured
#' Product*. D. Van Nostrand.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   batch = rep(1:25, each = 5),
#'   y     = rnorm(125, mean = 50, sd = 1.5)
#' )
#' fit <- shewhart_xbar_r(df, value = y, subgroup = batch)
#' print(fit)
#'
#' @export
shewhart_xbar_r <- function(data, value, subgroup,
                            rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
                            locale = getOption("shewhart.locale", "en"),
                            verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)

  value_q <- rlang::enquo(value)
  group_q <- rlang::enquo(subgroup)

  value_name <- rlang::as_name(value_q)
  group_name <- rlang::as_name(group_q)
  check_column(data, value_name, arg = "value")
  check_column(data, group_name, arg = "subgroup")

  # Build per-subgroup statistics ------------------------------------------
  d <- dplyr::select(data, !!group_q, !!value_q)
  names(d) <- c(".group", ".value")
  check_numeric(d$.value, arg = "value")

  per <- d |>
    dplyr::group_by(.data$.group) |>
    dplyr::summarise(
      n        = sum(!is.na(.data$.value)),
      xbar     = mean(.data$.value, na.rm = TRUE),
      r        = max(.data$.value, na.rm = TRUE) -
                 min(.data$.value, na.rm = TRUE),
      .groups  = "drop"
    )

  # Verify equal subgroup sizes --------------------------------------------
  n_unique <- unique(per$n)
  if (length(n_unique) != 1L) {
    cli::cli_abort(c(
      "Subgroups have unequal sizes: {.val {n_unique}}.",
      "i" = "All subgroups must have the same size for the classical Xbar-R chart.",
      "i" = "Use {.fn shewhart_xbar_s} with {.code sigma_method = \"pooled_sd\"} for unequal subgroups."
    ))
  }

  n <- n_unique
  check_subgroup_size(n, max_warn = 10L)

  inform_step("Computing Xbar-R chart for {.val {nrow(per)}} subgroup{?s} of size {.val {n}}.",
              verbose = verbose)

  # Look up constants -------------------------------------------------------
  cons <- shewhart_constants(n)
  A2 <- cons$A2; D3 <- cons$D3; D4 <- cons$D4; d2 <- cons$d2

  xbar_bar <- mean(per$xbar)
  r_bar    <- mean(per$r)
  sigma_hat <- r_bar / d2

  xbar_upper <- xbar_bar + A2 * r_bar
  xbar_lower <- xbar_bar - A2 * r_bar
  r_upper    <- D4 * r_bar
  r_lower    <- D3 * r_bar

  # Flags on the Xbar series ------------------------------------------------
  flags <- flag_rules(
    per$xbar,
    rep(xbar_bar, nrow(per)),
    rep(sigma_hat / sqrt(n), nrow(per)),
    rules
  )

  augmented <- tibble::tibble(
    !!group_name  := per$.group,
    .obs           = seq_len(nrow(per)),
    .n             = n,
    .xbar          = per$xbar,
    .range         = per$r,
    .center        = xbar_bar,
    .sigma         = sigma_hat / sqrt(n),
    .upper         = xbar_upper,
    .lower         = xbar_lower,
    .r_center      = r_bar,
    .r_upper       = r_upper,
    .r_lower       = r_lower
  )
  # Convenience .value column for runs tests / unified plotting
  augmented$.value <- augmented$.xbar
  augmented <- dplyr::bind_cols(augmented, flags)

  limits <- tibble::tibble(
    chart = c("Xbar", "Xbar", "Xbar", "R", "R", "R"),
    line  = c("CL", "UCL", "LCL", "CL", "UCL", "LCL"),
    value = c(xbar_bar, xbar_upper, xbar_lower, r_bar, r_upper, r_lower)
  )

  violations <- shewhart_runs(per$xbar,
                              rules  = rules,
                              center = xbar_bar,
                              sigma  = sigma_hat / sqrt(n))

  new_shewhart_chart(
    type         = "xbar_r",
    augmented    = augmented,
    limits       = limits,
    violations   = violations,
    rules        = rules,
    sigma_hat    = sigma_hat,
    sigma_method = "range",
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
