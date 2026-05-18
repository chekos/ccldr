ALAMEDA_TYPE_MAP <- c(
  large_fccs = "810",
  infant_centers = "830",
  school_age_centers = "840",
  preschools = "850",
  single_licensed_centers = "860"
)

ALAMEDA_CITIES <- c(
  "Alameda", "Albany", "Berkeley", "Castro Valley", "Dublin",
  "Emeryville", "Fremont", "Hayward", "Livermore", "Newark",
  "Oakland", "Piedmont", "Pleasanton", "San Leandro", "San Lorenzo",
  "Sunol", "Union City"
)

alameda_factype_for <- function(type) {
  choices <- names(ALAMEDA_TYPE_MAP)
  matched <- tryCatch(
    match.arg(type, choices = choices),
    error = function(e) NULL
  )
  if (is.null(matched)) {
    cli::cli_abort(
      c(
        "Invalid {.arg type}.",
        "x" = "Got: {.val {type}}",
        "i" = "Use one of: {.val {choices}}",
        "i" = "`small_fccs` is blocked by the API; use the CKAN snapshot.",
        "i" = "`centers` maps to a sparse legacy API bucket; use `preschools`."
      ),
      class = "ccldr_invalid_input"
    )
  }
  unname(ALAMEDA_TYPE_MAP[[matched]])
}

alameda_search_city <- function(factype, city, cache = TRUE) {
  path <- paste0(
    "FacilitySearch?facType=", factype,
    "&facility=&Street=&city=", utils::URLencode(city),
    "&zip=&county=&facnum="
  )
  body <- ccldr_fetch_json(path, cache = cache)
  out <- parse_search_array(body)
  if (nrow(out) > 0) {
    out$city <- city
  }
  attr(out, "ccldr_count") <- suppressWarnings(as.integer(body$COUNT %||% nrow(out)))
  out
}

#' Live Alameda snapshot for a child-care facility type
#'
#' Pulls the current set of Alameda County child-care facilities of the given
#' type from the live CCLD Transparency API. Internally, the function walks the
#' 17 Alameda cities to work around the API's 250-result per-call cap, unions
#' the rows, and deduplicates by `facility_number`.
#'
#' Two facility types are deliberately unsupported: `"small_fccs"` because the
#' API blocks `facType = 0` searches, and `"centers"` because the API's
#' `facType = 845` bucket only contains a few legacy records statewide. For the
#' center workflow, use `"preschools"` (`facType = 850`).
#'
#' If any city query reports 250 or more results, `ccld_alameda()` warns that
#' the API cap may have hidden additional facilities. The returned rows are
#' deduplicated by `facility_number`.
#'
#' @param type One of `"large_fccs"`, `"infant_centers"`,
#'   `"school_age_centers"`, `"preschools"`, or
#'   `"single_licensed_centers"`. Partial matching via [match.arg()] is
#'   supported.
#' @param cache Logical value (default `TRUE`) controlling whether the on-disk
#'   response cache is used.
#'
#' @return A 13-column slim tibble, matching [ccld_verify()]. Search responses
#'   do not include closure dates, so `date_closed` is `NA`.
#' @family Alameda snapshots
#' @seealso [ccld_verify()] for the shared slim return schema.
#' @export
#' @examples
#' \dontrun{
#' ccld_alameda("preschools")
#' ccld_alameda("large_fccs")
#' }
ccld_alameda <- function(type, cache = TRUE) {
  factype <- alameda_factype_for(type)
  show_progress <- interactive()
  if (show_progress) {
    cli::cli_progress_bar("Walking Alameda cities", total = length(ALAMEDA_CITIES))
  }

  per_city <- lapply(ALAMEDA_CITIES, function(city) {
    result <- alameda_search_city(factype, city, cache = cache)
    if (show_progress) {
      cli::cli_progress_update()
    }
    result
  })
  if (show_progress) {
    cli::cli_progress_done()
  }

  capped <- ALAMEDA_CITIES[vapply(per_city, function(x) {
    count <- attr(x, "ccldr_count", exact = TRUE) %||% nrow(x)
    isTRUE(count >= 250)
  }, logical(1))]
  if (length(capped) > 0) {
    cli::cli_warn(c(
      "One or more city queries hit the 250-result cap.",
      "x" = "Cities: {.val {capped}}",
      "i" = "Some facilities may be missing; supplement with the CKAN snapshot."
    ))
  }

  out <- do.call(rbind, per_city)
  if (nrow(out) == 0) {
    return(out)
  }
  out[!duplicated(out$facility_number), , drop = FALSE]
}
