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

test_that("ccld_verify handles a 2-element vector", {
  setup_clean_cache()
  known <- fixture_text("facility_detail_known.json")
  unknown <- fixture_text("facility_detail_unknown.json")
  dispatch <- function(req) {
    if (grepl("099999999", req$url)) mock_json_response(unknown) else mock_json_response(known)
  }
  result <- httr2::with_mocked_responses(dispatch, ccld_verify(c("13423996", "99999999")))
  expect_equal(nrow(result), 2)
  expect_equal(result$found, c(TRUE, FALSE))
})

test_that("ccld_verify dedupes duplicate inputs before fetching", {
  setup_clean_cache()
  call_count <- 0
  dispatch <- function(req) {
    call_count <<- call_count + 1
    mock_json_response(fixture_text("facility_detail_known.json"))
  }
  result <- httr2::with_mocked_responses(
    dispatch,
    ccld_verify(c("13423996", "13423996", "13423996"))
  )
  expect_equal(nrow(result), 3)
  expect_equal(call_count, 1)
})

test_that("ccld_verify preserves input order after dedupe", {
  setup_clean_cache()
  known <- fixture_text("facility_detail_known.json")
  unknown <- fixture_text("facility_detail_unknown.json")
  dispatch <- function(req) {
    if (grepl("099999999", req$url)) mock_json_response(unknown) else mock_json_response(known)
  }
  result <- httr2::with_mocked_responses(
    dispatch,
    ccld_verify(c("99999999", "13423996", "99999999"))
  )
  expect_equal(result$input, c("99999999", "13423996", "99999999"))
  expect_equal(result$found, c(FALSE, TRUE, FALSE))
})

test_that("ccld_verify handles NA inputs without making requests", {
  setup_clean_cache()
  call_count <- 0
  dispatch <- function(req) {
    call_count <<- call_count + 1
    mock_json_response(fixture_text("facility_detail_known.json"))
  }
  result <- httr2::with_mocked_responses(
    dispatch,
    ccld_verify(c("13423996", NA, "13423996"))
  )
  expect_equal(nrow(result), 3)
  expect_true(is.na(result$facility_number[2]))
  expect_false(result$found[2])
  expect_equal(call_count, 1)
})
