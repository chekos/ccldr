#' Pad facility license numbers to the API's canonical 9-digit form
#'
#' The CCLD Transparency API requires every facility number to be left-padded
#' with leading zeros to exactly 9 digits. CDSS-side data usually stores the
#' 8-digit form. `ccld_pad()` makes the conversion explicit and vectorised.
#'
#' @param facnums Character or numeric vector of license numbers.
#' @return Character vector of 9-digit zero-padded license numbers. `NA` inputs
#'   return `NA_character_`.
#' @export
#' @examples
#' ccld_pad("13423996")
#' ccld_pad(c(13423996, 15700561))
ccld_pad <- function(facnums) {
  if (length(facnums) == 0) {
    return(character(0))
  }

  chr <- as.character(facnums)
  is_na <- is.na(chr)

  bad <- !is_na & !grepl("^[0-9]+$", chr)
  if (any(bad)) {
    cli::cli_abort(
      c(
        "Inputs must contain only digits.",
        "x" = "Got: {.val {chr[bad]}}"
      ),
      class = "ccldr_invalid_input"
    )
  }

  too_long <- !is_na & nchar(chr) > 9
  if (any(too_long)) {
    cli::cli_abort(
      c(
        "License numbers must be 9 digits or fewer.",
        "x" = "Got: {.val {chr[too_long]}}"
      ),
      class = "ccldr_invalid_input"
    )
  }

  out <- ifelse(
    is_na,
    NA_character_,
    sprintf("%09s", chr)
  )
  gsub(" ", "0", out, fixed = TRUE)
}
