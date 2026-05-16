#' Verify CCLD facility license numbers in bulk
#'
#' Looks up each license number against the live CCLD Transparency API and
#' returns a tibble with one row per input. Unknown licenses are not dropped:
#' they appear as rows with `found = FALSE` and `NA`s in the data columns.
#'
#' @param facnums Character or numeric vector of facility license numbers.
#'   Accepts 8- or 9-digit forms; padded internally via [ccld_pad()].
#' @param cache If `TRUE` (default), use the on-disk response cache.
#'
#' @return A tibble with 12 columns: `input`, `facility_number`, `found`,
#'   `facility_name`, `facility_type`, `status`, `licensee_name`,
#'   `street_address`, `city`, `zip`, `license_effective_date`,
#'   `last_visit_date`.
#' @export
#' @examples
#' \dontrun{
#' ccld_verify("13423996")
#' ccld_verify(c(13423996, 99999999))
#' }
ccld_verify <- function(facnums, cache = TRUE) {
  if (rlang::is_empty(facnums)) {
    return(empty_slim_tibble())
  }

  input <- as.character(facnums)
  padded <- ccld_pad(facnums)
  unique_padded <- unique(stats::na.omit(padded))

  show_progress <- length(unique_padded) > 10 && interactive()
  if (show_progress) {
    cli::cli_progress_bar("Verifying licenses", total = length(unique_padded))
  }

  fetched <- vector("list", length(unique_padded))
  names(fetched) <- unique_padded
  for (i in seq_along(unique_padded)) {
    fetched[[i]] <- ccldr_fetch_json(
      paste0("FacilityDetail/", unique_padded[[i]]),
      cache = cache
    )
    if (show_progress) {
      cli::cli_progress_update()
    }
  }
  if (show_progress) {
    cli::cli_progress_done()
  }

  rows <- lapply(seq_along(input), function(i) {
    if (is.na(padded[[i]])) {
      return(parse_slim_row(list(), input = input[[i]]))
    }
    parse_slim_row(fetched[[padded[[i]]]], input = input[[i]])
  })
  do.call(rbind, rows)
}
