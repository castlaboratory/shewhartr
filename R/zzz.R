# Package-level options and lifecycle hooks --------------------------------

.shewhart_default_options <- list(
  shewhart.locale  = "en",
  shewhart.verbose = FALSE
)

.onLoad <- function(libname, pkgname) {
  op <- options()
  to_set <- !names(.shewhart_default_options) %in% names(op)
  if (any(to_set)) options(.shewhart_default_options[to_set])
  invisible()
}
