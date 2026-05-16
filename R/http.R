BASE_URL <- "https://www.ccld.dss.ca.gov/transparencyapi/api/"

.ccldr_state <- new.env(parent = emptyenv())
.ccldr_state$last_request_at <- NA_real_

user_agent <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("ccldr")),
    error = function(e) utils::packageDescription("ccldr", fields = "Version")
  )
  paste0("ccldr/", version, " (+https://github.com/chekos/ccldr)")
}

ccldr_request <- function(path) {
  httr2::request(paste0(BASE_URL, path)) |>
    httr2::req_user_agent(user_agent()) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_timeout(20) |>
    httr2::req_retry(max_tries = 2, backoff = function(tries) 2 ^ tries) |>
    httr2::req_error(is_error = function(resp) FALSE)
}

throttle <- function() {
  delay <- getOption("ccldr.delay", 0.5)
  if (is.na(delay) || delay <= 0 || is.na(.ccldr_state$last_request_at)) {
    return(invisible())
  }

  elapsed <- as.numeric(Sys.time()) - .ccldr_state$last_request_at
  if (elapsed < delay) {
    Sys.sleep(delay - elapsed)
  }
  invisible()
}

ccldr_fetch_json <- function(path, cache = TRUE) {
  if (isTRUE(cache)) {
    hit <- cache_get(path)
    if (!is.null(hit)) {
      return(hit)
    }
  }

  throttle()
  req <- ccldr_request(path)
  if (isTRUE(getOption("ccldr.verbose", FALSE))) {
    cli::cli_inform("GET {path}")
  }

  resp <- httr2::req_perform(req)
  .ccldr_state$last_request_at <- as.numeric(Sys.time())
  status <- httr2::resp_status(resp)
  if (status >= 400) {
    body <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
    cli::cli_abort(
      c(
        "CCLD API request failed.",
        "x" = "Path: {.val {path}}",
        "x" = "Status: {status}",
        "i" = body
      ),
      class = "ccldr_http_error"
    )
  }

  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  if (isTRUE(cache)) {
    cache_set(path, body)
  }
  body
}
