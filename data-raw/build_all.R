# Synthetic dataset generation -------------------------------------------
#
# All datasets shipped with the package are generated from the scripts
# in `data-raw/`. Each script sets a seed, generates a tibble, calls
# usethis::use_data(), and writes a README entry.
#
# Run all scripts with: source("data-raw/build_all.R")

library(usethis)

set.seed(20251101)

# tablet_weight ----------------------------------------------------------
# Pharmaceutical tablet weight, 25 subgroups of 5 tablets each.
# Target: 250 mg, in-control sigma: 1.5 mg. A small mean shift is
# embedded in subgroups 18-25 to make the chart pedagogically
# interesting.

tablet_weight <- tibble::tibble(
  subgroup = rep(1:25, each = 5L),
  tablet   = rep(1:5,  times = 25L),
  weight   = c(
    rnorm(17 * 5, mean = 250.0, sd = 1.5),
    rnorm( 8 * 5, mean = 251.5, sd = 1.5)
  )
)
usethis::use_data(tablet_weight, overwrite = TRUE)

# bottle_fill ------------------------------------------------------------
# Beverage bottle fill volume. Individual measurements (no rational
# subgroup), 100 observations. A drift starts around obs 65 - sensors
# in the filler need recalibration.

bottle_fill <- tibble::tibble(
  observation = 1:100,
  ml = c(
    rnorm(64, mean = 500.0, sd = 1.2),
    500 + 0.04 * 1:36 + rnorm(36, mean = 0, sd = 1.2)
  )
)
usethis::use_data(bottle_fill, overwrite = TRUE)

# pcb_solder -------------------------------------------------------------
# Defects in solder joints on printed circuit boards. 50 boards, c
# chart canonical setup. Mean number of defects ~6.

pcb_solder <- tibble::tibble(
  board   = 1:50,
  defects = rpois(50, lambda = 6)
)
usethis::use_data(pcb_solder, overwrite = TRUE)

# claims_p ---------------------------------------------------------------
# Daily proportion of insurance claims with errors. Variable subgroup
# size n (number of claims processed each day, 80-150). Underlying
# defect rate ~5% with a spike in last week of the month.

claims_p <- tibble::tibble(
  day     = 1:30,
  n       = sample(80:150, 30L, replace = TRUE),
  defects = NA_integer_
)
claims_p$defects <- vapply(seq_len(30L), function(i) {
  p <- if (i <= 22L) 0.05 else 0.09
  stats::rbinom(1L, size = claims_p$n[i], prob = p)
}, integer(1L))
usethis::use_data(claims_p, overwrite = TRUE)

# temperature_drift ------------------------------------------------------
# Sensor reading on a curing oven. 200 observations. The sensor exhibits
# a slow linear drift, perfect for a regression chart - a classical
# Shewhart chart would systematically misjudge the limits.

temperature_drift <- tibble::tibble(
  minute = 1:200,
  temp_c = 180 + 0.05 * 1:200 +
           sin(2 * pi * 1:200 / 50) * 0.5 +
           rnorm(200, sd = 0.4)
)
usethis::use_data(temperature_drift, overwrite = TRUE)

# bacterial_growth -------------------------------------------------------
# Optical density measurements of bacterial culture. 80 observations
# over time. Underlying Gompertz growth.

bacterial_growth <- tibble::tibble(
  hour = seq(0, 24, length.out = 80L),
  od   = NA_real_
)
true <- 1.2 * exp(-2 * exp(-0.25 * bacterial_growth$hour))
bacterial_growth$od <- true + rnorm(80, sd = 0.04)
usethis::use_data(bacterial_growth, overwrite = TRUE)

# cvd_recife -------------------------------------------------------------
# COVID-19 daily mortality time series for Recife, capital of Pernambuco
# (Brazil), 2020. Originally distributed with v0.1.x of the package as
# `inst/extdata/recife_2020_covid19.rds`. Preserved here as a vignette
# case study illustrating the regression-chart workflow on
# non-stationary epidemiological counts.

raw_rds <- system.file("extdata", "cvd_recife_raw.rds", package = "shewhartr")
if (!nzchar(raw_rds)) raw_rds <- "inst/extdata/cvd_recife_raw.rds"

cvd_raw <- readRDS(raw_rds)
# Normalise to a clean schema: date (Date), new_deaths (integer), with
# a row index (.t) for use as the regression-chart predictor. The
# original column names from the source rds are `data` (Portuguese for
# "date") and `obitosNovos` (new deaths).
cvd_recife <- tibble::tibble(
  date       = as.Date(cvd_raw[["data"]]),
  new_deaths = as.integer(cvd_raw[["obitosNovos"]])
)
cvd_recife$.t <- seq_len(nrow(cvd_recife))
usethis::use_data(cvd_recife, overwrite = TRUE)
