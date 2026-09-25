# Regression-based control chart ------------------------------------------
#
# A control chart whose centre line is a fitted curve and whose limits
# are estimated from the residuals. This is the speciality of the
# package: trended processes (epidemic curves, sensor drift, growth)
# violate the stationarity assumption of classical Shewhart charts but
# can still be monitored if the trend is itself modelled.
#
# Phase detection: a new phase is introduced when a runs-rule fires.
# The chart is then re-fit phase-by-phase. The default rule
# ("nelson_2_nine_same") is more conservative than the legacy
# 7-points-in-a-row ("we_seven_same") and gives ARL_0 ~= 511 versus 127.
# Under H0 each point falls on either side of the centre with
# probability 1/2, so the expected waiting time for a run of k points
# on the same side is 2^k - 1 (Markov-chain result; confirmed by
# `shewhart_arl()`): 2^9 - 1 = 511 and 2^7 - 1 = 127.
#
# Time axis: every model in the menu regresses on `.N`, the position
# of the observation *within its phase* (1, 2, ..., n_phase), not on
# the raw index (dev/ROADMAP.md: irregular grids must not break the
# chart). Consequences that the code must honour:
#   * a phase too short to fit (< 3 rows) inherits the previous
#     phase's fit AND sigma, and extrapolates it by continuing `.N`
#     from where the previous phase stopped;
#   * `monitor()` continues `.N` from the last position of the last
#     phase (`metadata$phase_n_end`) and uses that phase's sigma
#     (`metadata$phase_sigma`), never restarting at `.N = 1`.
#
# `model = "auto"` maps the Box-Cox lambda of the phase to the
# nearest rung of Tukey's ladder that the menu offers: lambda < 0.25
# (rungs 0 and below) -> "log"; otherwise -> "linear". The square-root
# rung (0.5) has no model in the menu and is mapped to "linear", the
# nearest *weaker* transform; "loglog" is stronger than log and is
# therefore never chosen automatically.
#
# Key references:
#
#   Mandel, B. J. (1969). The Regression Control Chart. Journal of
#     Quality Technology, 1(1), 1-9.
#     <doi:10.1080/00224065.1969.11980341>
#   Hawkins, D. M. (1991). Multivariate Quality Control Based on
#     Regression-Adjusted Variables. Technometrics, 33(1), 61-75.
#     <doi:10.1080/00401706.1991.10484770>
#   Mason, R. L., & Young, J. C. (2002). Multivariate Statistical
#     Process Control with Industrial Applications. SIAM/ASA.

#' Regression-based control chart for processes with trend
#'
#' Fits a chosen model to the data (linear, log, log-log, Gompertz,
#' logistic, or a user-supplied formula), then constructs control
#' limits around the fitted curve using the moving-range estimator on
#' the residuals (Wheeler 1992). Optionally detects phase changes
#' automatically via runs tests on the residuals and re-fits each
#' phase.
#'
#' This is the package's flagship chart, intended for trended or
#' non-stationary processes for which classical Shewhart charts give
#' systematically wrong limits. See the vignette
#' `regression-charts` for a thorough discussion and examples.
#'
#' @param data A data frame.
#' @param value Tidy-eval column reference for the response.
#' @param index Tidy-eval column reference for the predictor (typically
#'   time, but can be any continuous variable).
#' @param model Character. One of `"auto"` (Box-Cox guidance),
#'   `"linear"`, `"log"` (fits `log(y + 1) ~ N`), `"loglog"`,
#'   `"gompertz"`, `"logistic"`. For full control, supply `formula`
#'   instead. With `"auto"`, each phase gets the Box-Cox profile
#'   maximiser `lambda` of `y + 1`, rounded to the nearest rung of the
#'   ladder that the menu offers: `lambda < 0.25` selects `"log"`, any
#'   larger value selects `"linear"` (a square-root lambda near 0.5 has
#'   no dedicated model and maps to `"linear"`; `"loglog"` is a stronger
#'   transform than log and is never chosen automatically).
#' @param formula Optional one-sided or two-sided formula referencing
#'   columns in `data`. If provided, overrides `model`.
#' @param dummy Optional tidy-eval column reference for an additive
#'   covariate (a "dummy" in the original v0.1 nomenclature; can be
#'   any factor or numeric covariate the user wants to adjust for,
#'   such as day-of-week effects or treatment indicators).
#' @param start_base Integer or `NULL`. Number of initial observations
#'   used to estimate the first (base) phase. With automatic phase
#'   detection, `NULL` (the default) means 10. When `phase_changes` is
#'   supplied, `NULL` means the base phase ends just before the first
#'   supplied change; an explicit `start_base` adds a cut at
#'   observation `start_base + 1` in addition to `phase_changes`.
#' @param phase_changes Optional vector of index values at which to
#'   force a phase change (the observation whose index equals the value
#'   starts the new phase). If `NULL`, phase changes are detected
#'   automatically using the supplied `phase_rule`.
#' @param phase_rule Character. Runs rule used to detect new phases.
#'   See [shewhart_rules_available()]. Default Nelson 2 (9 points
#'   same side; ARL_0 = 2^9 - 1 = 511). For backward compatibility with
#'   v0.1.x, use `"we_seven_same"` (7 points; ARL_0 = 2^7 - 1 = 127).
#' @param rules Character vector of rules to flag on the final chart.
#' @param sigma_method One of `"mr"` (default), `"median_mr"`,
#'   `"biweight"` (Tukey-style robust), or `"sd"`.
#' @param lower_bound Numeric scalar or `NA`. If non-`NA`, lower limit
#'   is clipped at this value (commonly 0 for counts). Default `NA`
#'   (no clipping).
#' @param locale Character. One of `"en"`, `"pt"`, `"es"`, `"fr"`.
#' @param verbose Logical. Print progress messages?
#'
#' @return A [shewhart_chart] object of subclass `shewhart_regression`.
#'   The `fits` slot contains a list of fitted model objects (one per
#'   phase; a phase with fewer than 3 observations reuses the previous
#'   phase's fit). The `metadata` slot additionally stores
#'   `phase_n_end` (the last within-phase position `.N` reached by each
#'   phase's fit) and `phase_sigma` (the residual sigma of each phase),
#'   which [monitor()] uses to extrapolate the last phase. The
#'   `sigma_hat` slot is the median of the per-phase sigmas.
#'
#' @references
#' Mandel, B. J. (1969). The Regression Control Chart. *Journal of
#' Quality Technology*, 1(1), 1-9.
#' \doi{10.1080/00224065.1969.11980341}
#'
#' Wheeler, D. J., & Chambers, D. S. (1992). *Understanding Statistical
#' Process Control* (2nd ed.). SPC Press.
#'
#' Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
#' *Journal of the Royal Statistical Society, Series B*, 26(2),
#' 211-252. \doi{10.1111/j.2517-6161.1964.tb00553.x}
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' df <- data.frame(
#'   t = 1:60,
#'   y = c(1:30 * 0.5 + rnorm(30, sd = 0.5),    # phase 1: linear trend
#'         15 + 1:30 * 0.1 + rnorm(30, sd = 0.5)) # phase 2: shift + slowdown
#' )
#' fit <- shewhart_regression(df, value = y, index = t, model = "linear")
#' print(fit)
#' ggplot2::autoplot(fit)
#' }
#'
#' @export
shewhart_regression <- function(data, value, index,
                                model = c("auto", "linear", "log", "loglog",
                                          "gompertz", "logistic"),
                                formula       = NULL,
                                dummy         = NULL,
                                start_base    = NULL,
                                phase_changes = NULL,
                                phase_rule    = "nelson_2_nine_same",
                                rules         = c("nelson_1_beyond_3s",
                                                  "nelson_2_nine_same"),
                                sigma_method  = c("mr", "median_mr",
                                                  "biweight", "sd"),
                                lower_bound   = NA_real_,
                                locale        = getOption("shewhart.locale", "en"),
                                verbose       = NULL) {

  call <- sys.call()
  check_data(data)
  check_locale(locale)
  model <- rlang::arg_match(model)
  sigma_method <- rlang::arg_match(sigma_method)
  explicit_base <- !is.null(start_base)
  start_base    <- if (explicit_base) check_scalar_int(start_base, min = 5L)
                   else 10L

  v_q <- rlang::enquo(value); v_n <- rlang::as_name(v_q)
  i_q <- rlang::enquo(index); i_n <- rlang::as_name(i_q)
  d_q <- rlang::enquo(dummy)
  check_column(data, v_n, arg = "value")
  check_column(data, i_n, arg = "index")

  has_dummy <- !is_quo_null(d_q)
  if (has_dummy) {
    d_n <- rlang::as_name(d_q)
    check_column(data, d_n, arg = "dummy")
  } else {
    d_n <- NULL
  }

  if (nrow(data) <= start_base) {
    cli::cli_abort(c(
      "Need more than {.val {start_base}} observations.",
      "i" = "Got {.val {nrow(data)}}."
    ))
  }

  # Phase detection -------------------------------------------------------
  if (is.null(phase_changes)) {
    inform_step("Detecting phase changes via {.val {phase_rule}}.", verbose = verbose)
    phase_positions <- detect_phases(
      data        = data,
      value_q     = v_q,
      index_q     = i_q,
      dummy_q     = d_q,
      model       = model,
      formula     = formula,
      start_base  = start_base,
      phase_rule  = phase_rule,
      verbose     = verbose
    )
  } else {
    # Convert user-supplied phase_changes to integer positions. An
    # explicit start_base is honoured as an extra cut; otherwise the
    # base phase runs up to the first supplied change.
    idx_v <- dplyr::pull(data, !!i_q)
    phase_positions <- which(idx_v %in% phase_changes)
    if (explicit_base) {
      phase_positions <- sort(unique(c(start_base + 1L, phase_positions)))
    }
  }

  success_step("{.val {length(phase_positions)}} phase change{?s} found.",
               verbose = verbose)

  # Fit phase by phase -----------------------------------------------------
  augmented <- build_phases(
    data            = data,
    value_q         = v_q,
    index_q         = i_q,
    dummy_q         = d_q,
    model           = model,
    formula         = formula,
    start_base      = start_base,
    phase_positions = phase_positions,
    sigma_method    = sigma_method,
    lower_bound     = lower_bound,
    rules           = rules,
    locale          = locale
  )

  fits <- attr(augmented, "fits")
  phase_info <- attr(augmented, "phase_info")
  attr(augmented, "fits") <- NULL
  attr(augmented, "phase_info") <- NULL

  # Limits summary ---------------------------------------------------------
  lim_tbl <- augmented |>
    dplyr::group_by(.data$.phase) |>
    dplyr::summarise(
      cl_first   = dplyr::first(.data$.center),
      ucl_first  = dplyr::first(.data$.upper),
      lcl_first  = dplyr::first(.data$.lower),
      cl_last    = dplyr::last(.data$.center),
      ucl_last   = dplyr::last(.data$.upper),
      lcl_last   = dplyr::last(.data$.lower),
      .groups    = "drop"
    )

  violations <- shewhart_runs(
    augmented$.value,
    rules  = rules,
    center = augmented$.center,
    sigma  = augmented$.sigma
  )

  new_shewhart_chart(
    type         = "regression",
    augmented    = augmented,
    limits       = lim_tbl,
    violations   = violations,
    fits         = fits,
    rules        = rules,
    sigma_hat    = stats::median(phase_info$sigma, na.rm = TRUE),
    sigma_method = sigma_method,
    phase        = "phase_1",
    call         = call,
    metadata     = list(
      value_name = v_n,
      index_name = i_n,
      dummy_name = d_n,
      model      = model,
      formula    = formula,
      phase_rule = phase_rule,
      locale     = locale,
      phase_n_end = phase_info$n_end,
      phase_sigma = phase_info$sigma
    )
  )
}

# Internal helpers --------------------------------------------------------

#' Build the model matrix / fit a single phase
#'
#' @keywords internal
#' @noRd
fit_one_phase <- function(d, value_q, index_q, dummy_q, model, formula) {
  v_n <- rlang::as_name(value_q)
  i_n <- rlang::as_name(index_q)
  has_dummy <- !is_quo_null(dummy_q)
  d_n <- if (has_dummy) rlang::as_name(dummy_q) else NULL

  # Position within the phase
  d$.N <- seq_len(nrow(d))

  # Build formula if not supplied -----------------------------------------
  if (is.null(formula)) {
    if (model == "auto") {
      model <- auto_model_from_lambda(shewhart_box_cox_lambda(d[[v_n]] + 1))
    }
    rhs <- if (has_dummy) paste0(".N + ", d_n) else ".N"
    lhs <- switch(model,
      linear  = v_n,
      log     = sprintf("I(log(`%s` + 1))", v_n),
      loglog  = sprintf("I(loglog(`%s`))", v_n),
      gompertz = NULL,
      logistic = NULL
    )
    if (model %in% c("gompertz", "logistic")) {
      formula <- NULL  # use nls path below
    } else {
      formula <- stats::as.formula(paste(lhs, "~", rhs))
    }
  }

  if (!is.null(formula)) {
    fit <- stats::lm(formula, data = d)
    fit$.shewhart_model <- model
    fit$.shewhart_formula <- formula
    return(fit)
  }

  # nls path for gompertz / logistic --------------------------------------
  if (model == "gompertz") {
    fit <- tryCatch(
      stats::nls(
        stats::as.formula(sprintf("I(cumsum(`%s`) + 1) ~ stats::SSgompertz(.N, Asym, b2, b3)", v_n)),
        data    = d,
        control = stats::nls.control(maxiter = 500, warnOnly = TRUE)
      ),
      error = function(e) NULL
    )
    if (is.null(fit)) {
      cli::cli_warn("Gompertz fit failed; falling back to log model.")
      formula <- stats::as.formula(sprintf("I(log(`%s` + 1)) ~ .N", v_n))
      fit <- stats::lm(formula, data = d)
      fit$.shewhart_model <- "log"
    } else {
      fit$.shewhart_model <- "gompertz"
    }
    return(fit)
  }
  if (model == "logistic") {
    fit <- tryCatch(
      stats::nls(
        stats::as.formula(sprintf("I(cumsum(`%s`) + 1) ~ stats::SSlogis(.N, Asym, xmid, scal)", v_n)),
        data    = d,
        control = stats::nls.control(maxiter = 500, warnOnly = TRUE)
      ),
      error = function(e) NULL
    )
    if (is.null(fit)) {
      cli::cli_warn("Logistic fit failed; falling back to log model.")
      formula <- stats::as.formula(sprintf("I(log(`%s` + 1)) ~ .N", v_n))
      fit <- stats::lm(formula, data = d)
      fit$.shewhart_model <- "log"
    } else {
      fit$.shewhart_model <- "logistic"
    }
    return(fit)
  }
}

#' Map a Box-Cox lambda to a model of the menu (model = "auto")
#'
#' Nearest rung of Tukey's ladder among those the menu offers. The
#' lambda is rounded first because the profile grid
#' `seq(-2, 2, by = 0.1)` carries floating-point noise (e.g. the grid
#' point near -0.1 is not exactly -1/10), which made the old
#' `abs(lambda) < 0.1` window asymmetric.
#'
#' @keywords internal
#' @noRd
auto_model_from_lambda <- function(lambda) {
  lambda <- round(lambda, 6L)
  if (!is.finite(lambda)) return("linear")
  if (lambda < 0.25) "log" else "linear"
}

#' Compute fitted values on the original scale, given a model
#'
#' Gompertz / logistic fits model the cumulative series
#' `cumsum(y) + 1` against `.N`; the fitted increment at `.N` is
#' `C(.N) - C(.N - 1)`, with `C(0) = 1` (the offset: nothing
#' accumulated yet). Evaluating `C(.N - 1)` explicitly keeps this
#' correct for the first row of a phase and for Phase II rows whose
#' `.N` continues past the calibration data.
#'
#' @keywords internal
#' @noRd
predict_original <- function(fit, newdata, value_name) {
  pred <- stats::predict(fit, newdata = newdata)
  m    <- fit$.shewhart_model %||% "linear"
  switch(m,
    linear   = pred,
    log      = pmax(0, exp(pred) - 1),
    loglog   = pmax(0, iloglog(pred)),
    gompertz = ,
    logistic = {
      prev_data    <- newdata
      prev_data$.N <- newdata$.N - 1
      prev         <- stats::predict(fit, newdata = prev_data)
      prev[prev_data$.N <= 0] <- 1
      as.vector(pred - prev)
    },
    pred
  )
}

#' Detect phase changes by iteratively scanning the most recent phase
#'
#' @keywords internal
#' @noRd
detect_phases <- function(data, value_q, index_q, dummy_q, model, formula,
                          start_base, phase_rule, verbose) {

  # Length of the run that the rule looks for, e.g. 7 for `we_seven_same`,
  # 9 for `nelson_2_nine_same`. Used to set a minimum-phase-size threshold
  # that prevents the greedy loop from cutting a phase the moment its
  # first n_consec points happen to fall on the same side of the locally
  # fitted centre line — see Ferraz et al. (2020), §3, on the
  # "regra do deslocamento" requiring a sustained run inside an
  # already-stable phase.
  rule_n_consec <- function(rule_key) {
    switch(rule_key,
      we_seven_same       = 7L,
      nelson_2_nine_same  = 9L,
      nelson_3_six_trend  = 6L,
      nelson_4_alternating = 14L,
      nelson_7_stratification = 15L,
      nelson_8_mixture    = 8L,
      9L
    )
  }
  n_consec  <- rule_n_consec(phase_rule)
  min_phase <- 2L * n_consec   # minimum phase size to allow another cut

  v <- dplyr::pull(data, !!value_q)
  positions <- start_base + 1L      # first phase change is the end of base
  changed   <- TRUE
  while (changed) {
    changed <- FALSE
    # Re-fit with currently known phase positions
    aug <- build_phases(
      data            = data,
      value_q         = value_q,
      index_q         = index_q,
      dummy_q         = dummy_q,
      model           = model,
      formula         = formula,
      start_base      = start_base,
      phase_positions = positions,
      sigma_method    = "mr",
      lower_bound     = NA_real_,
      rules           = phase_rule,
      locale          = "en"
    )
    last_phase <- aug |>
      dplyr::filter(.data$.phase == max(.data$.phase))

    if (nrow(last_phase) >= min_phase) {
      flag_col <- paste0(".flag_", phase_rule)
      # Skip the first n_consec rows of the phase: the run rule needs
      # n_consec observations to even start firing, so any flag inside
      # that window is just the rule's warm-up, not real evidence of a
      # new phase.
      hit <- which(last_phase[[flag_col]] &
                   seq_len(nrow(last_phase)) > n_consec)
      if (length(hit) > 0L) {
        new_pos <- last_phase$.obs[hit[1]] + 1L
        # The piece left over after the cut must itself be large
        # enough to estimate a regression model on.
        leftover <- nrow(data) - new_pos + 1L
        if (!new_pos %in% positions && leftover >= n_consec) {
          positions <- sort(unique(c(positions, new_pos)))
          changed   <- TRUE
        }
      }
    }
  }
  positions
}

#' Build the per-row augmented tibble with limits for all phases
#'
#' @keywords internal
#' @noRd
build_phases <- function(data, value_q, index_q, dummy_q, model, formula,
                         start_base, phase_positions, sigma_method,
                         lower_bound, rules, locale) {

  v_n <- rlang::as_name(value_q)
  i_n <- rlang::as_name(index_q)
  has_dummy <- !is_quo_null(dummy_q)
  d_n <- if (has_dummy) rlang::as_name(dummy_q) else NULL

  cols <- c(i_n, v_n, d_n)
  d <- data[, cols, drop = FALSE]
  d$.obs <- seq_len(nrow(d))

  # Cut points define phases ----------------------------------------------
  cuts  <- sort(unique(c(1L, phase_positions, nrow(d) + 1L)))
  phase <- findInterval(d$.obs, cuts, rightmost.closed = FALSE) - 1L
  phase <- pmax(phase, 0L)
  d$.phase <- phase

  n_phases <- max(phase) + 1L
  fits  <- vector("list", length = n_phases)
  n_end <- integer(n_phases)
  sigma <- rep(NA_real_, n_phases)
  out   <- vector("list", length = nrow(d))

  for (p in unique(phase)) {
    sub <- d[d$.phase == p, , drop = FALSE]
    inherit <- nrow(sub) < 3L && p > 0L
    if (inherit) {
      # Not enough data: extrapolate the previous phase's fit (and use
      # its sigma), continuing .N from where that phase stopped.
      fit    <- fits[[p]]
      offset <- n_end[p]
    } else {
      fit <- if (nrow(sub) < 3L) {
        NULL
      } else {
        fit_one_phase(sub, value_q, index_q, dummy_q, model, formula)
      }
      offset <- 0L
    }
    sub$.N <- offset + seq_len(nrow(sub))
    # Single-bracket assignment: `fits[[i]] <- NULL` would delete the
    # element and shift every later phase's index.
    fits[p + 1L]  <- list(fit)
    n_end[p + 1L] <- offset + nrow(sub)

    if (is.null(fit)) {
      sub$.fitted <- NA_real_
    } else {
      sub$.fitted <- predict_original(fit, sub, v_n)
    }

    if (inherit) {
      sigma_hat <- sigma[p]
    } else {
      # Sigma from residuals (on original scale, simple choice)
      resid <- sub[[v_n]] - sub$.fitted
      sigma_hat <- switch(
        sigma_method,
        mr        = mr_bar(resid) / 1.128,
        median_mr = stats::median(moving_range(resid), na.rm = TRUE) / 0.954,
        biweight  = unname(biweight(resid)["scale"]),
        sd        = stats::sd(resid, na.rm = TRUE)
      )
    }
    if (!is.finite(sigma_hat) || sigma_hat <= 0) sigma_hat <- 1
    sigma[p + 1L] <- sigma_hat
    sub$.center <- sub$.fitted
    sub$.sigma  <- sigma_hat
    sub$.upper  <- sub$.fitted + 3 * sigma_hat
    sub$.lower  <- sub$.fitted - 3 * sigma_hat
    if (!is.na(lower_bound)) sub$.lower <- pmax(lower_bound, sub$.lower)

    out[[p + 1L]] <- sub
  }

  augmented <- dplyr::bind_rows(out)
  augmented$.value <- augmented[[v_n]]

  # Phase labels (locale-aware). Explicit `augmented$` references
  # rather than `with()` keep R CMD check free of global-variable NOTEs.
  ph <- augmented$.phase
  augmented$.phase_label <- ifelse(
    ph == 0L, tr("phase_base", locale),
    ifelse(ph == max(ph), tr("phase_monitoring", locale),
           vapply(ph, function(p) tr("phase_n", locale, p),
                  character(1L)))
  )

  # Apply rule flags -------------------------------------------------------
  flags <- flag_rules(augmented$.value, augmented$.center, augmented$.sigma, rules)
  augmented <- dplyr::bind_cols(augmented, flags)

  attr(augmented, "fits") <- fits
  attr(augmented, "phase_info") <- list(n_end = n_end, sigma = sigma)
  augmented
}
