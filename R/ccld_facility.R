#' Pull the full CCLD facility detail for one license
#'
#' Returns the facility detail fields exposed by the Transparency API, plus
#' nested list-columns for evaluation reports and itemized complaints. Use
#' `tidyr::unnest()` to flatten either list-column after inspecting the scalar
#' facility fields.
#'
#' `ccld_facility()` is intentionally scalar: pass one facility license number
#' at a time. Use [ccld_verify()] first when you need to screen a vector of
#' candidate licenses. Unknown facilities raise a `ccldr_not_found` error.
#'
#' @param facnum A single facility license number, character or numeric.
#'   Accepts 8- or 9-digit forms; padded internally via [ccld_pad()].
#' @param cache Logical value (default `TRUE`) controlling whether the on-disk
#'   response cache is used.
#'
#' @return A one-row tibble with scalar facility fields and list-columns
#'   `reports` and `complaints`.
#' @family facility detail
#' @seealso [ccld_verify()] to check whether licenses exist before requesting
#'   full detail.
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
