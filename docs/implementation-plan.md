# ccldr Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tidyverse-native R package wrapping the CCLD Transparency API so the F5 data team can verify license numbers, pull facility detail, and pull live Alameda snapshots from inside `.R` scripts. See [`docs/design.md`](design.md) for the design.

**Architecture:** Standard `usethis::create_package()` layout. Four exported functions (`ccld_verify`, `ccld_facility`, `ccld_alameda`, `ccld_pad`) backed by two internal modules: an `httr2`-based request layer with retry and rate limit, and a `qs`-backed file cache. Tests use `testthat` for assertions and `httptest2` for HTTP record/replay so the suite never depends on the live CCLD site.

**Tech Stack:** R ≥ 4.1, `tibble`, `httr2`, `qs`, `cli`, `rlang`. Dev-time: `usethis`, `devtools`, `testthat`, `httptest2`, `roxygen2`. CI via GitHub Actions (`r-lib/actions`).

**Prerequisites:** R ≥ 4.1 installed, `usethis::create_package()` available, working directory at the cloned `chekos/ccldr` repo (currently holding only `README.md`, `docs/design.md`, `docs/implementation-plan.md`, `.gitignore`).

---

## Phase 0: Package skeleton

### Task 0.1: Create the R package skeleton

**Files:**
- Create: `DESCRIPTION`, `NAMESPACE`, `R/ccldr-package.R`, `man/ccldr-package.Rd`, `.Rbuildignore`

- [ ] **Step 1: Initialize the package in-place**

In an R session at the repo root:

```r
usethis::create_package(".", fields = list(
  Package = "ccldr",
  Title = "R Client for the CCLD Transparency API",
  Version = "0.0.0.9000",
  Authors = 'person("Sergio", "Sanchez", email = "sergio.sanchez@first5alameda.org", role = c("aut", "cre"))',
  Description = "Verify license numbers, pull facility detail, and snapshot Alameda child-care facilities via the California CCLD Transparency API.",
  License = "MIT + file LICENSE",
  Encoding = "UTF-8"
), rstudio = FALSE, open = FALSE)
```

This writes `DESCRIPTION`, `NAMESPACE`, `R/ccldr-package.R`, `man/ccldr-package.Rd`, `.Rbuildignore`, `ccldr.Rproj`. Don't worry about `ccldr.Rproj` — it's harmless and `.Rbuildignore`'d.

- [ ] **Step 2: Add the LICENSE file**

```r
usethis::use_mit_license("Sergio Sanchez")
```

Writes `LICENSE` and `LICENSE.md` and registers them in `.Rbuildignore`.

- [ ] **Step 3: Declare runtime dependencies**

```r
usethis::use_package("tibble", "Imports")
usethis::use_package("httr2", "Imports")
usethis::use_package("qs", "Imports")
usethis::use_package("cli", "Imports")
usethis::use_package("rlang", "Imports")
```

- [ ] **Step 4: Declare dev dependencies**

```r
usethis::use_package("testthat", "Suggests")
usethis::use_package("httptest2", "Suggests")
usethis::use_package("withr", "Suggests")
```

- [ ] **Step 5: Set up testthat**

```r
usethis::use_testthat(3)
```

Creates `tests/testthat/`, `tests/testthat.R`, and adds `Config/testthat/edition: 3` to `DESCRIPTION`.

- [ ] **Step 6: Add roxygen2 config to DESCRIPTION**

Open `DESCRIPTION` and add this line near the bottom:

```
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.2
```

- [ ] **Step 7: Replace the auto-generated package doc**

Overwrite `R/ccldr-package.R`:

```r
#' ccldr: R client for the CCLD Transparency API
#'
#' Verify facility license numbers, pull rich per-facility detail, and snapshot
#' Alameda child-care facilities from the California Community Care Licensing
#' Division's undocumented Transparency API.
#'
#' @section Package options:
#'
#' \describe{
#'   \item{`ccldr.delay`}{Seconds between requests in batch mode. Default 0.5.}
#'   \item{`ccldr.cache_ttl_seconds`}{Cache TTL in seconds. Default 86400 (24h).}
#'   \item{`ccldr.verbose`}{If `TRUE`, log one line per HTTP request. Default `FALSE`.}
#' }
#'
#' @keywords internal
"_PACKAGE"
```

- [ ] **Step 8: Regenerate documentation**

```r
devtools::document()
```

Updates `NAMESPACE` and `man/ccldr-package.Rd`.

- [ ] **Step 9: Commit**

```bash
git add DESCRIPTION NAMESPACE LICENSE LICENSE.md R/ccldr-package.R man/ccldr-package.Rd .Rbuildignore tests/
git commit -m "chore: initialize R package skeleton with testthat"
```

---

## Phase 1: Foundation primitives

### Task 1.1: `ccld_pad()` — padding helper

The simplest exported function. A good warmup for the TDD rhythm.

**Files:**
- Create: `R/ccld_pad.R`
- Create: `tests/testthat/test-pad.R`

- [ ] **Step 1: Write failing tests**

Create `tests/testthat/test-pad.R`:

```r
test_that("ccld_pad pads 8-digit char to 9", {
  expect_equal(ccld_pad("13423996"), "013423996")
})

test_that("ccld_pad accepts numeric input", {
  expect_equal(ccld_pad(13423996), "013423996")
})

test_that("ccld_pad is vectorized", {
  expect_equal(
    ccld_pad(c("13423996", "15700561")),
    c("013423996", "015700561")
  )
})

test_that("ccld_pad leaves already-9-digit input untouched", {
  expect_equal(ccld_pad("013423996"), "013423996")
})

test_that("ccld_pad returns NA for NA input", {
  expect_equal(ccld_pad(NA), NA_character_)
  expect_equal(ccld_pad(c("13423996", NA)), c("013423996", NA_character_))
})

test_that("ccld_pad errors on non-numeric strings", {
  expect_error(ccld_pad("not-a-number"), class = "ccldr_invalid_input")
})

test_that("ccld_pad errors on inputs > 9 digits", {
  expect_error(ccld_pad("0123456789"), class = "ccldr_invalid_input")
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "pad")
```

Expected: all tests FAIL because `ccld_pad` doesn't exist yet.

- [ ] **Step 3: Implement `ccld_pad`**

Create `R/ccld_pad.R`:

```r
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
  if (length(facnums) == 0) return(character(0))
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
  out <- ifelse(is_na, NA_character_, formatC(as.numeric(chr), width = 9, flag = "0", format = "d"))
  out
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::document()
devtools::test(filter = "pad")
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/ccld_pad.R tests/testthat/test-pad.R man/ccld_pad.Rd NAMESPACE
git commit -m "feat(pad): add ccld_pad() license-number padding helper"
```

---

### Task 1.2: HTTP layer — internal request builder

The thin layer over `httr2` that every fetching function uses. Handles base URL, user agent, retry, rate-limit politeness.

**Files:**
- Create: `R/http.R`
- Create: `tests/testthat/test-http.R`
- Create: `tests/testthat/fixtures/facility_detail_known.json`
- Create: `tests/testthat/fixtures/facility_detail_unknown.json`

- [ ] **Step 1: Capture two fixtures from the live API**

These are committed so tests don't hit the network. In a shell:

```bash
mkdir -p tests/testthat/fixtures
curl -s -H "User-Agent: ccldr/0.0.0" \
  "https://www.ccld.dss.ca.gov/transparencyapi/api/FacilityDetail/013423996" \
  > tests/testthat/fixtures/facility_detail_known.json

curl -s -H "User-Agent: ccldr/0.0.0" \
  "https://www.ccld.dss.ca.gov/transparencyapi/api/FacilityDetail/099999999" \
  > tests/testthat/fixtures/facility_detail_unknown.json
```

Verify both are valid JSON:

```bash
jq . tests/testthat/fixtures/facility_detail_known.json > /dev/null
jq . tests/testthat/fixtures/facility_detail_unknown.json > /dev/null
```

Expected: both commands exit 0 silently.

- [ ] **Step 2: Write failing tests**

Create `tests/testthat/test-http.R`:

```r
test_that("ccldr_request builds a request with the right URL and UA", {
  req <- ccldr_request("FacilityDetail/013423996")
  expect_s3_class(req, "httr2_request")
  expect_match(req$url, "transparencyapi/api/FacilityDetail/013423996$")
  ua <- req$headers[["User-Agent"]]
  expect_match(ua, "^ccldr/")
})

test_that("ccldr_fetch_json returns parsed JSON for a known facility", {
  fake <- function(req) {
    body <- readLines("fixtures/facility_detail_known.json", warn = FALSE)
    httr2::response(status_code = 200, body = paste(body, collapse = "\n"),
                    headers = list("Content-Type" = "application/json"))
  }
  withr::local_options(ccldr.delay = 0)
  result <- httr2::with_mocked_responses(
    function(req) {
      body <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
      httr2::response(status_code = 200, body = body,
                      headers = list("Content-Type" = "application/json"))
    },
    ccldr_fetch_json("FacilityDetail/013423996")
  )
  expect_type(result, "list")
  expect_true("FacilityDetail" %in% names(result))
  expect_equal(result$FacilityDetail$FACILITYNUMBER, "013423996")
})

test_that("ccldr_fetch_json applies the configured delay between calls", {
  withr::local_options(ccldr.delay = 0.05)
  mock_resp <- function(req) {
    httr2::response(status_code = 200, body = "{}",
                    headers = list("Content-Type" = "application/json"))
  }
  t0 <- Sys.time()
  httr2::with_mocked_responses(mock_resp, {
    ccldr_fetch_json("FacilityDetail/013423996")
    ccldr_fetch_json("FacilityDetail/013423997")
  })
  expect_gte(as.numeric(Sys.time() - t0), 0.04)
})
```

- [ ] **Step 3: Run tests to verify they fail**

```r
devtools::test(filter = "http")
```

Expected: tests FAIL with "could not find function" errors.

- [ ] **Step 4: Implement the HTTP layer**

Create `R/http.R`:

```r
# Internal. Do not export.

BASE_URL <- "https://www.ccld.dss.ca.gov/transparencyapi/api/"

user_agent <- function() {
  ver <- as.character(utils::packageVersion("ccldr"))
  paste0("ccldr/", ver, " (+https://github.com/chekos/ccldr)")
}

#' Build a httr2 request for a Transparency API path
#' @noRd
ccldr_request <- function(path) {
  httr2::request(paste0(BASE_URL, path)) |>
    httr2::req_user_agent(user_agent()) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_timeout(20) |>
    httr2::req_retry(max_tries = 2, backoff = function(i) 2 ^ i)
}

# Track the time of the most recent successful request. Used to enforce the
# configured politeness delay across calls within a session.
.ccldr_state <- new.env(parent = emptyenv())
.ccldr_state$last_request_at <- NA_real_

throttle <- function() {
  delay <- getOption("ccldr.delay", 0.5)
  if (delay <= 0 || is.na(.ccldr_state$last_request_at)) return(invisible())
  elapsed <- as.numeric(Sys.time()) - .ccldr_state$last_request_at
  if (elapsed < delay) Sys.sleep(delay - elapsed)
}

#' Fetch a JSON endpoint, returning the parsed body
#' @noRd
ccldr_fetch_json <- function(path) {
  throttle()
  req <- ccldr_request(path)
  if (isTRUE(getOption("ccldr.verbose", FALSE))) {
    cli::cli_inform("GET {path}")
  }
  resp <- httr2::req_perform(req)
  .ccldr_state$last_request_at <- as.numeric(Sys.time())
  if (httr2::resp_status(resp) >= 400) {
    cli::cli_abort(
      c(
        "CCLD API request failed.",
        "x" = "Path: {.val {path}}",
        "x" = "Status: {httr2::resp_status(resp)}"
      ),
      class = "ccldr_http_error"
    )
  }
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}
```

- [ ] **Step 5: Run tests to verify they pass**

```r
devtools::test(filter = "http")
```

Expected: all 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add R/http.R tests/testthat/test-http.R tests/testthat/fixtures/
git commit -m "feat(http): add internal httr2 request + JSON fetch with rate limiting"
```

---

### Task 1.3: Cache layer

File-backed cache keyed on endpoint path + 24h TTL.

**Files:**
- Create: `R/cache.R`
- Create: `tests/testthat/test-cache.R`

- [ ] **Step 1: Write failing tests**

Create `tests/testthat/test-cache.R`:

```r
test_that("cache_dir creates the user dir if missing", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  path <- ccldr_cache_dir()
  expect_true(dir.exists(path))
  expect_match(path, "ccldr")
})

test_that("cache_get returns NULL when key not present", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  expect_null(cache_get("missing_key"))
})

test_that("cache_set then cache_get round-trips a list", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("hello", list(a = 1, b = "x"))
  expect_equal(cache_get("hello"), list(a = 1, b = "x"))
})

test_that("cache_get returns NULL when entry is stale", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  withr::local_options(ccldr.cache_ttl_seconds = 0)
  cache_set("k", list(a = 1))
  Sys.sleep(0.01)
  expect_null(cache_get("k"))
})

test_that("ccld_cache_clear removes all entries", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("a", 1); cache_set("b", 2)
  ccld_cache_clear()
  expect_null(cache_get("a"))
  expect_null(cache_get("b"))
})

test_that("ccld_cache_info returns a tibble with rows for each entry", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("a", 1)
  cache_set("b", 2)
  info <- ccld_cache_info()
  expect_s3_class(info, "tbl_df")
  expect_equal(nrow(info), 2)
  expect_true(all(c("key", "age_seconds", "size_bytes") %in% names(info)))
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "cache")
```

Expected: failures with "could not find function".

- [ ] **Step 3: Implement the cache layer**

Create `R/cache.R`:

```r
#' Cache directory (creates it if missing)
#' @noRd
ccldr_cache_dir <- function() {
  d <- tools::R_user_dir("ccldr", "cache")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

cache_path <- function(key) {
  safe <- gsub("[^A-Za-z0-9_.-]", "_", key)
  file.path(ccldr_cache_dir(), paste0(safe, ".qs"))
}

#' Read a cached value, returning NULL if missing or stale
#' @noRd
cache_get <- function(key) {
  p <- cache_path(key)
  if (!file.exists(p)) return(NULL)
  ttl <- getOption("ccldr.cache_ttl_seconds", 86400)
  age <- as.numeric(Sys.time()) - file.info(p)$mtime
  if (age > ttl) return(NULL)
  tryCatch(qs::qread(p, nthreads = 1), error = function(e) NULL)
}

#' Write a value to the cache
#' @noRd
cache_set <- function(key, value) {
  qs::qsave(value, cache_path(key), preset = "fast", nthreads = 1)
  invisible(value)
}

#' Clear the ccldr cache
#'
#' Removes every entry from the on-disk cache directory.
#' @export
ccld_cache_clear <- function() {
  d <- ccldr_cache_dir()
  files <- list.files(d, pattern = "\\.qs$", full.names = TRUE)
  unlink(files)
  invisible(length(files))
}

#' Inspect the ccldr cache
#'
#' @return A tibble with one row per cached entry (key, age_seconds, size_bytes).
#' @export
ccld_cache_info <- function() {
  d <- ccldr_cache_dir()
  files <- list.files(d, pattern = "\\.qs$", full.names = TRUE)
  if (length(files) == 0) {
    return(tibble::tibble(key = character(), age_seconds = numeric(), size_bytes = numeric()))
  }
  fi <- file.info(files)
  tibble::tibble(
    key = sub("\\.qs$", "", basename(files)),
    age_seconds = as.numeric(Sys.time()) - as.numeric(fi$mtime),
    size_bytes = fi$size
  )
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::document()
devtools::test(filter = "cache")
```

Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/cache.R tests/testthat/test-cache.R man/ccld_cache_clear.Rd man/ccld_cache_info.Rd NAMESPACE
git commit -m "feat(cache): add qs-backed file cache with TTL"
```

---

### Task 1.4: Wire the cache into the HTTP layer

`ccldr_fetch_json` should check the cache before making a request and write to it on success.

**Files:**
- Modify: `R/http.R`
- Modify: `tests/testthat/test-http.R`

- [ ] **Step 1: Write failing tests**

Append to `tests/testthat/test-http.R`:

```r
test_that("ccldr_fetch_json reads from cache when fresh", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("FacilityDetail/013423996", list(fixture = "yes"))
  result <- ccldr_fetch_json("FacilityDetail/013423996")
  expect_equal(result, list(fixture = "yes"))
})

test_that("ccldr_fetch_json bypasses cache when cache = FALSE", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("FacilityDetail/013423996", list(fixture = "stale"))
  body <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  mock_resp <- function(req) {
    httr2::response(status_code = 200, body = body,
                    headers = list("Content-Type" = "application/json"))
  }
  withr::local_options(ccldr.delay = 0)
  result <- httr2::with_mocked_responses(mock_resp, {
    ccldr_fetch_json("FacilityDetail/013423996", cache = FALSE)
  })
  expect_equal(result$FacilityDetail$FACILITYNUMBER, "013423996")
})

test_that("ccldr_fetch_json writes to cache after a fresh fetch", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  body <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  mock_resp <- function(req) {
    httr2::response(status_code = 200, body = body,
                    headers = list("Content-Type" = "application/json"))
  }
  withr::local_options(ccldr.delay = 0)
  httr2::with_mocked_responses(mock_resp, ccldr_fetch_json("FacilityDetail/013423996"))
  cached <- cache_get("FacilityDetail/013423996")
  expect_equal(cached$FacilityDetail$FACILITYNUMBER, "013423996")
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "http")
```

Expected: the three new tests fail.

- [ ] **Step 3: Wire caching into `ccldr_fetch_json`**

Replace the `ccldr_fetch_json` function in `R/http.R` with:

```r
#' Fetch a JSON endpoint, with optional caching, returning the parsed body
#' @param path Endpoint path beneath the Transparency API base URL.
#' @param cache If TRUE (default), check and populate the file cache.
#' @noRd
ccldr_fetch_json <- function(path, cache = TRUE) {
  if (cache) {
    hit <- cache_get(path)
    if (!is.null(hit)) return(hit)
  }
  throttle()
  req <- ccldr_request(path)
  if (isTRUE(getOption("ccldr.verbose", FALSE))) {
    cli::cli_inform("GET {path}")
  }
  resp <- httr2::req_perform(req)
  .ccldr_state$last_request_at <- as.numeric(Sys.time())
  if (httr2::resp_status(resp) >= 400) {
    cli::cli_abort(
      c(
        "CCLD API request failed.",
        "x" = "Path: {.val {path}}",
        "x" = "Status: {httr2::resp_status(resp)}"
      ),
      class = "ccldr_http_error"
    )
  }
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  if (cache) cache_set(path, body)
  body
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::test(filter = "http")
```

Expected: all http tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/http.R tests/testthat/test-http.R
git commit -m "feat(http): cache successful JSON fetches"
```

---

## Phase 2: `ccld_verify()`

### Task 2.1: Slim-row parser

Pure transformation from one `FacilityDetail` JSON object to the slim 12-column row. No HTTP. Easy to test exhaustively.

**Files:**
- Create: `R/parse.R`
- Create: `tests/testthat/test-parse.R`
- Create: `tests/testthat/fixtures/facility_detail_closed.json`

- [ ] **Step 1: Capture a third fixture (closed facility)**

```bash
curl -s -H "User-Agent: ccldr/0.0.0" \
  "https://www.ccld.dss.ca.gov/transparencyapi/api/FacilityDetail/013423958" \
  > tests/testthat/fixtures/facility_detail_closed.json
```

- [ ] **Step 2: Write failing tests**

Create `tests/testthat/test-parse.R`:

```r
load_fixture <- function(name) {
  jsonlite::fromJSON(file.path("fixtures", name), simplifyVector = FALSE)
}

test_that("parse_slim_row handles a licensed FCC", {
  body <- load_fixture("facility_detail_known.json")
  row <- parse_slim_row(body, input = "13423996")
  expect_equal(row$input, "13423996")
  expect_equal(row$facility_number, "013423996")
  expect_true(row$found)
  expect_equal(row$facility_name, "JOHNSON III, JOHNNY")
  expect_equal(row$facility_type, "FAMILY DAY CARE HOME")
  expect_equal(row$status, "Licensed")
  expect_equal(row$city, "OAKLAND")
  expect_s3_class(row$license_effective_date, "Date")
})

test_that("parse_slim_row handles a closed facility", {
  body <- load_fixture("facility_detail_closed.json")
  row <- parse_slim_row(body, input = "13423958")
  expect_true(row$found)
  expect_equal(row$status, "Closed, Licensee Initiated")
})

test_that("parse_slim_row returns found=FALSE for unknown licenses", {
  body <- load_fixture("facility_detail_unknown.json")
  row <- parse_slim_row(body, input = "99999999")
  expect_equal(row$input, "99999999")
  expect_equal(row$facility_number, "099999999")
  expect_false(row$found)
  expect_true(is.na(row$facility_name))
  expect_true(is.na(row$status))
})
```

You also need to add `jsonlite` to Suggests:

```r
usethis::use_package("jsonlite", "Suggests")
```

- [ ] **Step 3: Run tests to verify they fail**

```r
devtools::test(filter = "parse")
```

Expected: tests FAIL ("could not find function parse_slim_row").

- [ ] **Step 4: Implement the parser**

Create `R/parse.R`:

```r
# Internal — pure transformation, no I/O.

parse_date <- function(x) {
  if (is.null(x) || identical(x, "") || identical(x, "1/1/0001")) return(as.Date(NA))
  as.Date(x, tryFormats = c("%m/%d/%Y"), optional = TRUE)
}

empty_to_na <- function(x) {
  if (is.null(x) || identical(x, "")) NA_character_ else x
}

#' Convert one FacilityDetail JSON body to a one-row tibble slice
#' @noRd
parse_slim_row <- function(body, input) {
  fd <- body$FacilityDetail %||% list()
  status <- empty_to_na(fd$STATUS)
  found <- !is.na(status)
  tibble::tibble(
    input = as.character(input),
    facility_number = ccld_pad(input),
    found = found,
    facility_name = if (found) empty_to_na(fd$FACILITYNAME) else NA_character_,
    facility_type = if (found) empty_to_na(fd$FACILITYTYPE) else NA_character_,
    status = status,
    licensee_name = if (found) empty_to_na(fd$LICENSEENAME) else NA_character_,
    street_address = if (found) empty_to_na(fd$STREETADDRESS) else NA_character_,
    city = if (found) empty_to_na(fd$CITY) else NA_character_,
    zip = if (found) empty_to_na(fd$ZIPCODE) else NA_character_,
    license_effective_date = if (found) parse_date(fd$LICENSEEFFECTIVEDATE) else as.Date(NA),
    last_visit_date = if (found) parse_date(fd$LASTVISITDATE) else as.Date(NA)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
```

- [ ] **Step 5: Run tests to verify they pass**

```r
devtools::test(filter = "parse")
```

Expected: 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add R/parse.R tests/testthat/test-parse.R tests/testthat/fixtures/facility_detail_closed.json DESCRIPTION
git commit -m "feat(parse): parse FacilityDetail JSON to slim 12-column tibble row"
```

---

### Task 2.2: `ccld_verify()` — single-license path

Now wire the parser to the HTTP layer for the one-license case. Batch handling comes next.

**Files:**
- Create: `R/ccld_verify.R`
- Create: `tests/testthat/test-verify.R`

- [ ] **Step 1: Write failing tests**

Create `tests/testthat/test-verify.R`:

```r
mock_fixture <- function(name) {
  body <- paste(readLines(file.path("fixtures", name), warn = FALSE), collapse = "\n")
  function(req) {
    httr2::response(status_code = 200, body = body,
                    headers = list("Content-Type" = "application/json"))
  }
}

setup_clean_cache <- function() {
  tmp <- withr::local_tempdir(.local_envir = parent.frame())
  withr::local_envvar(R_USER_CACHE_DIR = tmp, .local_envir = parent.frame())
  withr::local_options(ccldr.delay = 0, .local_envir = parent.frame())
}

test_that("ccld_verify returns a 1-row tibble for a single license", {
  setup_clean_cache()
  result <- httr2::with_mocked_responses(
    mock_fixture("facility_detail_known.json"),
    ccld_verify("13423996")
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$facility_number, "013423996")
  expect_true(result$found)
  expect_equal(ncol(result), 12)
})

test_that("ccld_verify returns found=FALSE for unknown license", {
  setup_clean_cache()
  result <- httr2::with_mocked_responses(
    mock_fixture("facility_detail_unknown.json"),
    ccld_verify("99999999")
  )
  expect_equal(nrow(result), 1)
  expect_false(result$found)
  expect_true(is.na(result$facility_name))
})

test_that("ccld_verify accepts numeric input", {
  setup_clean_cache()
  result <- httr2::with_mocked_responses(
    mock_fixture("facility_detail_known.json"),
    ccld_verify(13423996)
  )
  expect_equal(result$facility_number, "013423996")
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "verify")
```

Expected: FAIL ("could not find function ccld_verify").

- [ ] **Step 3: Implement `ccld_verify` for the scalar case**

Create `R/ccld_verify.R`:

```r
#' Verify CCLD facility license numbers in bulk
#'
#' Looks up each license number against the live CCLD Transparency API and
#' returns a tibble with one row per input. Unknown licenses are not dropped:
#' they appear as a row with `found = FALSE` and `NA`s in the data columns.
#'
#' @param facnums Character or numeric vector of facility license numbers.
#'   Accepts 8- or 9-digit forms; padded internally via [ccld_pad()].
#' @param cache If `TRUE` (default), short-circuit lookups via the on-disk
#'   cache. See [ccld_cache_clear()] / [ccld_cache_info()].
#'
#' @return A tibble with 12 columns: `input`, `facility_number`, `found`,
#'   `facility_name`, `facility_type`, `status`, `licensee_name`,
#'   `street_address`, `city`, `zip`, `license_effective_date`,
#'   `last_visit_date`. See `vignette("getting-started")` for examples.
#'
#' @export
#' @examples
#' \dontrun{
#' ccld_verify("13423996")
#' ccld_verify(c(13423996, 99999999))
#' }
ccld_verify <- function(facnums, cache = TRUE) {
  if (length(facnums) == 0) {
    return(empty_slim_tibble())
  }
  padded <- ccld_pad(facnums)
  rows <- lapply(seq_along(facnums), function(i) {
    if (is.na(padded[[i]])) return(parse_slim_row(list(), input = NA_character_))
    body <- ccldr_fetch_json(paste0("FacilityDetail/", padded[[i]]), cache = cache)
    parse_slim_row(body, input = as.character(facnums[[i]]))
  })
  do.call(rbind, rows)
}

empty_slim_tibble <- function() {
  tibble::tibble(
    input = character(), facility_number = character(), found = logical(),
    facility_name = character(), facility_type = character(), status = character(),
    licensee_name = character(), street_address = character(),
    city = character(), zip = character(),
    license_effective_date = as.Date(character()),
    last_visit_date = as.Date(character())
  )
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::document()
devtools::test(filter = "verify")
```

Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/ccld_verify.R tests/testthat/test-verify.R man/ccld_verify.Rd NAMESPACE
git commit -m "feat(verify): add ccld_verify() for single-license lookup"
```

---

### Task 2.3: `ccld_verify()` — batch + progress + dedupe

Handle vector input efficiently: dedupe before fetching, show a `cli::cli_progress_bar` for batches > 10, expand back to caller's order.

**Files:**
- Modify: `R/ccld_verify.R`
- Modify: `tests/testthat/test-verify.R`

- [ ] **Step 1: Write failing tests**

Append to `tests/testthat/test-verify.R`:

```r
test_that("ccld_verify handles a 2-element vector", {
  setup_clean_cache()
  body_known <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  body_unknown <- paste(readLines("fixtures/facility_detail_unknown.json", warn = FALSE), collapse = "\n")
  dispatch <- function(req) {
    if (grepl("099999999", req$url)) {
      httr2::response(200, body = body_unknown, headers = list("Content-Type" = "application/json"))
    } else {
      httr2::response(200, body = body_known, headers = list("Content-Type" = "application/json"))
    }
  }
  result <- httr2::with_mocked_responses(dispatch, ccld_verify(c("13423996", "99999999")))
  expect_equal(nrow(result), 2)
  expect_equal(result$found, c(TRUE, FALSE))
})

test_that("ccld_verify dedupes duplicate inputs before fetching", {
  setup_clean_cache()
  body_known <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  call_count <- 0
  counting <- function(req) {
    call_count <<- call_count + 1
    httr2::response(200, body = body_known, headers = list("Content-Type" = "application/json"))
  }
  result <- httr2::with_mocked_responses(counting, ccld_verify(c("13423996", "13423996", "13423996")))
  expect_equal(nrow(result), 3)
  expect_equal(call_count, 1)
})

test_that("ccld_verify preserves input order after dedupe", {
  setup_clean_cache()
  body_known <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  body_unknown <- paste(readLines("fixtures/facility_detail_unknown.json", warn = FALSE), collapse = "\n")
  dispatch <- function(req) {
    if (grepl("099999999", req$url)) {
      httr2::response(200, body = body_unknown, headers = list("Content-Type" = "application/json"))
    } else {
      httr2::response(200, body = body_known, headers = list("Content-Type" = "application/json"))
    }
  }
  result <- httr2::with_mocked_responses(dispatch, ccld_verify(c("99999999", "13423996", "99999999")))
  expect_equal(result$input, c("99999999", "13423996", "99999999"))
  expect_equal(result$found, c(FALSE, TRUE, FALSE))
})

test_that("ccld_verify handles NA inputs without making requests", {
  setup_clean_cache()
  call_count <- 0
  body_known <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  counting <- function(req) {
    call_count <<- call_count + 1
    httr2::response(200, body = body_known, headers = list("Content-Type" = "application/json"))
  }
  result <- httr2::with_mocked_responses(counting, ccld_verify(c("13423996", NA, "13423996")))
  expect_equal(nrow(result), 3)
  expect_true(is.na(result$facility_number[2]))
  expect_false(result$found[2])
  expect_equal(call_count, 1)
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "verify")
```

Expected: dedupe + order tests fail (the existing scalar tests still pass).

- [ ] **Step 3: Rewrite `ccld_verify` with dedupe + progress bar**

Replace the body of `ccld_verify` in `R/ccld_verify.R` with:

```r
ccld_verify <- function(facnums, cache = TRUE) {
  if (length(facnums) == 0) return(empty_slim_tibble())

  input <- as.character(facnums)
  padded <- ccld_pad(facnums)

  # Dedupe non-NA, fetch once per unique padded id, then expand.
  unique_padded <- unique(stats::na.omit(padded))
  show_progress <- length(unique_padded) > 10 && interactive()
  if (show_progress) {
    cli::cli_progress_bar("Verifying licenses", total = length(unique_padded))
  }
  fetched <- vector("list", length(unique_padded))
  names(fetched) <- unique_padded
  for (i in seq_along(unique_padded)) {
    fetched[[i]] <- ccldr_fetch_json(paste0("FacilityDetail/", unique_padded[[i]]), cache = cache)
    if (show_progress) cli::cli_progress_update()
  }
  if (show_progress) cli::cli_progress_done()

  # Expand back to caller's order.
  rows <- lapply(seq_along(input), function(i) {
    if (is.na(padded[[i]])) {
      return(parse_slim_row(list(), input = input[[i]]))
    }
    parse_slim_row(fetched[[padded[[i]]]], input = input[[i]])
  })
  do.call(rbind, rows)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::test(filter = "verify")
```

Expected: all 7 verify tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/ccld_verify.R tests/testthat/test-verify.R
git commit -m "feat(verify): dedupe + progress bar + NA-safe batch verification"
```

---

## Phase 3: `ccld_facility()`

### Task 3.1: Rich-detail parser

A second parser that returns the full 54-field record + nested `reports` / `complaints` list-columns.

**Files:**
- Modify: `R/parse.R`
- Create: `tests/testthat/test-facility.R`
- Create: `tests/testthat/fixtures/facility_reports_known.json`

- [ ] **Step 1: Capture the reports fixture**

```bash
curl -s -H "User-Agent: ccldr/0.0.0" \
  "https://www.ccld.dss.ca.gov/transparencyapi/api/FacilityReports/013423996" \
  > tests/testthat/fixtures/facility_reports_known.json
```

- [ ] **Step 2: Write failing tests**

Create `tests/testthat/test-facility.R`:

```r
test_that("ccld_facility returns a 1-row tibble with all fields", {
  setup_clean_cache()
  detail_body <- paste(readLines("fixtures/facility_detail_known.json", warn = FALSE), collapse = "\n")
  reports_body <- paste(readLines("fixtures/facility_reports_known.json", warn = FALSE), collapse = "\n")
  dispatch <- function(req) {
    body <- if (grepl("FacilityReports", req$url)) reports_body else detail_body
    httr2::response(200, body = body, headers = list("Content-Type" = "application/json"))
  }
  result <- httr2::with_mocked_responses(dispatch, ccld_facility("13423996"))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$facility_number, "013423996")
  expect_equal(result$facility_name, "JOHNSON III, JOHNNY")
  # Reports is a list-column with one inner tibble
  expect_type(result$reports, "list")
  expect_s3_class(result$reports[[1]], "tbl_df")
  expect_equal(nrow(result$reports[[1]]), 1)
  expect_true("report_date" %in% names(result$reports[[1]]))
  # Complaints is a list-column (empty array in this fixture)
  expect_type(result$complaints, "list")
  expect_s3_class(result$complaints[[1]], "tbl_df")
})

test_that("ccld_facility errors with class ccldr_not_found for unknown license", {
  setup_clean_cache()
  unknown_body <- paste(readLines("fixtures/facility_detail_unknown.json", warn = FALSE), collapse = "\n")
  dispatch <- function(req) {
    httr2::response(200, body = unknown_body, headers = list("Content-Type" = "application/json"))
  }
  expect_error(
    httr2::with_mocked_responses(dispatch, ccld_facility("99999999")),
    class = "ccldr_not_found"
  )
})
```

- [ ] **Step 3: Run tests to verify they fail**

```r
devtools::test(filter = "facility")
```

Expected: FAIL ("could not find function ccld_facility").

- [ ] **Step 4: Add `parse_full_row` + `parse_reports` helpers**

Append to `R/parse.R`:

```r
parse_int <- function(x) {
  if (is.null(x) || identical(x, "")) return(NA_integer_)
  suppressWarnings(as.integer(x))
}

parse_reports <- function(reports_body) {
  arr <- reports_body$REPORTARRAY %||% list()
  if (length(arr) == 0) {
    return(tibble::tibble(
      report_date = as.Date(character()),
      report_title = character(),
      report_type = character(),
      control_number = character()
    ))
  }
  tibble::tibble(
    report_date = vapply(arr, function(r) format(parse_date(r$REPORTDATE)), character(1)) |> as.Date(),
    report_title = vapply(arr, function(r) r$REPORTTITLE %||% NA_character_, character(1)),
    report_type = vapply(arr, function(r) r$REPORTTYPE %||% NA_character_, character(1)),
    control_number = vapply(arr, function(r) r$CONTROLNUMBER %||% NA_character_, character(1))
  )
}

parse_complaints <- function(detail_body) {
  arr <- detail_body$FacilityDetail$COMPLAINTARRAY %||% list()
  if (length(arr) == 0) {
    return(tibble::tibble(
      complaint_date = as.Date(character()),
      allegation = character(),
      outcome = character()
    ))
  }
  tibble::tibble(
    complaint_date = vapply(arr, function(c) format(parse_date(c$COMPLAINTDATE %||% c$DATE)), character(1)) |> as.Date(),
    allegation = vapply(arr, function(c) c$ALLEGATION %||% NA_character_, character(1)),
    outcome = vapply(arr, function(c) c$OUTCOME %||% NA_character_, character(1))
  )
}

parse_full_row <- function(detail_body, reports_body, input) {
  fd <- detail_body$FacilityDetail %||% list()
  status <- empty_to_na(fd$STATUS)
  if (is.na(status)) {
    cli::cli_abort(
      c("Facility not found.", "x" = "License: {.val {input}}"),
      class = "ccldr_not_found"
    )
  }
  tibble::tibble(
    input = as.character(input),
    facility_number = ccld_pad(input),
    facility_name = empty_to_na(fd$FACILITYNAME),
    facility_type = empty_to_na(fd$FACILITYTYPE),
    status = status,
    licensee_name = empty_to_na(fd$LICENSEENAME),
    contact = empty_to_na(fd$CONTACT),
    street_address = empty_to_na(fd$STREETADDRESS),
    city = empty_to_na(fd$CITY),
    state = empty_to_na(fd$STATE),
    zip = empty_to_na(fd$ZIPCODE),
    county = empty_to_na(fd$COUNTY),
    telephone = empty_to_na(fd$TELEPHONE),
    capacity = parse_int(fd$CAPACITY),
    license_first_date = parse_date(fd$LICENSEFIRSTDATE),
    license_effective_date = parse_date(fd$LICENSEEFFECTIVEDATE),
    date_closed = parse_date(fd$DATECLOSED),
    last_visit_date = parse_date(fd$LASTVISITDATE),
    visits_total = parse_int(fd$NBRALLVISITS),
    visits_complaints = parse_int(fd$NBRCMPLTVISITS),
    visits_inspections = parse_int(fd$NBRINSPVISITS),
    visits_other = parse_int(fd$NBROTHERVISITS),
    cmplt_type_a = parse_int(fd$NBRCMPLTTYPA),
    cmplt_type_b = parse_int(fd$NBRCMPLTTYPB),
    cmplt_substantiated = parse_int(fd$NBRCMPLTSUB),
    cmplt_unsubstantiated = parse_int(fd$NBRCMPLTUNS),
    cmplt_inconclusive = parse_int(fd$NBRCMPLTINC),
    cmplt_unfounded = parse_int(fd$NBRCMPLTUNF),
    insp_type_a = parse_int(fd$NBRINSPTYPA),
    insp_type_b = parse_int(fd$NBRINSPTYPB),
    district_office = empty_to_na(fd$DISTRICTOFFICE),
    district_office_phone = empty_to_na(fd$DOTELEPHONE),
    comments = empty_to_na(fd$COMMENTS),
    comments_2 = empty_to_na(fd$COMMENTS2),
    reports = list(parse_reports(reports_body)),
    complaints = list(parse_complaints(detail_body))
  )
}
```

- [ ] **Step 5: Create `R/ccld_facility.R`**

```r
#' Pull the full CCLD facility detail for one license
#'
#' Returns every field the Transparency API exposes for a single license,
#' plus nested list-columns for the facility's evaluation reports and
#' itemized complaints. Use `tidyr::unnest()` to flatten either column.
#'
#' For batch verification with a slim 12-column return, use [ccld_verify()].
#'
#' @param facnum A single facility license number (character or numeric).
#'   8- or 9-digit form; padded internally.
#' @param cache If `TRUE` (default), short-circuit via the on-disk cache.
#'
#' @return A 1-row tibble with ~34 scalar columns plus the list-columns
#'   `reports` (evaluation report manifest) and `complaints` (itemized
#'   complaint records).
#'
#' @export
#' @examples
#' \dontrun{
#' f <- ccld_facility("13423996")
#' tidyr::unnest(f, reports)
#' }
ccld_facility <- function(facnum, cache = TRUE) {
  if (length(facnum) != 1) {
    cli::cli_abort("ccld_facility() takes one license number; got {length(facnum)}.")
  }
  padded <- ccld_pad(facnum)
  if (is.na(padded)) cli::cli_abort("License is NA.")
  detail <- ccldr_fetch_json(paste0("FacilityDetail/", padded), cache = cache)
  reports <- ccldr_fetch_json(paste0("FacilityReports/", padded), cache = cache)
  parse_full_row(detail, reports, input = as.character(facnum))
}
```

- [ ] **Step 6: Run tests to verify they pass**

```r
devtools::document()
devtools::test(filter = "facility")
```

Expected: 2 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add R/ccld_facility.R R/parse.R tests/testthat/test-facility.R tests/testthat/fixtures/facility_reports_known.json man/ccld_facility.Rd NAMESPACE
git commit -m "feat(facility): add ccld_facility() with nested reports and complaints"
```

---

### Task 3.2: Cut v0.1.0

A working slice ships: `ccld_verify` + `ccld_facility` + `ccld_pad` + cache helpers.

- [ ] **Step 1: Update DESCRIPTION version**

Change `Version: 0.0.0.9000` to `Version: 0.1.0` in `DESCRIPTION`.

- [ ] **Step 2: Add a brief NEWS.md**

Create `NEWS.md`:

```markdown
# ccldr 0.1.0

Initial release.

* `ccld_verify()` — bulk-verify a vector of CCLD license numbers; returns a
  12-column tibble keyed on `facility_number`.
* `ccld_facility()` — full per-facility detail (~34 fields plus nested
  `reports` and `complaints` list-columns).
* `ccld_pad()` — vectorised license-number padding helper.
* `ccld_cache_clear()` / `ccld_cache_info()` — inspect and manage the
  on-disk response cache.
```

- [ ] **Step 3: Run a full check before tagging**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, 0 notes (or only the standard "checking CRAN incoming feasibility" note that we don't care about).

- [ ] **Step 4: Commit and tag**

```bash
git add DESCRIPTION NEWS.md
git commit -m "chore: release v0.1.0"
git tag -a v0.1.0 -m "ccldr 0.1.0: verify, facility, pad"
git push && git push --tags
```

---

## Phase 4: `ccld_alameda()`

### Task 4.1: type → facType mapping + input validation

Pure dispatcher, no I/O.

> **Empirical correction from spec:** the CCLD API's `facType=845` ("Child Care Center") contains only 4 facilities statewide. The bulk of Alameda's centers live in `facType=850` (Preschool). The type enum drops `"centers"` accordingly. Documented in the function help.

**Files:**
- Create: `R/ccld_alameda.R` (stub the public function and a private mapper)
- Create: `tests/testthat/test-alameda.R`

- [ ] **Step 1: Write failing tests**

Create `tests/testthat/test-alameda.R`:

```r
test_that("alameda_factype_for maps each accepted type to its facType", {
  expect_equal(alameda_factype_for("large_fccs"), "810")
  expect_equal(alameda_factype_for("infant_centers"), "830")
  expect_equal(alameda_factype_for("school_age_centers"), "840")
  expect_equal(alameda_factype_for("preschools"), "850")
  expect_equal(alameda_factype_for("single_licensed_centers"), "860")
})

test_that("alameda_factype_for supports match.arg partial matching", {
  expect_equal(alameda_factype_for("infant"), "830")
  expect_equal(alameda_factype_for("pre"), "850")
})

test_that("alameda_factype_for rejects unknown types with valid options listed", {
  expect_error(alameda_factype_for("small_fccs"), class = "ccldr_invalid_input")
  expect_error(alameda_factype_for("centers"), class = "ccldr_invalid_input")
  expect_error(alameda_factype_for("foo"), class = "ccldr_invalid_input")
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "alameda")
```

Expected: FAIL ("could not find function alameda_factype_for").

- [ ] **Step 3: Implement the mapper**

Create `R/ccld_alameda.R`:

```r
ALAMEDA_TYPE_MAP <- c(
  large_fccs              = "810",
  infant_centers          = "830",
  school_age_centers      = "840",
  preschools              = "850",
  single_licensed_centers = "860"
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
        "i" = "Use one of: {.val {choices}}"
      ),
      class = "ccldr_invalid_input"
    )
  }
  unname(ALAMEDA_TYPE_MAP[[matched]])
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::test(filter = "alameda")
```

Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/ccld_alameda.R tests/testthat/test-alameda.R
git commit -m "feat(alameda): add type → facType mapping helper with match.arg"
```

---

### Task 4.2: Single-city FacilitySearch + slim-tibble shaping

One city query, parse the FACILITYARRAY into the slim 12-column shape.

> **Empirical correction from spec:** the API silently returns 0 results when `city` and `county` are filtered together. Use `city=X` without `county`. The 17 Alameda cities are all in Alameda, so no downstream filter is needed. The response payload does not include CITY for each facility, so we stamp it from the query parameter.

**Files:**
- Modify: `R/ccld_alameda.R`
- Modify: `R/parse.R`
- Modify: `tests/testthat/test-alameda.R`
- Create: `tests/testthat/fixtures/facility_search_preschools_oakland.json`

- [ ] **Step 1: Capture the fixture**

```bash
curl -s -H "User-Agent: ccldr/0.0.0" \
  "https://www.ccld.dss.ca.gov/transparencyapi/api/FacilitySearch?facType=850&facility=&Street=&city=Oakland&zip=&county=&facnum=" \
  > tests/testthat/fixtures/facility_search_preschools_oakland.json
```

- [ ] **Step 2: Write failing tests**

Append to `tests/testthat/test-alameda.R`:

```r
test_that("parse_search_array returns a 12-column slim tibble keyed on facility_number", {
  body <- jsonlite::fromJSON("fixtures/facility_search_preschools_oakland.json", simplifyVector = FALSE)
  out <- parse_search_array(body)
  expect_s3_class(out, "tbl_df")
  expect_equal(ncol(out), 12)
  expect_true(all(c("facility_number", "facility_name", "status", "city", "zip") %in% names(out)))
  expect_true(all(out$found))
  expect_true(all(nchar(out$facility_number) == 9))
  # parse_search_array does NOT know the queried city — city is NA here
  # (alameda_search_city stamps it in the next layer)
  expect_true(all(is.na(out$city)))
})

test_that("alameda_search_city stamps the queried city onto every row", {
  setup_clean_cache()
  body <- paste(readLines("fixtures/facility_search_preschools_oakland.json", warn = FALSE), collapse = "\n")
  dispatch <- function(req) {
    httr2::response(200, body = body, headers = list("Content-Type" = "application/json"))
  }
  result <- httr2::with_mocked_responses(dispatch, alameda_search_city("850", "Oakland"))
  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) > 0)
  expect_true(all(result$city == "Oakland"))
})

test_that("alameda_search_city builds a URL without county filter", {
  setup_clean_cache()
  seen_url <- NULL
  dispatch <- function(req) {
    seen_url <<- req$url
    httr2::response(200, body = '{"COUNT":0,"FACILITYARRAY":[]}',
                    headers = list("Content-Type" = "application/json"))
  }
  httr2::with_mocked_responses(dispatch, alameda_search_city("850", "Oakland"))
  expect_match(seen_url, "facType=850")
  expect_match(seen_url, "city=Oakland")
  # County must be empty — the API returns 0 when city+county are combined
  expect_match(seen_url, "county=(&|$)")
})
```

- [ ] **Step 3: Run tests to verify they fail**

```r
devtools::test(filter = "alameda")
```

Expected: 2 new tests FAIL.

- [ ] **Step 4: Add `parse_search_array` to `R/parse.R`**

Append to `R/parse.R`:

```r
parse_search_array <- function(body) {
  arr <- body$FACILITYARRAY %||% list()
  if (length(arr) == 0) return(empty_slim_tibble())
  rows <- lapply(arr, function(item) {
    if (is.null(item)) return(NULL)
    tibble::tibble(
      input = item$FACILITYNUMBER %||% NA_character_,
      facility_number = ccld_pad(item$FACILITYNUMBER),
      found = TRUE,
      facility_name = empty_to_na(item$FACILITYNAME),
      facility_type = NA_character_,
      status = empty_to_na(item$STATUS),
      licensee_name = NA_character_,
      street_address = empty_to_na(item$STREETADDRESS),
      city = NA_character_,   # FacilitySearch payload does not include CITY
      zip = empty_to_na(item$ZIPCODE),
      license_effective_date = as.Date(NA),
      last_visit_date = as.Date(NA)
    )
  })
  do.call(rbind, Filter(Negate(is.null), rows))
}
```

The FacilitySearch payload doesn't include `LICENSEEFFECTIVEDATE`, `LASTVISITDATE`, `LICENSEENAME`, `FACILITYTYPE`, or `CITY` — those columns come back NA. `alameda_search_city` then stamps `city` from the query parameter (next step). Users who need the rest can call `ccld_facility()` per row.

- [ ] **Step 5: Add `alameda_search_city` to `R/ccld_alameda.R`**

Append to `R/ccld_alameda.R`:

```r
ALAMEDA_CITIES <- c(
  "Alameda", "Albany", "Berkeley", "Castro Valley", "Dublin",
  "Emeryville", "Fremont", "Hayward", "Livermore", "Newark",
  "Oakland", "Piedmont", "Pleasanton", "San Leandro", "San Lorenzo",
  "Sunol", "Union City"
)

alameda_search_city <- function(factype, city, cache = TRUE) {
  # Do NOT add county=Alameda — the API silently returns 0 when city+county
  # are combined. The 17 ALAMEDA_CITIES are all in Alameda, so the city
  # filter alone is correct.
  qs <- paste0(
    "FacilitySearch?facType=", factype,
    "&facility=&Street=&city=", utils::URLencode(city),
    "&zip=&county=&facnum="
  )
  body <- ccldr_fetch_json(qs, cache = cache)
  out <- parse_search_array(body)
  if (nrow(out) > 0) out$city <- city
  out
}
```

- [ ] **Step 6: Run tests to verify they pass**

```r
devtools::test(filter = "alameda")
```

Expected: all alameda tests PASS.

- [ ] **Step 7: Commit**

```bash
git add R/ccld_alameda.R R/parse.R tests/testthat/test-alameda.R tests/testthat/fixtures/facility_search_preschools_oakland.json
git commit -m "feat(alameda): add single-city FacilitySearch with slim-tibble shaping"
```

---

### Task 4.3: `ccld_alameda()` — city-walk + dedupe + export

Walk the 17 cities, union, dedupe. This is the public function.

**Files:**
- Modify: `R/ccld_alameda.R`
- Modify: `tests/testthat/test-alameda.R`

- [ ] **Step 1: Write failing tests**

Append to `tests/testthat/test-alameda.R`:

```r
test_that("ccld_alameda walks all 17 cities and dedupes by facility_number", {
  setup_clean_cache()
  body <- paste(readLines("fixtures/facility_search_preschools_oakland.json", warn = FALSE), collapse = "\n")
  call_count <- 0
  counting <- function(req) {
    call_count <<- call_count + 1
    httr2::response(200, body = body, headers = list("Content-Type" = "application/json"))
  }
  result <- httr2::with_mocked_responses(counting, ccld_alameda("preschools"))
  expect_equal(call_count, 17)
  # Each city returns the same fixture; dedupe should leave at most as many
  # rows as unique facility_numbers in the fixture.
  expect_equal(anyDuplicated(result$facility_number), 0)
  expect_s3_class(result, "tbl_df")
})

test_that("ccld_alameda errors on small_fccs with a route-to-CKAN hint", {
  setup_clean_cache()
  err <- expect_error(ccld_alameda("small_fccs"))
  expect_match(conditionMessage(err), "small_fccs", fixed = TRUE)
})

test_that("ccld_alameda errors on 'centers' (facType=845 is empty)", {
  setup_clean_cache()
  expect_error(ccld_alameda("centers"), class = "ccldr_invalid_input")
})

test_that("ccld_alameda warns when any single city hits the 250-cap", {
  setup_clean_cache()
  # Build a fixture with COUNT=250 to simulate the cap
  big_arr <- paste0(
    '{"FACILITYNUMBER":"', sprintf("013420%03d", 1:250),
    '","FACILITYNAME":"X","STATUS":"Licensed","STREETADDRESS":"x","COUNTY":"Alameda","ZIPCODE":"94606","TELEPHONE":"x"}',
    collapse = ","
  )
  capped_body <- paste0('{"COUNT":250,"FACILITYARRAY":[', big_arr, ']}')
  dispatch <- function(req) {
    httr2::response(200, body = capped_body, headers = list("Content-Type" = "application/json"))
  }
  expect_warning(
    httr2::with_mocked_responses(dispatch, ccld_alameda("preschools")),
    "250-result cap"
  )
})
```

- [ ] **Step 2: Run tests to verify they fail**

```r
devtools::test(filter = "alameda")
```

Expected: FAIL ("could not find function ccld_alameda").

- [ ] **Step 3: Implement the public function**

Append to `R/ccld_alameda.R`:

```r
#' Live Alameda snapshot for a child-care facility type
#'
#' Pulls the current set of Alameda-County child-care facilities of the given
#' type from the live CCLD Transparency API. Internally walks the 17 Alameda
#' cities to work around the API's 250-result per-call cap, unions the
#' results, and dedupes by `facility_number`.
#'
#' Two facility types are deliberately unsupported:
#'
#' * Small FCCs (`facType = 0`) — the API blocks the search entirely.
#' * Child Care Center (`facType = 845`) — the API has only 4 records statewide
#'   in this category; the bulk of "centers" live in `"preschools"`
#'   (`facType = 850`). Pass `"preschools"` instead.
#'
#' For Small FCC enumeration, use the open-data CSVs in
#' `chekos/ccld-open-data-snapshot/data/homes.csv`.
#'
#' @param type One of `"large_fccs"`, `"infant_centers"`, `"school_age_centers"`,
#'   `"preschools"`, `"single_licensed_centers"`. Partial matching via
#'   [match.arg()] is supported.
#' @param cache If `TRUE` (default), short-circuit per-city queries via the cache.
#'
#' @return A 12-column slim tibble (same shape as [ccld_verify()]).
#'
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
    cli::cli_progress_bar("Walking {length(ALAMEDA_CITIES)} Alameda cities",
                          total = length(ALAMEDA_CITIES))
  }
  per_city <- lapply(ALAMEDA_CITIES, function(city) {
    r <- alameda_search_city(factype, city, cache = cache)
    if (show_progress) cli::cli_progress_update()
    r
  })
  if (show_progress) cli::cli_progress_done()

  # Warn if any city hit the 250-result cap — likely missing rows.
  capped_cities <- ALAMEDA_CITIES[vapply(per_city, function(x) nrow(x) >= 250, logical(1))]
  if (length(capped_cities) > 0) {
    cli::cli_warn(c(
      "Hit the 250-result cap in {length(capped_cities)} cit{?y/ies}: {.val {capped_cities}}.",
      "i" = "Some facilities may be missing. Consider supplementing with the CKAN snapshot."
    ))
  }

  out <- do.call(rbind, per_city)
  out[!duplicated(out$facility_number), , drop = FALSE]
}
```

- [ ] **Step 4: Run tests to verify they pass**

```r
devtools::document()
devtools::test(filter = "alameda")
```

Expected: all alameda tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/ccld_alameda.R tests/testthat/test-alameda.R man/ccld_alameda.Rd NAMESPACE
git commit -m "feat(alameda): add ccld_alameda() city-walking snapshot"
```

---

### Task 4.4: Cut v0.2.0

- [ ] **Step 1: Update version + NEWS.md**

`DESCRIPTION`: bump `Version: 0.1.0` to `Version: 0.2.0`.

Prepend to `NEWS.md`:

```markdown
# ccldr 0.2.0

* `ccld_alameda(type)` — live Alameda snapshot per facility type, walking
  the 17 Alameda cities under the hood to work around the API's 250-result
  per-call cap. Supports `match.arg()` partial matching on `type`.

```

- [ ] **Step 2: Run full check**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Commit and tag**

```bash
git add DESCRIPTION NEWS.md
git commit -m "chore: release v0.2.0"
git tag -a v0.2.0 -m "ccldr 0.2.0: ccld_alameda() snapshot function"
git push && git push --tags
```

---

## Phase 5: Documentation and CI

### Task 5.1: README quickstart

Replace the design-only README with a working quickstart.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace `README.md` content**

```markdown
# ccldr

An R client for the [CCLD Transparency API](https://www.ccld.dss.ca.gov/carefacilitysearch/). Verify license numbers, pull facility detail, snapshot Alameda — all from inside your R script.

## Installation

```r
remotes::install_github("chekos/ccldr")
```

## Quickstart

```r
library(ccldr)
library(dplyr)
library(readr)

# 1. Verify a column of license numbers
rr <- read_csv("rr_sites_2026.csv")
verified <- ccld_verify(rr$license_number)

rr |> left_join(verified, by = c("license_number" = "input"))

# 2. Rich detail for one facility
ccld_facility("13423996") |>
  tidyr::unnest(reports)

# 3. Live Alameda snapshot
ccld_alameda("centers")
```

See `vignette("getting-started")` for a longer walkthrough and
[`docs/design.md`](docs/design.md) for the design.

## Related

- [`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot) — bulk CKAN snapshot of Alameda CCLD data and the Python `verify.py` companion. The R package here is the live, per-facility-detail layer.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: replace design-only README with working quickstart"
```

---

### Task 5.2: Getting-started vignette

**Files:**
- Create: `vignettes/getting-started.Rmd`

- [ ] **Step 1: Bootstrap the vignette**

```r
usethis::use_vignette("getting-started", "Getting started with ccldr")
```

- [ ] **Step 2: Replace the vignette body**

Open `vignettes/getting-started.Rmd` and replace its body (everything below the YAML front matter) with:

```rmd
```{r, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)
```

`ccldr` is a tidyverse-native R client for the CCLD Transparency API. This
vignette walks through the three things it's built to do.

## 1. Verify a column of license numbers

Imagine you have a CSV of new R&R intakes with a `license_number` column,
and you want to know which licenses CCLD actually recognises.

```{r}
library(ccldr)
library(dplyr)
library(readr)

rr <- read_csv("rr_sites.csv")
verified <- ccld_verify(rr$license_number)

# Join the verification back onto the source data
rr |>
  left_join(verified, by = c("license_number" = "input")) |>
  filter(!found) |>
  select(license_number, site_name)
```

`ccld_verify()` returns one row per input. Unknown licenses don't drop —
they appear with `found = FALSE` and `NA`s in the data columns.

## 2. Audit a specific site

When you need every field CCLD has for one license, use `ccld_facility()`:

```{r}
f <- ccld_facility("13423996")

# Visit history
f |> select(visits_total, visits_complaints, last_visit_date)

# Itemised complaints
f |> tidyr::unnest(complaints)

# Evaluation reports
f |> tidyr::unnest(reports)
```

## 3. Live Alameda snapshot

When you need the current population of a facility type in Alameda — for
example, to compare against an internal roster — use `ccld_alameda()`:

```{r}
centers     <- ccld_alameda("centers")
preschools  <- ccld_alameda("preschools")
large_fccs  <- ccld_alameda("large_fccs")
```

Each call walks the 17 Alameda cities under the hood (the API's
`FacilitySearch` endpoint caps at 250 results per call, which is below
Alameda's ~640 child-care centers).

**Note:** there is no `"small_fccs"` option — the API blocks
`facType = 0` searches. For small FCC enumeration, use the open-data CSVs
at
[`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot).

## Caching

Every API response is cached on disk for 24 hours by default. To bypass for
one call: `ccld_verify(x, cache = FALSE)`. To clear the whole cache:
`ccld_cache_clear()`. To inspect: `ccld_cache_info()`.
```

(The Rmd code-fence open/close lines above are escaped illustratively; the
actual file uses plain backticks.)

- [ ] **Step 3: Build vignettes locally to confirm they render**

```r
devtools::build_vignettes()
```

Expected: no errors. A `doc/getting-started.html` is created.

- [ ] **Step 4: Commit**

```bash
git add vignettes/getting-started.Rmd DESCRIPTION
git commit -m "docs: add getting-started vignette"
```

---

### Task 5.3: CI — R-CMD-check workflow

**Files:**
- Create: `.github/workflows/R-CMD-check.yaml`

- [ ] **Step 1: Add the workflow via `usethis`**

```r
usethis::use_github_action("check-standard")
```

This creates `.github/workflows/R-CMD-check.yaml` using `r-lib/actions`. Inspect it; the standard one runs on push and PR across `release`, `oldrel-1`, and `devel` R on Ubuntu, plus `release` on macOS and Windows.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/R-CMD-check.yaml .Rbuildignore
git commit -m "ci: add R-CMD-check workflow"
git push
```

- [ ] **Step 3: Watch the first CI run**

```bash
gh run watch
```

Expected: workflow completes successfully. If it fails for environment reasons (e.g. missing system dep for `qs`), fix in a follow-up commit.

---

## Self-review checklist

After finishing the plan above, verify against the spec:

- [x] `ccld_verify()` — Tasks 2.2 + 2.3
- [x] `ccld_facility()` — Task 3.1
- [x] `ccld_alameda()` — Tasks 4.1 + 4.2 + 4.3
- [x] `ccld_pad()` — Task 1.1
- [x] `ccld_cache_clear()` / `ccld_cache_info()` — Task 1.3
- [x] 12-column slim schema — `parse_slim_row` (Task 2.1) + `parse_search_array` (Task 4.2)
- [x] Full 34+nested schema — `parse_full_row` (Task 3.1)
- [x] Caching with 24h TTL — Task 1.3 + 1.4
- [x] 0.5s rate limit — Task 1.2 (`throttle()`)
- [x] `cli::cli_abort` errors with classed conditions — `ccldr_invalid_input`, `ccldr_http_error`, `ccldr_not_found`
- [x] Progress bar at >10 items — Task 2.3 + 4.3
- [x] Vignette — Task 5.2
- [x] CI — Task 5.3
- [x] Release tags — 0.1.0 (Task 3.2), 0.2.0 (Task 4.4)
