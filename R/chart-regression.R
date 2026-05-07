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
# 7-points-in-a-row ("we_seven_same") and gives ARL_0 ~= 256 versus 64.
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
#'   instead.
#' @param formula Optional one-sided or two-sided formula referencing
#'   columns in `data`. If provided, overrides `model`.
#' @param dummy Optional tidy-eval column reference for an additive
#'   covariate (a "dummy" in the original v0.1 nomenclature; can be
#'   any factor or numeric covariate the user wants to adjust for,
#'   such as day-of-week effects or treatment indicators).
#' @param start_base Integer. Number of initial observations used to
#'   estimate the first phase. Defaults to 10.
#' @param phase_changes Optional vector of index positions or values
#'   at which to force a phase change. If `NULL`, phase changes are
#'   detected automatically using the supplied `phase_rule`.
#' @param phase_rule Character. Runs rule used to detect new phases.
#'   See [shewhart_rules_available()]. Default Nelson 2 (9 points
#'   same side; ARL_0 ~ 256). For backward compatibility with v0.1.x,
#'   use `"we_seven_same"` (7 points; ARL_0 ~ 64).
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
#'   phase).
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
                                start_base    = 10L,
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
  start_base   <- check_scalar_int(start_base, min = 5L)

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
    # Convert user-supplied phase_changes to integer positions
    idx_v <- dplyr::pull(data, !!i_q)
    phase_positions <- which(idx_v %in% phase_changes)
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
  attr(augmented, "fits") <- NULL

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
    sigma_hat    = stats::median(augmented$.sigma, na.rm = TRUE),
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
      locale     = locale
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
      lambda <- shewhart_box_cox_lambda(d[[v_n]] + 1)
      if (abs(lambda) < 0.1) model <- "log"
      else if (abs(lambda - 0.5) < 0.1) model <- "loglog"
      else model <- "linear"
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

#' Compute fitted values on the original scale, given a model
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
      # nls fits cumulative; recover increments
      c(pred[1], diff(pred))
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

    if (nrow(last_phase) > 9L) {
      flag_col <- paste0(".flag_", phase_rule)
      hit <- which(last_phase[[flag_col]])
      if (length(hit) > 0L) {
        new_pos <- last_phase$.obs[hit[1]] + 1L
        if (!new_pos %in% positions && new_pos < nrow(data)) {
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

  fits <- vector("list", length = max(phase) + 1L)
  out  <- vector("list", length = nrow(d))

  for (p in unique(phase)) {
    sub <- d[d$.phase == p, , drop = FALSE]
    sub$.N <- seq_len(nrow(sub))
    if (nrow(sub) < 3L) {
      # Not enough data; reuse previous phase's fit
      fit <- if (p > 0L) fits[[p]] else NULL
    } else {
      fit <- fit_one_phase(sub, value_q, index_q, dummy_q, model, formula)
    }
    fits[[p + 1L]] <- fit

    if (is.null(fit)) {
      sub$.fitted <- NA_real_
    } else {
      sub$.fitted <- predict_original(fit, sub, v_n)
    }

    # Sigma from residuals (on original scale, simple choice)
    resid <- sub[[v_n]] - sub$.fitted
    sigma_hat <- switch(
      sigma_method,
      mr        = mr_bar(resid) / 1.128,
      median_mr = stats::median(moving_range(resid), na.rm = TRUE) / 0.954,
      biweight  = unname(biweight(resid)["scale"]),
      sd        = stats::sd(resid, na.rm = TRUE)
    )
    if (!is.finite(sigma_hat) || sigma_hat <= 0) sigma_hat <- 1
    sub$.center <- sub$.fitted
    sub$.sigma  <- sigma_hat
    sub$.upper  <- sub$.fitted + 3 * sigma_hat
    sub$.lower  <- sub$.fitted - 3 * sigma_hat
    if (!is.na(lower_bound)) sub$.lower <- pmax(lower_bound, sub$.lower)

    out[[p + 1L]] <- sub
  }

  augmented <- dplyr::bind_rows(out)
  augmented$.value <- augmented[[v_n]]

  # Phase labels (locale-aware)
  augmented$.phase_label <- with(augmented,
    ifelse(
      .phase == 0L, tr("phase_base", locale),
      ifelse(.phase == max(.phase), tr("phase_monitoring", locale),
             vapply(.phase, function(p) tr("phase_n", locale, p),
                    character(1L)))
    )
  )

  # Apply rule flags -------------------------------------------------------
  flags <- flag_rules(augmented$.value, augmented$.center, augmented$.sigma, rules)
  augmented <- dplyr::bind_cols(augmented, flags)

  attr(augmented, "fits") <- fits
  augmented
}
