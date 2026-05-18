test_that("census_geocoder_request builds a no-key geocoder request", {
  req <- census_geocoder_request(
    "1221 Oak Street, Oakland, CA, 94612",
    benchmark = "Public_AR_Current",
    vintage = "Current_Current",
    layers = "all"
  )

  expect_s3_class(req, "httr2_request")
  expect_match(req$url, "geocoder/geographies/onelineaddress")
  expect_match(req$url, "address=1221")
  expect_match(req$url, "benchmark=Public_AR_Current")
  expect_match(req$url, "vintage=Current_Current")
  expect_match(req$url, "layers=all")
  expect_false(grepl("key=", req$url, fixed = TRUE))
})

test_that("parse_census_geocoder_response extracts geography columns", {
  body <- load_fixture("census_geocoder_oakland.json")
  row <- parse_census_geocoder_response(
    body,
    input_address = "1221 Oak Street, Oakland, CA, 94612"
  )

  expect_equal(row$geocode_status, "matched")
  expect_equal(row$geocode_matched_address, "1221 OAK ST, OAKLAND, CA, 94612")
  expect_equal(row$state_fips, "06")
  expect_equal(row$county_fips, "06001")
  expect_equal(row$census_tract_geoid, "06001403402")
  expect_equal(row$census_block_group_geoid, "060014034021")
  expect_equal(row$census_block_geoid, "060014034021005")
  expect_equal(row$zcta_geoid, "94612")
  expect_equal(row$place_name, "Oakland city")
  expect_equal(row$unified_school_district_name, "Oakland Unified School District")
  expect_equal(row$state_senate_district, "7")
  expect_equal(row$state_assembly_district, "18")
  expect_equal(row$congressional_district, "12")
  expect_equal(row$tiger_line_id, "125000948")
  expect_equal(row$tiger_line_side, "L")
  expect_equal(row$latitude, 37.799894764455)
  expect_equal(row$longitude, -122.263716981538)
})

test_that("parse_census_geocoder_response handles unmatched addresses", {
  row <- parse_census_geocoder_response(
    list(result = list(addressMatches = list())),
    input_address = "1 Missing Way, Oakland, CA"
  )

  expect_equal(row$geocode_status, "unmatched")
  expect_equal(row$geocode_input, "1 Missing Way, Oakland, CA")
  expect_true(is.na(row$census_tract_geoid))
})

test_that("ccld_add_census_geographies appends rows and deduplicates requests", {
  setup_clean_cache()
  calls <- 0
  facilities <- tibble::tibble(
    facility_number = c("000000001", "000000002", "000000003"),
    street_address = c("1221 Oak Street", "1221 Oak Street", "Unavailable"),
    city = c("Oakland", "Oakland", "Oakland"),
    zip = c("94612", "94612", "94612")
  )

  result <- httr2::with_mocked_responses(function(req) {
    calls <<- calls + 1
    expect_match(req$url, "geocoder/geographies/onelineaddress")
    expect_match(req$url, "layers=all")
    mock_json_response(fixture_text("census_geocoder_oakland.json"))
  }, {
    ccld_add_census_geographies(facilities)
  })

  expect_equal(calls, 1)
  expect_equal(nrow(result), 3)
  expect_equal(result$geocode_status, c("matched", "matched", "not_geocoded"))
  expect_equal(result$census_tract_geoid[1:2], c("06001403402", "06001403402"))
  expect_true(is.na(result$census_tract_geoid[3]))
})

test_that("ccld_add_census_geographies preserves empty inputs", {
  result <- ccld_add_census_geographies(empty_slim_tibble())

  expect_equal(nrow(result), 0)
  expect_true("geocode_status" %in% names(result))
  expect_true("zcta_geoid" %in% names(result))
})

test_that("ccld_add_census_geographies uses explicit state columns when present", {
  setup_clean_cache()
  facilities <- tibble::tibble(
    street_address = "1221 Oak Street",
    city = "Oakland",
    state = "CA",
    zip = "94612"
  )

  result <- httr2::with_mocked_responses(function(req) {
    expect_match(req$url, "address=1221")
    expect_match(req$url, "CA")
    mock_json_response(fixture_text("census_geocoder_oakland.json"))
  }, {
    ccld_add_census_geographies(facilities, state_col = "state", cache = FALSE)
  })

  expect_equal(result$state_fips, "06")
})
