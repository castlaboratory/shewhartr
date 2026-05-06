# u chart -----------------------------------------------------------------
#
# Number of nonconformities per unit, when inspection size (exposure)
# varies across subgroups. Limits per observation:
#   u_bar +/- 3 sqrt(u_bar / e_i)

#' u chart for nonconformities per unit, variable inspection size
#'
#' Constructs a u chart from defect counts and a per-observation
#' "exposure" (inspection size: square metres of fabric, hours of
#' operation, lines of code, etc.). For constant exposure use
#' [shewhart_c()].
#'
#' @inheritParams shewhart_c
#' @param defects Tidy-eval column reference for raw defect counts.
#' @param exposure Tidy-eval column reference for the inspection size
#'   (must be positive).
#'
#' @return A [shewhart_chart] object of subclass `shewhart_u`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 7.3.2.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   roll     = 1:25,
#'   defects  = rpois(25, lambda = 4 * runif(25, 0.5, 1.5)),
#'   m2       = runif(25, 0.5, 1.5)    # variable inspection size
#' )
#' fit <- shewhart_u(df, defects = defects, exposure = m2, index = roll)
#'
#' @export
shewhart_u <- function(data, defects, exposure, index = NULL,
                       limits = c("3sigma", "poisson"),
                       rules  = c("nelson_1_beyond_3s"),
                       locale = getOption("shewhart.locale", "en"),
                       verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  limits <- rlang::arg_match(limits)

  d_q <- rlang::enquo(defects);  d_n <- rlang::as_name(d_q)
  e_q <- rlang::enquo(exposure); e_n <- rlang::as_name(e_q)
  i_q <- rlang::enquo(index)
  check_column(data, d_n, arg = "defects")
  check_column(data, e_n, arg = "exposure")

  defects_v  <- dplyr::pull(data, !!d_q); check_count(defects_v, arg = "defects")
  exposure_v <- dplyr::pull(data, !!e_q); check_numeric(exposure_v, arg = "exposure")
  if (any(exposure_v <= 0)) cli::cli_abort("{.arg exposure} must be strictly positive.")

  if (is_quo_null(i_q)) {
    idx <- seq_along(defects_v); index_name <- "index"
  } else {
    index_name <- rlang::as_name(i_q)
    check_column(data, index_name, arg = "index")
    idx <- dplyr::pull(data, !!i_q)
  }

  u_i   <- defects_v / exposure_v
  u_bar <- sum(defects_v) / sum(exposure_v)

  inform_step("u_bar = {.val {round(u_bar, 4)}} from {.val {sum(exposure_v)}} total exposure.",
              verbose = verbose)

  sigma_i <- sqrt(u_bar / exposure_v)

  if (limits == "3sigma") {
    upper <- u_bar + 3 * sigma_i
    lower <- pmax(0, u_bar - 3 * sigma_i)
  } else {
    # exact Poisson on counts, scaled to rate
    upper <- stats::qpois(0.99865, lambda = u_bar * exposure_v) / exposure_v
    lower <- stats::qpois(0.00135, lambda = u_bar * exposure_v) / exposure_v
  }

  flags <- flag_rules(u_i, rep(u_bar, length(u_i)), sigma_i, rules)

  augmented <- tibble::tibble(
    !!index_name := idx,
    .obs          = seq_along(u_i),
    .defects      = defects_v,
    .exposure     = exposure_v,
    .value        = u_i,
    .center       = u_bar,
    .sigma        = sigma_i,
    .upper        = upper,
    .lower        = lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  lim_tbl <- tibble::tibble(
    chart = "u",
    line  = c("CL", "UCL", "LCL"),
    value = c(u_bar,
              if (length(unique(upper)) == 1L) unique(upper) else NA_real_,
              if (length(unique(lower)) == 1L) unique(lower) else NA_real_),
    note  = c("",
              if (length(unique(upper)) == 1L) "" else "varies with exposure",
              if (length(unique(lower)) == 1L) "" else "varies with exposure")
  )

  violations <- shewhart_runs(u_i, rules = rules,
                              center = u_bar, sigma = sigma_i)

  new_shewhart_chart(
    type         = "u",
    augmented    = augmented,
    limits       = lim_tbl,
    violations   = violations,
    rules        = rules,
    sigma_hat    = NA_real_,
    sigma_method = limits,
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      defects_name  = d_n,
      exposure_name = e_n,
      index_name    = index_name,
      u_bar         = u_bar,
      locale        = locale
    )
  )
}
