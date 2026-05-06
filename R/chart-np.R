# np chart ----------------------------------------------------------------
#
# Number of nonconforming items in subgroups of constant size n.
# Limits: n p_bar +/- 3 sqrt(n p_bar (1 - p_bar)).

#' np chart for the number of nonconforming items
#'
#' Constructs an np chart from counts of nonconforming items in
#' subgroups of constant size `n`. For variable subgroup sizes, use
#' [shewhart_p()] instead.
#'
#' @inheritParams shewhart_p
#' @param n Numeric scalar. The (constant) subgroup size.
#'
#' @return A [shewhart_chart] object of subclass `shewhart_np`.
#'
#' @references
#' Montgomery, D. C. (2019). *Introduction to Statistical Quality
#' Control* (8th ed.). Wiley. Chapter 7.2.2.
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   day     = 1:30,
#'   defects = rbinom(30, size = 200, prob = 0.04)
#' )
#' fit <- shewhart_np(df, defects = defects, n = 200, index = day)
#' print(fit)
#'
#' @export
shewhart_np <- function(data, defects, n, index = NULL,
                        rules  = c("nelson_1_beyond_3s"),
                        locale = getOption("shewhart.locale", "en"),
                        verbose = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  if (!is.numeric(n) || length(n) != 1L || n <= 0 || n != round(n)) {
    cli::cli_abort("{.arg n} must be a single positive integer (constant subgroup size).")
  }
  n <- as.integer(n)

  d_q <- rlang::enquo(defects); d_n <- rlang::as_name(d_q)
  i_q <- rlang::enquo(index)
  check_column(data, d_n, arg = "defects")
  defects_v <- dplyr::pull(data, !!d_q); check_count(defects_v, arg = "defects")
  if (any(defects_v > n)) cli::cli_abort("{.arg defects} cannot exceed {.arg n}.")

  if (is_quo_null(i_q)) {
    idx <- seq_along(defects_v); index_name <- "index"
  } else {
    index_name <- rlang::as_name(i_q)
    check_column(data, index_name, arg = "index")
    idx <- dplyr::pull(data, !!i_q)
  }

  p_bar  <- mean(defects_v) / n
  center <- n * p_bar
  sigma  <- sqrt(n * p_bar * (1 - p_bar))
  upper  <- center + 3 * sigma
  lower  <- max(0, center - 3 * sigma)

  inform_step(
    "np chart: {.val {n}} per subgroup, p_bar = {.val {round(p_bar, 5)}}.",
    verbose = verbose
  )

  flags <- flag_rules(defects_v,
                      rep(center, length(defects_v)),
                      rep(sigma,  length(defects_v)),
                      rules)

  augmented <- tibble::tibble(
    !!index_name := idx,
    .obs          = seq_along(defects_v),
    .value        = defects_v,
    .n            = n,
    .center       = center,
    .sigma        = sigma,
    .upper        = upper,
    .lower        = lower
  )
  augmented <- dplyr::bind_cols(augmented, flags)

  lim_tbl <- tibble::tibble(
    chart = "np",
    line  = c("CL", "UCL", "LCL"),
    value = c(center, upper, lower)
  )

  violations <- shewhart_runs(defects_v, rules = rules,
                              center = center, sigma = sigma)

  new_shewhart_chart(
    type         = "np",
    augmented    = augmented,
    limits       = lim_tbl,
    violations   = violations,
    rules        = rules,
    sigma_hat    = sigma,
    sigma_method = "binomial",
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      defects_name = d_n,
      n            = n,
      p_bar        = p_bar,
      index_name   = index_name,
      locale       = locale
    )
  )
}
