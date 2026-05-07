# Local pkgdown build with orphan cleanup
#
# pkgdown:::package_mds() renders every *.md at the package root as an
# HTML page; the allow-list is hardcoded (README/LICENSE/NEWS/404/
# issue_template/pull_request_template/cran-comments) and there is no
# config to opt out. CLAUDE.md must stay in the repo for Claude Code,
# so we delete its rendered output after build_site() finishes.
#
# Usage from the package root:
#   source("dev/build_site.R")

stopifnot(file.exists("DESCRIPTION"))

pkgdown::build_site(preview = FALSE, devel = FALSE)

orphans <- c("CLAUDE.html", "CLAUDE.md")
existing <- file.path("docs", orphans)
existing <- existing[file.exists(existing)]
if (length(existing)) {
  cat("Removing orphan top-level docs:\n  ",
      paste(existing, collapse = "\n  "), "\n", sep = "")
  unlink(existing)
}
