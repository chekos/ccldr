# Internal cache helpers.

ccldr_cache_dir <- function() {
  dir <- tools::R_user_dir("ccldr", "cache")
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

cache_path <- function(key) {
  safe <- gsub("[^A-Za-z0-9_.-]", "_", key)
  file.path(ccldr_cache_dir(), paste0(safe, ".qs"))
}

cache_get <- function(key) {
  path <- cache_path(key)
  if (!file.exists(path)) {
    return(NULL)
  }

  ttl <- getOption("ccldr.cache_ttl_seconds", 86400)
  age <- as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "secs"))
  if (is.na(ttl) || ttl < 0 || age > ttl) {
    return(NULL)
  }

  tryCatch(qs2::qs_read(path, nthreads = 1), error = function(e) NULL)
}

cache_set <- function(key, value) {
  qs2::qs_save(value, cache_path(key), compress_level = 1, nthreads = 1)
  invisible(value)
}

#' Clear cached CCLD API responses
#'
#' Removes every cached response from the on-disk `ccldr` cache. This is useful
#' before a reproducibility run or when you want to force subsequent calls to
#' re-query the live CCLD Transparency API.
#'
#' @return Invisibly, the number of cache files removed.
#' @family cache management
#' @export
#' @examples
#' ccld_cache_clear()
ccld_cache_clear <- function() {
  dir <- ccldr_cache_dir()
  files <- list.files(dir, pattern = "\\.qs$", full.names = TRUE)
  unlink(files)
  invisible(length(files))
}

#' Inspect cached CCLD API responses
#'
#' Returns one row per cached response. Cache entries older than
#' `getOption("ccldr.cache_ttl_seconds")` are ignored by API helpers, but they
#' can still appear here until the cache is cleared.
#'
#' @return A tibble with one row per cached response and columns `key`,
#'   `age_seconds`, and `size_bytes`.
#' @family cache management
#' @export
#' @examples
#' ccld_cache_info()
ccld_cache_info <- function() {
  dir <- ccldr_cache_dir()
  files <- list.files(dir, pattern = "\\.qs$", full.names = TRUE)
  if (length(files) == 0) {
    return(tibble::tibble(
      key = character(),
      age_seconds = numeric(),
      size_bytes = numeric()
    ))
  }

  info <- file.info(files)
  tibble::tibble(
    key = sub("\\.qs$", "", basename(files)),
    age_seconds = as.numeric(difftime(Sys.time(), info$mtime, units = "secs")),
    size_bytes = as.numeric(info$size)
  )
}
