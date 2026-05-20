test_that("ccld_facility returns a 1-row tibble with all fields", {
  setup_clean_cache()
  detail <- fixture_text("facility_detail_known.json")
  reports <- fixture_text("facility_reports_known.json")
  dispatch <- function(req) {
    if (grepl("FacilityReports", req$url)) mock_json_response(reports) else mock_json_response(detail)
  }
  result <- httr2::with_mocked_responses(dispatch, ccld_facility("13423996"))
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$facility_number, "013423996")
  expect_equal(result$facility_name, "JOHNSON III, JOHNNY")
  expect_type(result$reports, "list")
  expect_s3_class(result$reports[[1]], "tbl_df")
  expect_equal(nrow(result$reports[[1]]), 1)
  expect_true("report_date" %in% names(result$reports[[1]]))
  expect_type(result$complaints, "list")
  expect_s3_class(result$complaints[[1]], "tbl_df")
})

test_that("ccld_facility errors with class ccldr_not_found for unknown license", {
  setup_clean_cache()
  dispatch <- function(req) mock_json_response(fixture_text("facility_detail_unknown.json"))
  expect_error(
    httr2::with_mocked_responses(dispatch, ccld_facility("99999999")),
    class = "ccldr_not_found"
  )
})

test_that("ccld_facilities returns full details for a vector", {
  setup_clean_cache()
  detail <- fixture_text("facility_detail_known.json")
  reports <- fixture_text("facility_reports_known.json")
  dispatch <- function(req) {
    if (grepl("FacilityReports", req$url)) mock_json_response(reports) else mock_json_response(detail)
  }

  result <- httr2::with_mocked_responses(
    dispatch,
    ccld_facilities(c("13423996", "13423996"))
  )

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$input, c("13423996", "13423996"))
  expect_true(all(result$found))
  expect_equal(result$facility_name, rep("JOHNSON III, JOHNNY", 2))
  expect_type(result$reports, "list")
  expect_s3_class(result$reports[[1]], "tbl_df")
  expect_type(result$complaints, "list")
})

test_that("ccld_facilities preserves unknown and NA inputs", {
  setup_clean_cache()
  known <- fixture_text("facility_detail_known.json")
  reports <- fixture_text("facility_reports_known.json")
  unknown <- fixture_text("facility_detail_unknown.json")
  dispatch <- function(req) {
    if (grepl("FacilityReports", req$url)) {
      mock_json_response(reports)
    } else if (grepl("099999999", req$url)) {
      mock_json_response(unknown)
    } else {
      mock_json_response(known)
    }
  }

  result <- httr2::with_mocked_responses(
    dispatch,
    ccld_facilities(c("99999999", "13423996", NA))
  )

  expect_equal(nrow(result), 3)
  expect_equal(result$input, c("99999999", "13423996", NA))
  expect_equal(result$found, c(FALSE, TRUE, FALSE))
  expect_true(is.na(result$facility_name[1]))
  expect_true(is.na(result$facility_number[3]))
  expect_s3_class(result$reports[[1]], "tbl_df")
  expect_equal(nrow(result$reports[[1]]), 0)
})

test_that("ccld_facilities dedupes before fetching details and reports", {
  setup_clean_cache()
  calls <- character()
  dispatch <- function(req) {
    calls <<- c(calls, req$url)
    if (grepl("FacilityReports", req$url)) {
      mock_json_response(fixture_text("facility_reports_known.json"))
    } else {
      mock_json_response(fixture_text("facility_detail_known.json"))
    }
  }

  result <- httr2::with_mocked_responses(
    dispatch,
    ccld_facilities(c("13423996", "13423996", "013423996"))
  )

  expect_equal(nrow(result), 3)
  expect_equal(sum(grepl("FacilityDetail", calls)), 1)
  expect_equal(sum(grepl("FacilityReports", calls)), 1)
})
