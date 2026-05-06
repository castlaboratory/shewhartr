# p chart -----------------------------------------------------------------
#
# Proportion of nonconforming items. Supports variable subgroup size n.
# Limits at +/- 3 sigma_p where sigma_p = sqrt(p_bar (1 - p_bar) / n_i).

#' p chart for the proportion of nonconforming items
#'
#' Constructs a p chart from counts of nonconforming items in subgroups
#' of size `n`. Subgroup sizes may vary; in that case, control limits
#' are computed per observation.
#'
#' Standard 3-sigma limits use the normal approximation to the binomial:
#' \deqn{\bar p \pm 3 \sqrt{\bar p (1 - \bar p) / n_i}.}
#' For very small `n_i` or very small / very large `p_bar`, the
#' approximation deteriorates and exact binomial limits should be
#' preferred (`limits = "binomial"`).
#'
#' @param data A data frame.
#' @param defects Tidy-eval column reference for the count of
#'   nonconforming items in each subgroup.
#' @param n Tidy-eval column reference for the subgroup size.
#' @param index Optional tidy-eval column reference for the x-axis.
#' @param limits One of `"3sigma"` (default; classical normal
#'   approximation) or `"binomial"` (exact 0.00135 / 0.99865 binomial
#'   quantiles, equivalent to the standard 3-sigma rate when n is
#'   large).
#' @inheritParams shewhart_i_mr
#'
#' @return A [shewhart_chart] object of subclass `shewhart_p`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 7.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   day     = 1:30,
#'   defects = rbinom(30, size = 100, prob = 0.05),
#'   n       = 100
#' )
#' fit <- shewhart_p(df, defects = defects, n = n, index = day)
#' print(fit)
#'
#' @export
shewhart_p <- function(data, defects, n, index = NULL,
                       limits = c("3sigma", "binomial"),
                       rules  = c("nelson_1_beyond_3s"),
                       locale = getOption("shewhart.locale", "en"),
                       verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  limits <- rlang::arg_match(limits)

  d_q <- rlang::enquo(defects); d_n <- rlang::as_name(d_q)
  n_q <- rlang::enquo(n);       n_n <- rlang::as_name(n_q)
  i_q <- rlang::enquo(index)
  check_column(data, d_n, arg = "defects")
  check_column(data, n_n, arg = "n")

  defects_v <- dplyr::pull(data, !!d_q); check_count(defects_v, arg = "defects")
  n_v       <- dplyr::pull(data, !!n_q); check_count(n_v, arg = "n")
  if (any(defects_v > n_v)) {
    cli::cli_abort("{.arg defects} cannot exceed {.arg n} in any row.")
  }

  if (is_quo_null(i_q)) {
    idx <- seq_along(defects_v); index_name <- "index"
  } else {
    index_name <- rlang::as_name(i_q)
    check_column(data, index_name, arg = "index")
    idx <- dplyr::pull(data, !!i_q)
  }

  p_i  <- defects_v / n_v
  p_bar <- sum(defects_v) / sum(n_v)

  inform_step("p_bar = {.val {round(p_bar, 5)}} from {.val {sum(n_v)}} total items.",
              verbose = verbose)

  if (limits == "3sigma") {
    sigma_i <- sqrt(p_bar * (1 - p_bar) / n_v)
    upper   <- pmin(1, p_bar + 3 * sigma_i)
    lower   <- pmax(0, p_bar - 3 * sigma_i)
  } else {
    # exact binomial 0.00135 / 0.99865 quantiles, scaled to proportion
    upper <- stats::qbinom(0.99865, size = n_v, prob = p_bar) / n_v
    lower <- stats::qbinom(0.00135, size = n_v, prob = p_bar) / n_v
    sigma_i <- sqrt(p_bar * (1 - p_bar) / n_v)
  }

  flags <- flag_rules(p_i, rep(p_bar, length(p_i)), sigma_i, rules)

  augmented <- tibble::tibble(
    !!index_name := idx,
    .obs          = seq_along(p_i),
    .defects      = defects_v,
    .n            = n_v,
    .value        = p_i,
    .center       = p_bar,
    .sigma        = sigma_i,
    .upper        = upper,
    .lower        = lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  lim_tbl <- tibble::tibble(
    chart = "p",
    line  = c("CL", "UCL", "LCL"),
    value = c(p_bar,
              if (length(unique(upper)) == 1L) unique(upper) else NA_real_,
              if (length(unique(lower)) == 1L) unique(lower) else NA_real_),
    note  = c("",
              if (length(unique(upper)) == 1L) "" else "varies with n",
              if (length(unique(lower)) == 1L) "" else "varies with n")
  )

  violations <- shewhart_runs(p_i, rules = rules,
                              center = p_bar, sigma = sigma_i)

  new_shewhart_chart(
    type         = "p",
    augmented    = augmented,
    limits       = lim_tbl,
    violations   = violations,
    rules        = rules,
    sigma_hat    = NA_real_,
    sigma_method = limits,
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      defects_name = d_n,
      n_name       = n_n,
      index_name   = index_name,
      p_bar        = p_bar,
      locale       = locale
    )
  )
}
