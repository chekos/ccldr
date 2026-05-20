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

test_that("parse_search_array returns a 14-column slim tibble keyed on facility_number", {
  body <- load_fixture("facility_search_preschools_oakland.json")
  out <- parse_search_array(body)
  expect_s3_class(out, "tbl_df")
  expect_equal(ncol(out), 14)
  expect_true(all(c("facility_number", "facility_name", "status", "city", "zip") %in% names(out)))
  expect_true(all(out$found))
  expect_true(all(nchar(out$facility_number) == 9))
  expect_true(all(is.na(out$city)))
  expect_true(all(is.na(out$capacity)))
  expect_true(all(is.na(out$date_closed)))
})

test_that("alameda_search_city stamps the queried city onto every row", {
  setup_clean_cache()
  dispatch <- function(req) mock_json_response(fixture_text("facility_search_preschools_oakland.json"))
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
    mock_json_response('{"COUNT":0,"FACILITYARRAY":[]}')
  }
  httr2::with_mocked_responses(dispatch, alameda_search_city("850", "Oakland"))
  expect_match(seen_url, "facType=850")
  expect_match(seen_url, "city=Oakland")
  expect_match(seen_url, "county=(&|$)")
})

test_that("ccld_alameda walks all 17 cities and dedupes by facility_number", {
  setup_clean_cache()
  call_count <- 0
  dispatch <- function(req) {
    call_count <<- call_count + 1
    mock_json_response(fixture_text("facility_search_preschools_oakland.json"))
  }
  result <- httr2::with_mocked_responses(dispatch, ccld_alameda("preschools"))
  expect_equal(call_count, 17)
  expect_equal(anyDuplicated(result$facility_number), 0)
  expect_s3_class(result, "tbl_df")
})

test_that("ccld_alameda errors on small_fccs with a route-to-CKAN hint", {
  setup_clean_cache()
  err <- expect_error(ccld_alameda("small_fccs"), class = "ccldr_invalid_input")
  expect_match(conditionMessage(err), "small_fccs", fixed = TRUE)
})

test_that("ccld_alameda errors on centers", {
  setup_clean_cache()
  expect_error(ccld_alameda("centers"), class = "ccldr_invalid_input")
})

test_that("ccld_alameda warns when any single city hits the 250-cap", {
  setup_clean_cache()
  records <- paste0(
    '{"FACILITYNUMBER":"', sprintf("013420%03d", 1:250),
    '","FACILITYNAME":"X","STATUS":"Licensed","STREETADDRESS":"x",',
    '"COUNTY":"Alameda","ZIPCODE":"94606","TELEPHONE":"x"}',
    collapse = ","
  )
  capped_body <- paste0('{"COUNT":250,"FACILITYARRAY":[', records, "]}")
  dispatch <- function(req) mock_json_response(capped_body)
  expect_warning(
    httr2::with_mocked_responses(dispatch, ccld_alameda("preschools")),
    "250-result cap"
  )
})
