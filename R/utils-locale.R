# Internationalisation system ---------------------------------------------
#
# A simple translation system. Each user-facing label lives in
# `.shewhart_messages` keyed first by language ("en", "pt", "es", "fr")
# and then by message key. tr() looks up the message; missing translations
# fall back to English; missing keys fall back to the literal key.
#
# Plot labels are the primary use case. Validation errors (cli::cli_abort)
# stay in English to keep error messages diffable across users; user
# control is via the `locale` argument on plotting / chart functions.

.shewhart_supported_locales <- c("en", "pt", "es", "fr")

.shewhart_messages <- list(
  en = list(
    # axis labels
    label_observation     = "Observation",
    label_subgroup        = "Subgroup",
    label_value           = "Value",
    label_individual      = "Individual",
    label_moving_range    = "Moving range",
    label_mean            = "Mean",
    label_range           = "Range",
    label_std_dev         = "Standard deviation",
    label_proportion      = "Proportion",
    label_count           = "Count",
    label_count_per_unit  = "Count per unit",
    label_index           = "Index",
    # chart titles
    title_i_mr            = "I-MR chart",
    title_xbar_r          = "Xbar-R chart",
    title_xbar_s          = "Xbar-S chart",
    title_p               = "p chart (proportion of nonconforming)",
    title_np              = "np chart (number of nonconforming)",
    title_c               = "c chart (number of nonconformities)",
    title_u               = "u chart (nonconformities per unit)",
    title_regression      = "Regression control chart",
    title_ewma            = "EWMA chart",
    title_cusum           = "CUSUM chart",
    title_hotelling       = "Hotelling T\u00b2 chart",
    title_mewma           = "Multivariate EWMA chart",
    title_mcusum          = "Multivariate CUSUM chart",
    label_mcusum          = "MCUSUM statistic",
    label_ewma            = "EWMA",
    label_cusum           = "CUSUM",
    label_t2              = "T\u00b2",
    # legend / annotation
    legend_phase          = "Phase",
    legend_phases         = "Phases",
    legend_status         = "Status",
    status_in_control     = "In control",
    status_out_of_control = "Out of control",
    label_ucl             = "UCL",
    label_lcl             = "LCL",
    label_cl              = "CL",
    label_target          = "Target",
    # phase strings
    phase_base            = "Base",
    phase_monitoring      = "Monitoring",
    phase_n               = "Phase %d",
    # diagnostics
    diag_residuals_fitted = "Residuals vs. Fitted",
    diag_qq_normal        = "Normal Q-Q",
    diag_acf              = "Autocorrelation",
    diag_mr_plot          = "Moving range",
    diag_histogram        = "Residual histogram",
    diag_box_cox          = "Box-Cox profile log-likelihood",
    diag_lambda           = "lambda"
  ),
  pt = list(
    label_observation     = "Observa\u00e7\u00e3o",
    label_subgroup        = "Subgrupo",
    label_value           = "Valor",
    label_individual      = "Individual",
    label_moving_range    = "Amplitude m\u00f3vel",
    label_mean            = "M\u00e9dia",
    label_range           = "Amplitude",
    label_std_dev         = "Desvio padr\u00e3o",
    label_proportion      = "Propor\u00e7\u00e3o",
    label_count           = "Contagem",
    label_count_per_unit  = "Contagem por unidade",
    label_index           = "\u00cdndice",
    title_i_mr            = "Carta I-MR",
    title_xbar_r          = "Carta Xbar-R",
    title_xbar_s          = "Carta Xbar-S",
    title_p               = "Carta p (propor\u00e7\u00e3o de defeituosos)",
    title_np              = "Carta np (n\u00famero de defeituosos)",
    title_c               = "Carta c (n\u00famero de defeitos)",
    title_u               = "Carta u (defeitos por unidade)",
    title_regression      = "Carta de controle por regress\u00e3o",
    title_ewma            = "Carta EWMA",
    title_cusum           = "Carta CUSUM",
    title_hotelling       = "Carta Hotelling T\u00b2",
    title_mewma           = "Carta MEWMA multivariada",
    title_mcusum          = "Carta MCUSUM multivariada",
    label_mcusum          = "Estat\u00edstica MCUSUM",
    label_ewma            = "EWMA",
    label_cusum           = "CUSUM",
    label_t2              = "T\u00b2",
    legend_phase          = "Fase",
    legend_phases         = "Fases",
    legend_status         = "Status",
    status_in_control     = "Sob controle",
    status_out_of_control = "Fora de controle",
    label_ucl             = "LSC",
    label_lcl             = "LIC",
    label_cl              = "LC",
    label_target          = "Alvo",
    phase_base            = "Base",
    phase_monitoring      = "Monitorando",
    phase_n               = "Fase %d",
    diag_residuals_fitted = "Res\u00edduos vs. Ajustados",
    diag_qq_normal        = "Q-Q Normal",
    diag_acf              = "Autocorrela\u00e7\u00e3o",
    diag_mr_plot          = "Amplitude m\u00f3vel",
    diag_histogram        = "Histograma dos res\u00edduos",
    diag_box_cox          = "Log-verossimilhan\u00e7a perfilada Box-Cox",
    diag_lambda           = "lambda"
  ),
  es = list(
    label_observation     = "Observaci\u00f3n",
    label_subgroup        = "Subgrupo",
    label_value           = "Valor",
    label_individual      = "Individual",
    label_moving_range    = "Rango m\u00f3vil",
    label_mean            = "Media",
    label_range           = "Rango",
    label_std_dev         = "Desviaci\u00f3n est\u00e1ndar",
    label_proportion      = "Proporci\u00f3n",
    label_count           = "Conteo",
    label_count_per_unit  = "Conteo por unidad",
    label_index           = "\u00cdndice",
    title_i_mr            = "Carta I-MR",
    title_xbar_r          = "Carta Xbar-R",
    title_xbar_s          = "Carta Xbar-S",
    title_p               = "Carta p (proporci\u00f3n de no conformes)",
    title_np              = "Carta np (n\u00famero de no conformes)",
    title_c               = "Carta c (n\u00famero de no conformidades)",
    title_u               = "Carta u (no conformidades por unidad)",
    title_regression      = "Carta de control por regresi\u00f3n",
    title_ewma            = "Gr\u00e1fico EWMA",
    title_cusum           = "Gr\u00e1fico CUSUM",
    title_hotelling       = "Gr\u00e1fico Hotelling T\u00b2",
    title_mewma           = "Gr\u00e1fico MEWMA multivariado",
    title_mcusum          = "Gr\u00e1fico MCUSUM multivariado",
    label_mcusum          = "Estad\u00edstico MCUSUM",
    label_ewma            = "EWMA",
    label_cusum           = "CUSUM",
    label_t2              = "T\u00b2",
    legend_phase          = "Fase",
    legend_phases         = "Fases",
    legend_status         = "Estado",
    status_in_control     = "Bajo control",
    status_out_of_control = "Fuera de control",
    label_ucl             = "LSC",
    label_lcl             = "LIC",
    label_cl              = "LC",
    label_target          = "Objetivo",
    phase_base            = "Base",
    phase_monitoring      = "Monitoreo",
    phase_n               = "Fase %d",
    diag_residuals_fitted = "Residuos vs. Ajustados",
    diag_qq_normal        = "Q-Q Normal",
    diag_acf              = "Autocorrelaci\u00f3n",
    diag_mr_plot          = "Rango m\u00f3vil",
    diag_histogram        = "Histograma de residuos",
    diag_box_cox          = "Log-verosimilitud perfilada Box-Cox",
    diag_lambda           = "lambda"
  ),
  fr = list(
    label_observation     = "Observation",
    label_subgroup        = "Sous-groupe",
    label_value           = "Valeur",
    label_individual      = "Individuel",
    label_moving_range    = "\u00c9tendue mobile",
    label_mean            = "Moyenne",
    label_range           = "\u00c9tendue",
    label_std_dev         = "\u00c9cart-type",
    label_proportion      = "Proportion",
    label_count           = "Comptage",
    label_count_per_unit  = "Comptage par unit\u00e9",
    label_index           = "Indice",
    title_i_mr            = "Carte I-MR",
    title_xbar_r          = "Carte Xbar-R",
    title_xbar_s          = "Carte Xbar-S",
    title_p               = "Carte p (proportion de non-conformes)",
    title_np              = "Carte np (nombre de non-conformes)",
    title_c               = "Carte c (nombre de non-conformit\u00e9s)",
    title_u               = "Carte u (non-conformit\u00e9s par unit\u00e9)",
    title_regression      = "Carte de contr\u00f4le par r\u00e9gression",
    title_ewma            = "Carte EWMA",
    title_cusum           = "Carte CUSUM",
    title_hotelling       = "Carte Hotelling T\u00b2",
    title_mewma           = "Carte MEWMA multivari\u00e9e",
    title_mcusum          = "Carte MCUSUM multivari\u00e9e",
    label_mcusum          = "Statistique MCUSUM",
    label_ewma            = "EWMA",
    label_cusum           = "CUSUM",
    label_t2              = "T\u00b2",
    legend_phase          = "Phase",
    legend_phases         = "Phases",
    legend_status         = "Statut",
    status_in_control     = "Sous contr\u00f4le",
    status_out_of_control = "Hors contr\u00f4le",
    label_ucl             = "LSC",
    label_lcl             = "LIC",
    label_cl              = "LC",
    label_target          = "Cible",
    phase_base            = "Base",
    phase_monitoring      = "Surveillance",
    phase_n               = "Phase %d",
    diag_residuals_fitted = "R\u00e9sidus vs. Ajust\u00e9s",
    diag_qq_normal        = "Q-Q Normal",
    diag_acf              = "Autocorr\u00e9lation",
    diag_mr_plot          = "\u00c9tendue mobile",
    diag_histogram        = "Histogramme des r\u00e9sidus",
    diag_box_cox          = "Log-vraisemblance profil\u00e9e Box-Cox",
    diag_lambda           = "lambda"
  )
)

#' Translate a message key into the requested locale
#'
#' Internal helper used by chart constructors and plotting methods to
#' look up user-facing labels. Falls back to English if the locale
#' or key is not registered.
#'
#' @param key Character. Message key (e.g. `"label_value"`).
#' @param locale Character. Two-letter language code. Defaults to the
#'   value of the `shewhart.locale` option.
#' @param ... Optional `sprintf()` arguments for parameterised
#'   messages (e.g. `tr("phase_n", locale = "pt", 3)` returns
#'   `"Fase 3"`).
#'
#' @return A character string with the translated message.
#'
#' @keywords internal
#' @noRd
tr <- function(key, locale = NULL, ...) {
  locale <- locale %||% getOption("shewhart.locale", "en")
  if (!locale %in% .shewhart_supported_locales) locale <- "en"
  msg <- .shewhart_messages[[locale]][[key]] %||%
         .shewhart_messages[["en"]][[key]] %||%
         key
  args <- list(...)
  if (length(args) > 0L && grepl("%", msg, fixed = TRUE)) {
    msg <- do.call(sprintf, c(list(msg), args))
  }
  msg
}

#' Validate a locale argument
#'
#' @keywords internal
#' @noRd
check_locale <- function(locale, arg = rlang::caller_arg(locale),
                         call = rlang::caller_env()) {
  if (!is.character(locale) || length(locale) != 1L) {
    cli::cli_abort(
      "{.arg {arg}} must be a single string, not {.obj_type_friendly {locale}}.",
      call = call
    )
  }
  if (!locale %in% .shewhart_supported_locales) {
    supported <- .shewhart_supported_locales
    cli::cli_abort(
      c("{.arg {arg}} = {.val {locale}} is not supported.",
        "i" = "Supported locales: {.val {supported}}."),
      call = call
    )
  }
  invisible(locale)
}
