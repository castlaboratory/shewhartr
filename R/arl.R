# Average Run Length (ARL) ------------------------------------------------
#
# The Average Run Length is the central operating-characteristic of a
# control chart. ARL_0 is the expected number of in-control samples
# until a false alarm; ARL_1 is the expected number after a true
# shift before the chart signals.
#
# Closed-form ARLs exist for the simplest rule (Nelson 1, 3-sigma)
# under normal data: ARL_0 = 1 / (2 * pnorm(-3)) ~= 370.4. For
# combinations of rules and non-normal residuals, a Monte Carlo
# simulation is the most honest estimator. Wald insisted on this:
# document the operating characteristics of any decision rule.
#
# References:
#
#   Champ, C. W., & Woodall, W. H. (1987). Exact Results for Shewhart
#     Control Charts with Supplementary Runs Rules. Technometrics,
#     29(4), 393-399.
#   Wald, A. (1947). Sequential Analysis. Wiley.

#' Estimate Average Run Length via Monte Carlo simulation
#'
#' Simulates the run length of a Shewhart-type chart configuration
#' under a sequence of mean shifts. For each shift size, replicates
#' draw normal observations with mean `shift * sigma` (relative to
#' the in-control centre) and stop at the first observation where any
#' of the supplied rules fires. Returns a tibble with the average run
#' length and a Monte Carlo confidence interval.
#'
#' Computational note: for `n_sim = 1e4` and a moderate set of rules,
#' a single configuration takes a fraction of a second; a fine shift
#' grid (10-15 points) takes a few seconds. For tighter intervals or
#' larger rule sets, increase `n_sim` and/or set `parallel = TRUE`
#' (currently a placeholder for future implementation).
#'
#' @param shift Numeric vector of mean shifts to evaluate, in units of
#'   `sigma`. Default: `seq(0, 3, by = 0.5)`.
#' @param rules Character vector of rule keys (see
#'   [shewhart_rules_available()]).
#' @param n_sim Integer. Number of simulation replicates per shift.
#'   Default: 5000.
#' @param max_run Integer. Maximum run length before truncation
#'   (a censored alarm). Default: 1000.
#' @param sigma Numeric. In-control sigma. Default: 1 (the relevant
#'   quantity is `shift / sigma`, so 1 is fine).
#' @param seed Optional integer seed for reproducibility.
#'
#' @return A tibble with columns `shift`, `arl`, `arl_se`,
#'   `arl_lower`, `arl_upper`, `n_truncated`. `n_truncated` counts
#'   how many replicates hit `max_run` before alarming (a sign that
#'   `max_run` should be raised).
#'
#' @references
#' Champ, C. W., & Woodall, W. H. (1987). Exact Results for Shewhart
#' Control Charts with Supplementary Runs Rules. *Technometrics*,
#' 29(4), 393-399. \doi{10.1080/00401706.1987.10488262}
#'
#' Wald, A. (1947). *Sequential Analysis*. Wiley.
#'
#' @examples
#' \donttest{
#' # In-control ARL of Nelson 1 (closed-form ARL_0 ~= 370.4)
#' set.seed(1)
#' shewhart_arl(shift = 0, rules = "nelson_1_beyond_3s",
#'              n_sim = 2000, max_run = 2000)
#'
#' # Adding Nelson 2 sharpens detection but lowers ARL_0
#' shewhart_arl(shift = c(0, 0.5, 1, 1.5, 2),
#'              rules = c("nelson_1_beyond_3s", "nelson_2_nine_same"),
#'              n_sim = 2000)
#' }
#'
#' @export
shewhart_arl <- function(shift = seq(0, 3, by = 0.5),
                         rules = c("nelson_1_beyond_3s",
                                   "nelson_2_nine_same"),
                         n_sim   = 5000L,
                         max_run = 1000L,
                         sigma   = 1,
                         seed    = NULL) {

  check_numeric(shift)
  unknown <- setdiff(rules, names(.shewhart_rule_registry))
  if (length(unknown) > 0L) {
    cli::cli_abort("Unknown rule{?s}: {.val {unknown}}.")
  }
  n_sim   <- check_scalar_int(n_sim,   min = 100L)
  max_run <- check_scalar_int(max_run, min = 50L)

  if (!is.null(seed)) set.seed(seed)

  rule_fns <- lapply(rules, function(r) .shewhart_rule_registry[[r]]$fn)

  simulate_one <- function(s) {
    run_len <- integer(n_sim)
    truncated <- integer(n_sim)
    for (k in seq_len(n_sim)) {
      x <- numeric(0)
      hit <- FALSE
      for (i in seq_len(max_run)) {
        x <- c(x, stats::rnorm(1L, mean = s * sigma, sd = sigma))
        for (fn in rule_fns) {
          fired <- fn(x, 0, sigma)
          fired[is.na(fired)] <- FALSE
          if (any(fired[length(x)])) { hit <- TRUE; break }
        }
        if (hit) { run_len[k] <- i; break }
      }
      if (!hit) {
        run_len[k] <- max_run
        truncated[k] <- 1L
      }
    }
    list(run_len = run_len, truncated = sum(truncated))
  }

  cli::cli_progress_bar(
    "Simulating ARL", total = length(shift), clear = TRUE
  )
  results <- vector("list", length(shift))
  for (j in seq_along(shift)) {
    results[[j]] <- simulate_one(shift[j])
    cli::cli_progress_update()
  }
  cli::cli_progress_done()

  tibble::tibble(
    shift       = shift,
    arl         = vapply(results, function(r) mean(r$run_len), numeric(1L)),
    arl_se      = vapply(results, function(r) stats::sd(r$run_len) / sqrt(n_sim), numeric(1L)),
    arl_lower   = pmax(0, vapply(results, function(r)
                                 mean(r$run_len) - 1.96 * stats::sd(r$run_len) / sqrt(n_sim),
                                 numeric(1L))),
    arl_upper   = vapply(results, function(r)
                         mean(r$run_len) + 1.96 * stats::sd(r$run_len) / sqrt(n_sim),
                         numeric(1L)),
    n_truncated = vapply(results, function(r) r$truncated, integer(1L))
  )
}
