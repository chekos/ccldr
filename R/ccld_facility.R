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

#' Pull full CCLD facility detail for many licenses
#'
#' `ccld_facilities()` is the bulk full-detail companion to [ccld_facility()].
#' It calls the one-facility CCLD detail endpoints for each unique license,
#' then expands results back to the original input order. Unknown or invalid
#' licenses are kept as `found = FALSE` rows with missing scalar fields and
#' empty `reports` and `complaints` list-columns.
#'
#' Use [ccld_verify()] when you only need the slim verification schema. Use
#' `ccld_facilities()` when you need full detail for a whole column of
#' facilities, including visit counts, reports, and itemized complaints.
#'
#' @inheritParams ccld_facility
#' @param facnums Character or numeric vector of facility license numbers.
#'   Accepts 8- or 9-digit forms; padded internally via [ccld_pad()].
#'
#' @return A tibble with one row per input, a `found` column, scalar facility
#'   detail fields, and list-columns `reports` and `complaints`.
#' @family facility detail
#' @seealso [ccld_facility()] for the scalar full-detail helper and
#'   [ccld_verify()] for slim bulk verification.
#' @export
#' @examples
#' \dontrun{
#' ccld_facilities(c("13423996", "99999999"))
#' }
ccld_facilities <- function(facnums, cache = TRUE) {
  if (rlang::is_empty(facnums)) {
    return(empty_full_tibble())
  }

  input <- as.character(facnums)
  padded <- ccld_pad(facnums)
  unique_padded <- unique(stats::na.omit(padded))

  show_progress <- length(unique_padded) > 10 && interactive()
  if (show_progress) {
    cli::cli_progress_bar("Pulling facility details", total = length(unique_padded))
  }

  fetched <- vector("list", length(unique_padded))
  names(fetched) <- unique_padded
  for (i in seq_along(unique_padded)) {
    detail <- ccldr_fetch_json(
      paste0("FacilityDetail/", unique_padded[[i]]),
      cache = cache
    )
    found <- !is.na(empty_to_na((detail$FacilityDetail %||% list())$STATUS))
    reports <- if (found) {
      ccldr_fetch_json(paste0("FacilityReports/", unique_padded[[i]]), cache = cache)
    } else {
      list()
    }
    fetched[[i]] <- list(detail = detail, reports = reports, found = found)

    if (show_progress) {
      cli::cli_progress_update()
    }
  }
  if (show_progress) {
    cli::cli_progress_done()
  }

  rows <- lapply(seq_along(input), function(i) {
    if (is.na(padded[[i]])) {
      return(parse_full_missing_row(input[[i]]))
    }

    facility <- fetched[[padded[[i]]]]
    if (!isTRUE(facility$found)) {
      return(parse_full_missing_row(input[[i]]))
    }

    row <- parse_full_row(facility$detail, facility$reports, input = input[[i]])
    tibble::add_column(row, found = TRUE, .after = "facility_number")
  })
  do.call(rbind, rows)
}
