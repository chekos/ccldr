test_that("ccldr_request builds a request with the right URL and UA", {
  req <- ccldr_request("FacilityDetail/013423996")
  expect_s3_class(req, "httr2_request")
  expect_match(req$url, "transparencyapi/api/FacilityDetail/013423996$")
  expect_match(req$options$useragent, "^ccldr/")
})

test_that("ccldr_fetch_json returns parsed JSON for a known facility", {
  setup_clean_cache()
  result <- httr2::with_mocked_responses(
    function(req) mock_json_response(fixture_text("facility_detail_known.json")),
    ccldr_fetch_json("FacilityDetail/013423996")
  )
  expect_type(result, "list")
  expect_true("FacilityDetail" %in% names(result))
  expect_equal(result$FacilityDetail$FACILITYNUMBER, "013423996")
})

test_that("ccldr_fetch_json applies the configured delay between calls", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  withr::local_options(ccldr.delay = 0.05)
  .ccldr_state$last_request_at <- NA_real_
  t0 <- Sys.time()
  httr2::with_mocked_responses(function(req) mock_json_response("{}"), {
    ccldr_fetch_json("FacilityDetail/013423996", cache = FALSE)
    ccldr_fetch_json("FacilityDetail/013423997", cache = FALSE)
  })
  expect_gte(as.numeric(Sys.time() - t0), 0.04)
})

test_that("ccldr_fetch_json reads from cache when fresh", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("FacilityDetail/013423996", list(fixture = "yes"))
  result <- ccldr_fetch_json("FacilityDetail/013423996")
  expect_equal(result, list(fixture = "yes"))
})

test_that("ccldr_fetch_json bypasses cache when cache = FALSE", {
  setup_clean_cache()
  result <- httr2::with_mocked_responses(
    function(req) mock_json_response(fixture_text("facility_detail_known.json")),
    ccldr_fetch_json("FacilityDetail/013423996", cache = FALSE)
  )
  expect_equal(result$FacilityDetail$FACILITYNUMBER, "013423996")
})

test_that("ccldr_fetch_json writes to cache after a fresh fetch", {
  setup_clean_cache()
  httr2::with_mocked_responses(
    function(req) mock_json_response(fixture_text("facility_detail_known.json")),
    ccldr_fetch_json("FacilityDetail/013423996")
  )
  cached <- cache_get("FacilityDetail/013423996")
  expect_equal(cached$FacilityDetail$FACILITYNUMBER, "013423996")
})
