#' Add Census geographies to CCLD facility rows
#'
#' Geocodes facility address columns with the U.S. Census Geocoder and appends
#' Census geography identifiers, including tract, block, block group, ZCTA,
#' place, county subdivision, urban area, legislative districts, and school
#' district fields when the geocoder returns them.
#'
#' `ccld_add_census_geographies()` works with rows returned by
#' [ccld_verify()], [ccld_facility()], and [ccld_alameda()]. Inputs are returned
#' in the same order, and unmatched or ungeocodable rows are kept with
#' `geocode_status = "unmatched"` or `"not_geocoded"`.
#'
#' The Census Geocoder does not require an API key. Results are cached in the
#' package cache using the same cache controls as the CCLD API helpers.
#'
#' @param data A data frame containing facility address columns.
#' @param address_col Name of the street address column. Defaults to
#'   `"street_address"`.
#' @param city_col Name of the city column. Defaults to `"city"`.
#' @param state_col Optional name of the state column. When `NULL`, missing, or
#'   blank, `default_state` is used.
#' @param zip_col Name of the ZIP code column. Defaults to `"zip"`.
#' @param default_state State abbreviation used when `state_col` is absent or
#'   blank. Defaults to `"CA"`.
#' @param benchmark Census Geocoder benchmark. Defaults to
#'   `"Public_AR_Current"`.
#' @param vintage Census Geocoder vintage. Defaults to `"Current_Current"`.
#' @param layers Census geography layers to request. Defaults to `"all"` so
#'   ZCTA and school district layers are included when available.
#' @param cache Logical value (default `TRUE`) controlling whether the on-disk
#'   response cache is used.
#'
#' @return A tibble containing the input columns plus Census geocoding and
#'   geography columns.
#' @family geography helpers
#' @export
#' @examples
#' \dontrun{
#' ccld_alameda("preschools") |>
#'   ccld_add_census_geographies()
#' }
ccld_add_census_geographies <- function(data,
                                        address_col = "street_address",
                                        city_col = "city",
                                        state_col = NULL,
                                        zip_col = "zip",
                                        default_state = "CA",
                                        benchmark = "Public_AR_Current",
                                        vintage = "Current_Current",
                                        layers = "all",
                                        cache = TRUE) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.", class = "ccldr_invalid_input")
  }
  if (!address_col %in% names(data)) {
    cli::cli_abort(
      "{.arg address_col} must name a column in {.arg data}.",
      class = "ccldr_invalid_input"
    )
  }

  out <- tibble::as_tibble(data)
  if (nrow(out) == 0) {
    return(tibble::as_tibble(cbind(out, empty_census_geo_tibble())))
  }

  address <- column_or_na(out, address_col)
  city <- column_or_na(out, city_col)
  state <- state_values(out, state_col, default_state)
  zip <- column_or_na(out, zip_col)
  one_line <- build_census_address(address, city, state, zip)

  geocodable <- is_geocodable_address(address)
  unique_addresses <- unique(one_line[geocodable & !is.na(one_line)])
  geocoded <- vector("list", length(unique_addresses))
  names(geocoded) <- unique_addresses

  show_progress <- length(unique_addresses) > 10 && interactive()
  if (show_progress) {
    cli::cli_progress_bar("Geocoding facility addresses", total = length(unique_addresses))
  }

  for (i in seq_along(unique_addresses)) {
    geocoded[[i]] <- parse_census_geocoder_response(
      fetch_census_geocoder(
        unique_addresses[[i]],
        benchmark = benchmark,
        vintage = vintage,
        layers = layers,
        cache = cache
      ),
      input_address = unique_addresses[[i]]
    )
    if (show_progress) {
      cli::cli_progress_update()
    }
  }
  if (show_progress) {
    cli::cli_progress_done()
  }

  rows <- lapply(seq_len(nrow(out)), function(i) {
    if (!geocodable[[i]] || is.na(one_line[[i]])) {
      return(empty_census_geo_row(
        input_address = one_line[[i]],
        status = "not_geocoded"
      ))
    }
    geocoded[[one_line[[i]]]]
  })

  tibble::as_tibble(cbind(out, do.call(rbind, rows)))
}

CENSUS_GEOCODER_URL <- "https://geocoding.geo.census.gov/geocoder/geographies/onelineaddress"

fetch_census_geocoder <- function(address,
                                  benchmark = "Public_AR_Current",
                                  vintage = "Current_Current",
                                  layers = "all",
                                  cache = TRUE) {
  key <- paste(
    "CensusGeocoder/geographies/onelineaddress",
    benchmark,
    vintage,
    layers,
    address,
    sep = "|"
  )
  if (isTRUE(cache)) {
    hit <- cache_get(key)
    if (!is.null(hit)) {
      return(hit)
    }
  }

  throttle()
  req <- census_geocoder_request(
    address = address,
    benchmark = benchmark,
    vintage = vintage,
    layers = layers
  )
  if (isTRUE(getOption("ccldr.verbose", FALSE))) {
    cli::cli_inform("GET CensusGeocoder {address}")
  }

  resp <- httr2::req_perform(req)
  .ccldr_state$last_request_at <- as.numeric(Sys.time())
  status <- httr2::resp_status(resp)
  if (status >= 400) {
    body <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
    cli::cli_abort(
      c(
        "Census Geocoder request failed.",
        "x" = "Address: {.val {address}}",
        "x" = "Status: {status}",
        "i" = body
      ),
      class = "ccldr_geocoder_http_error"
    )
  }

  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  if (isTRUE(cache)) {
    cache_set(key, body)
  }
  body
}

census_geocoder_request <- function(address,
                                    benchmark = "Public_AR_Current",
                                    vintage = "Current_Current",
                                    layers = "all") {
  httr2::request(CENSUS_GEOCODER_URL) |>
    httr2::req_user_agent(user_agent()) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_url_query(
      address = address,
      benchmark = benchmark,
      vintage = vintage,
      layers = layers,
      format = "json"
    ) |>
    httr2::req_timeout(20) |>
    httr2::req_retry(max_tries = 2, backoff = function(tries) 2 ^ tries) |>
    httr2::req_error(is_error = function(resp) FALSE)
}

column_or_na <- function(data, col) {
  if (is.null(col) || !col %in% names(data)) {
    return(rep(NA_character_, nrow(data)))
  }
  as.character(data[[col]])
}

state_values <- function(data, state_col, default_state) {
  state <- column_or_na(data, state_col)
  missing <- is.na(state) | trimws(state) == ""
  state[missing] <- default_state
  state
}

build_census_address <- function(address, city, state, zip) {
  parts <- mapply(
    function(street, city_value, state_value, zip_value) {
      values <- c(street, city_value, state_value, zip_value)
      values <- values[!is.na(values) & trimws(values) != ""]
      if (length(values) == 0) {
        return(NA_character_)
      }
      paste(values, collapse = ", ")
    },
    address,
    city,
    state,
    zip,
    USE.NAMES = FALSE
  )
  as.character(parts)
}

is_geocodable_address <- function(address) {
  address <- as.character(address)
  present <- !is.na(address) & trimws(address) != ""
  present & !tolower(trimws(address)) %in% c("unavailable", "unknown", "not available")
}

parse_census_geocoder_response <- function(body, input_address) {
  matches <- ((body$result %||% list())$addressMatches) %||% list()
  if (length(matches) == 0) {
    return(empty_census_geo_row(input_address, status = "unmatched"))
  }

  match <- matches[[1]]
  geographies <- match$geographies %||% list()
  coordinates <- match$coordinates %||% list()
  tiger_line <- match$tigerLine %||% list()

  state <- geography_first(geographies, "States")
  county <- geography_first(geographies, "Counties")
  tract <- geography_first(geographies, "Census Tracts")
  block <- geography_first(geographies, "2020 Census Blocks")
  block_group <- geography_first(geographies, "Census Block Groups")
  zcta <- geography_first(geographies, "2020 Census ZIP Code Tabulation Areas")
  place <- geography_first(geographies, "Incorporated Places")
  cousub <- geography_first(geographies, "County Subdivisions")
  urban_area <- geography_first(geographies, "Urban Areas")
  congressional <- geography_first_pattern(geographies, "Congressional Districts")
  state_upper <- geography_first_pattern(geographies, "State Legislative Districts - Upper")
  state_lower <- geography_first_pattern(geographies, "State Legislative Districts - Lower")
  unified_school <- geography_first(geographies, "Unified School Districts")
  elementary_school <- geography_first(geographies, "Elementary School Districts")
  secondary_school <- geography_first(geographies, "Secondary School Districts")

  tibble::tibble(
    geocode_status = "matched",
    geocode_input = input_address,
    geocode_matched_address = empty_to_na(match$matchedAddress),
    latitude = parse_number(coordinates$y),
    longitude = parse_number(coordinates$x),
    tiger_line_id = empty_to_na(tiger_line$tigerLineId),
    tiger_line_side = empty_to_na(tiger_line$side),
    state_fips = empty_to_na(state$STATE %||% state$GEOID),
    state_name = empty_to_na(state$NAME),
    county_fips = empty_to_na(county$GEOID),
    county_name = empty_to_na(county$NAME),
    census_tract_geoid = empty_to_na(tract$GEOID),
    census_tract = empty_to_na(tract$TRACT),
    census_block_group_geoid = empty_to_na(block_group$GEOID),
    census_block_group = empty_to_na(block_group$BLKGRP),
    census_block_geoid = empty_to_na(block$GEOID),
    census_block = empty_to_na(block$BLOCK),
    zcta_geoid = empty_to_na(zcta$GEOID %||% zcta$ZCTA5),
    zcta = empty_to_na(zcta$ZCTA5 %||% zcta$BASENAME),
    place_geoid = empty_to_na(place$GEOID),
    place_name = empty_to_na(place$NAME),
    county_subdivision_geoid = empty_to_na(cousub$GEOID),
    county_subdivision_name = empty_to_na(cousub$NAME),
    urban_area_geoid = empty_to_na(urban_area$GEOID),
    urban_area_name = empty_to_na(urban_area$NAME),
    congressional_district_geoid = empty_to_na(congressional$GEOID),
    congressional_district = empty_to_na(congressional$BASENAME),
    state_senate_district_geoid = empty_to_na(state_upper$GEOID),
    state_senate_district = empty_to_na(state_upper$BASENAME),
    state_assembly_district_geoid = empty_to_na(state_lower$GEOID),
    state_assembly_district = empty_to_na(state_lower$BASENAME),
    unified_school_district_geoid = empty_to_na(unified_school$GEOID),
    unified_school_district_name = empty_to_na(unified_school$NAME),
    elementary_school_district_geoid = empty_to_na(elementary_school$GEOID),
    elementary_school_district_name = empty_to_na(elementary_school$NAME),
    secondary_school_district_geoid = empty_to_na(secondary_school$GEOID),
    secondary_school_district_name = empty_to_na(secondary_school$NAME)
  )
}

parse_number <- function(x) {
  x <- empty_to_na(x)
  if (is.na(x)) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(x))
}

geography_first <- function(geographies, layer) {
  records <- geographies[[layer]] %||% list()
  if (length(records) == 0) {
    return(list())
  }
  records[[1]]
}

geography_first_pattern <- function(geographies, pattern) {
  layer <- grep(pattern, names(geographies), value = TRUE, fixed = TRUE)
  if (length(layer) == 0) {
    return(list())
  }
  geography_first(geographies, layer[[1]])
}

empty_census_geo_tibble <- function() {
  tibble::tibble(
    geocode_status = character(),
    geocode_input = character(),
    geocode_matched_address = character(),
    latitude = numeric(),
    longitude = numeric(),
    tiger_line_id = character(),
    tiger_line_side = character(),
    state_fips = character(),
    state_name = character(),
    county_fips = character(),
    county_name = character(),
    census_tract_geoid = character(),
    census_tract = character(),
    census_block_group_geoid = character(),
    census_block_group = character(),
    census_block_geoid = character(),
    census_block = character(),
    zcta_geoid = character(),
    zcta = character(),
    place_geoid = character(),
    place_name = character(),
    county_subdivision_geoid = character(),
    county_subdivision_name = character(),
    urban_area_geoid = character(),
    urban_area_name = character(),
    congressional_district_geoid = character(),
    congressional_district = character(),
    state_senate_district_geoid = character(),
    state_senate_district = character(),
    state_assembly_district_geoid = character(),
    state_assembly_district = character(),
    unified_school_district_geoid = character(),
    unified_school_district_name = character(),
    elementary_school_district_geoid = character(),
    elementary_school_district_name = character(),
    secondary_school_district_geoid = character(),
    secondary_school_district_name = character()
  )
}

empty_census_geo_row <- function(input_address = NA_character_, status = "not_geocoded") {
  out <- empty_census_geo_tibble()
  out[1, ] <- NA
  out$geocode_status <- status
  out$geocode_input <- input_address
  out
}
