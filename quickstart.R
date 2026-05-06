# quickstart.R --- bootstrap the package on first checkout
#
# Run from the package root in a fresh R session. Executes the full
# document/build_data/check pipeline.
#
#   source("quickstart.R")
#
# Requires: devtools, usethis, roxygen2, pkgdown.

stopifnot(file.exists("DESCRIPTION"))

cat("\n[1/5] Generating NAMESPACE and man/*.Rd from roxygen comments...\n")
devtools::document()

cat("\n[2/5] Building synthetic + COVID datasets in data/...\n")
source("data-raw/build_all.R")

cat("\n[3/5] Re-documenting (datasets need it after build_all)...\n")
devtools::document()

cat("\n[4/5] Running test suite...\n")
devtools::test()

cat("\n[5/5] Building pkgdown site (optional)...\n")
ans <- readline(prompt = "Build pkgdown site now? [y/N] ")
if (tolower(ans) == "y") {
  pkgdown::build_site()
} else {
  cat("Skipped. Run pkgdown::build_site() later if you want the site.\n")
}

cat("\nDone. Run devtools::check() to verify CRAN-readiness.\n")
