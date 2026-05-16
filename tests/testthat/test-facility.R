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
