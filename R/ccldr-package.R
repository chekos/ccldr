#' ccldr: R client for the CCLD Transparency API
#'
#' Verify facility license numbers, pull rich per-facility detail, and snapshot
#' Alameda child-care facilities from the California Community Care Licensing
#' Division's undocumented Transparency API.
#'
#' @section Package options:
#'
#' \describe{
#'   \item{`ccldr.delay`}{Seconds between requests in batch mode. Default 0.5.}
#'   \item{`ccldr.cache_ttl_seconds`}{Cache TTL in seconds. Default 86400 (24h).}
#'   \item{`ccldr.verbose`}{If `TRUE`, log one line per HTTP request. Default `FALSE`.}
#' }
#'
#' @keywords internal
"_PACKAGE"

.onLoad <- function(libname, pkgname) {
  options(
    ccldr.delay = getOption("ccldr.delay", 0.5),
    ccldr.cache_ttl_seconds = getOption("ccldr.cache_ttl_seconds", 86400),
    ccldr.verbose = getOption("ccldr.verbose", FALSE)
  )
}
