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
#' Available top-level columns are: `input`, `facility_number`, `found`,
#' `facility_name`, `facility_type`, `status`, `licensee_name`, `contact`,
#' `street_address`, `city`, `state`, `zip`, `county`, `telephone`,
#' `capacity`, `client_served_1`, `client_served_2`, `client_served_3`,
#' `client_served_4`, `client_served_5`, `client_served_6`, `comments`,
#' `comments_2`, `license_effective_date`, `license_first_date`,
#' `date_closed`, `last_visit_date`, `visits_total`, `visits_complaints`,
#' `visits_inspections`, `visits_other`, `cmplt_type_a`, `cmplt_type_b`,
#' `cmplt_substantiated`, `cmplt_unsubstantiated`, `cmplt_inconclusive`,
#' `cmplt_unfounded`, `insp_type_a`, `insp_type_b`, `other_type_a`,
#' `other_type_b`, `visit_date_all`, `visit_date_complaint`,
#' `visit_date_inspection`, `visit_date_other`, `district_office`,
#' `district_office_address`, `district_office_city`, `district_office_state`,
#' `district_office_zip`, `district_office_phone`, `complaint_count`,
#' `total_complaint_visits`, `total_substantiated_allegations`,
#' `total_inconclusive_allegations`, `total_unsubstantiated_allegations`,
#' `total_unfounded_allegations`, `total_type_a`, `total_type_b`, `reports`,
#' and `complaints`.
#'
#' The `reports` list-column contains tibbles with `report_date`,
#' `report_title`, `report_type`, `report_page`, and `control_number`. The
#' `complaints` list-column contains tibbles with `complaint_date`,
#' `allegation`, and `outcome`.
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
