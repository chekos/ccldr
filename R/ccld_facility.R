#' Pull the full CCLD facility detail for one license
#'
#' Returns the facility detail fields exposed by the Transparency API, plus
#' nested list-columns for evaluation reports and itemized complaints. Use
#' `tidyr::unnest()` to flatten either list-column.
#'
#' @param facnum A single facility license number, character or numeric.
#'   Accepts 8- or 9-digit forms; padded internally via [ccld_pad()].
#' @param cache If `TRUE` (default), use the on-disk response cache.
#'
#' @return A one-row tibble with scalar facility fields and list-columns
#'   `reports` and `complaints`.
#' @export
#' @examples
#' \dontrun{
#' ccld_facility("13423996")
#' }
ccld_facility <- function(facnum, cache = TRUE) {
  if (length(facnum) != 1) {
    cli::cli_abort("ccld_facility() takes one license number; got {length(facnum)}.")
  }

  padded <- ccld_pad(facnum)
  if (is.na(padded)) {
    cli::cli_abort("License is NA.", class = "ccldr_invalid_input")
  }

  detail <- ccldr_fetch_json(paste0("FacilityDetail/", padded), cache = cache)
  reports <- ccldr_fetch_json(paste0("FacilityReports/", padded), cache = cache)
  parse_full_row(detail, reports, input = as.character(facnum))
}
