# Dataset documentation ---------------------------------------------------

#' Pharmaceutical tablet weights
#'
#' A synthetic dataset modelled on classical pharmaceutical quality
#' control. Tablet weights are recorded in subgroups of 5 tablets
#' each, across 25 production batches. Target weight is 250 mg with
#' a process sigma of 1.5 mg; a small mean shift to 251.5 mg is
#' embedded in subgroups 18-25.
#'
#' @format A tibble with 125 rows and 3 columns:
#' \describe{
#'   \item{subgroup}{Integer batch identifier (1-25).}
#'   \item{tablet}{Integer tablet position within the batch (1-5).}
#'   \item{weight}{Numeric tablet weight in milligrams.}
#' }
#'
#' @source Synthetic. See `data-raw/build_all.R`.
#' @seealso [shewhart_xbar_r()], [shewhart_xbar_s()].
#'
#' @examples
#' fit <- shewhart_xbar_r(tablet_weight, value = weight, subgroup = subgroup)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
"tablet_weight"

#' Bottle filling volumes
#'
#' A synthetic dataset of 100 individual fill volumes (in millilitres).
#' Process target is 500 ml with sigma 1.2 ml. A linear drift begins
#' around observation 65, simulating a slowly miscalibrating filler.
#'
#' @format A tibble with 100 rows and 2 columns:
#' \describe{
#'   \item{observation}{Integer observation index.}
#'   \item{ml}{Numeric volume in millilitres.}
#' }
#'
#' @source Synthetic. See `data-raw/build_all.R`.
#' @seealso [shewhart_i_mr()].
#'
#' @examples
#' fit <- shewhart_i_mr(bottle_fill, value = ml, index = observation)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
"bottle_fill"

#' Solder defects on printed circuit boards
#'
#' A synthetic Poisson dataset: number of defective solder joints on
#' each of 50 inspected printed circuit boards. The mean is 6, ideal
#' for either the 3-sigma c chart or its more honest cousin with
#' exact Poisson limits.
#'
#' @format A tibble with 50 rows and 2 columns:
#' \describe{
#'   \item{board}{Integer board identifier.}
#'   \item{defects}{Integer count of defective joints.}
#' }
#'
#' @source Synthetic. See `data-raw/build_all.R`.
#' @seealso [shewhart_c()].
#'
#' @examples
#' fit       <- shewhart_c(pcb_solder, defects = defects, index = board)
#' fit_exact <- shewhart_c(pcb_solder, defects = defects, index = board,
#'                         limits = "poisson")
"pcb_solder"

#' Daily insurance claim error rates
#'
#' A synthetic dataset of 30 days. Each day, a variable number of
#' claims is processed (80-150) and the count of claims with errors
#' is recorded. Underlying error rate is 5% for the first 22 days
#' and 9% thereafter.
#'
#' @format A tibble with 30 rows and 3 columns:
#' \describe{
#'   \item{day}{Integer day index (1-30).}
#'   \item{n}{Integer total claims processed that day.}
#'   \item{defects}{Integer claims found with errors.}
#' }
#'
#' @source Synthetic. See `data-raw/build_all.R`.
#' @seealso [shewhart_p()].
#'
#' @examples
#' fit <- shewhart_p(claims_p, defects = defects, n = n, index = day)
#' \donttest{
#' ggplot2::autoplot(fit)
#' }
"claims_p"

#' Curing oven temperature drift
#'
#' A synthetic dataset of 200 sensor readings on a curing oven. The
#' true temperature exhibits a slow linear drift superimposed on a
#' periodic component. A classical Shewhart chart will misjudge the
#' limits because the process is non-stationary - a regression
#' control chart is the right tool.
#'
#' @format A tibble with 200 rows and 2 columns:
#' \describe{
#'   \item{minute}{Integer minute since start.}
#'   \item{temp_c}{Numeric temperature in degrees Celsius.}
#' }
#'
#' @source Synthetic. See `data-raw/build_all.R`.
#' @seealso [shewhart_regression()].
#'
#' @examples
#' \donttest{
#' fit <- shewhart_regression(temperature_drift,
#'                            value = temp_c, index = minute,
#'                            model = "linear")
#' ggplot2::autoplot(fit)
#' }
"temperature_drift"

#' Bacterial growth curve (optical density)
#'
#' A synthetic dataset of optical density (OD) measurements from a
#' bacterial culture, sampled at 80 evenly spaced time points across
#' a 24-hour incubation. The true mean follows a Gompertz growth
#' curve with asymptote 1.2.
#'
#' @format A tibble with 80 rows and 2 columns:
#' \describe{
#'   \item{hour}{Numeric time in hours since inoculation.}
#'   \item{od}{Numeric optical density at 600 nm.}
#' }
#'
#' @source Synthetic. See `data-raw/build_all.R`.
#' @seealso [shewhart_regression()] with `model = "gompertz"`,
#'   [Gompertz()].
#'
#' @examples
#' \donttest{
#' fit <- shewhart_regression(bacterial_growth,
#'                            value = od, index = hour,
#'                            model = "gompertz")
#' ggplot2::autoplot(fit)
#' }
"bacterial_growth"

#' COVID-19 daily mortality, Recife, Brazil, 2020
#'
#' Daily count of new COVID-19 deaths officially recorded in Recife
#' (capital of Pernambuco state, Brazil) between 28 March 2020 and
#' 31 December 2020. Distributed with v0.1.x as
#' `inst/extdata/recife_2020_covid19.rds` and preserved in v1.0.0
#' as a vignette case study illustrating the regression-based control
#' chart on non-stationary epidemiological counts.
#'
#' @format A tibble with 279 rows and 3 columns:
#' \describe{
#'   \item{date}{Date of the bulletin.}
#'   \item{new_deaths}{Integer count of new deaths reported that day.}
#'   \item{.t}{Integer row index (1..N), useful as a continuous
#'     predictor for [shewhart_regression()].}
#' }
#'
#' @source Castlab (Universidade Federal de Pernambuco) compiled
#'   the original series from the Brazilian Ministry of Health daily
#'   bulletins. See <https://covid.saude.gov.br/>.
#' @seealso [shewhart_regression()],
#'   `vignette("covid-recife", package = "shewhartr")`.
#'
#' @examples
#' \donttest{
#' fit <- shewhart_regression(cvd_recife,
#'                            value = new_deaths, index = .t,
#'                            model = "loglog")
#' ggplot2::autoplot(fit)
#' }
"cvd_recife"
