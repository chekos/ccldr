#' ccldr: R client for the CCLD Transparency API
#'
#' Verify facility license numbers, pull rich per-facility detail, snapshot
#' Alameda child-care facilities, and append Census geographies using public
#' CCLD and Census APIs.
#'
#' @section Package options:
#'
#' \describe{
#'   \item{`ccldr.delay`}{Seconds between requests in batch mode. Default `0.5`.}
#'   \item{`ccldr.cache_ttl_seconds`}{Cache TTL in seconds. Default `86400` (24 hours).}
#'   \item{`ccldr.verbose`}{If `TRUE`, log one line per HTTP request. Default `FALSE`.}
#' }
#'
#' @seealso
#'   - [ccld_verify()] to verify many license numbers.
#'   - [ccld_facility()] to fetch full detail for one license.
#'   - [ccld_alameda()] to build live Alameda facility snapshots.
#'   - [ccld_add_census_geographies()] to append geocodes and Census geography.
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
