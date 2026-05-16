mock_json_response <- function(body, status = 200) {
  httr2::response(
    status_code = status,
    body = charToRaw(body),
    headers = list("Content-Type" = "application/json")
  )
}

fixture_text <- function(name) {
  paste(readLines(file.path("fixtures", name), warn = FALSE), collapse = "\n")
}

load_fixture <- function(name) {
  jsonlite::fromJSON(file.path("fixtures", name), simplifyVector = FALSE)
}

mock_fixture <- function(name) {
  body <- fixture_text(name)
  function(req) mock_json_response(body)
}

setup_clean_cache <- function() {
  tmp <- withr::local_tempdir(.local_envir = parent.frame())
  withr::local_envvar(R_USER_CACHE_DIR = tmp, .local_envir = parent.frame())
  withr::local_options(ccldr.delay = 0, .local_envir = parent.frame())
}
