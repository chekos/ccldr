`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}

empty_to_na <- function(x) {
  if (is.null(x) || length(x) == 0 || identical(x, "") || all(is.na(x))) {
    return(NA_character_)
  }
  as.character(x[[1]])
}

parse_date <- function(x) {
  x <- empty_to_na(x)
  if (is.na(x) || x == "1/1/0001") {
    return(as.Date(NA))
  }
  as.Date(x, tryFormats = c("%m/%d/%Y", "%m/%e/%Y"), optional = TRUE)
}

parse_int <- function(x) {
  x <- empty_to_na(x)
  if (is.na(x)) {
    return(NA_integer_)
  }
  suppressWarnings(as.integer(x))
}

empty_slim_tibble <- function() {
  tibble::tibble(
    input = character(),
    facility_number = character(),
    found = logical(),
    facility_name = character(),
    facility_type = character(),
    status = character(),
    licensee_name = character(),
    street_address = character(),
    city = character(),
    zip = character(),
    license_effective_date = as.Date(character()),
    date_closed = as.Date(character()),
    last_visit_date = as.Date(character())
  )
}

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
    date_closed = if (found) parse_date(fd$DATECLOSED) else as.Date(NA),
    last_visit_date = if (found) parse_date(fd$LASTVISITDATE) else as.Date(NA)
  )
}

compact_records <- function(x) {
  x <- x %||% list()
  Filter(function(item) !is.null(item), x)
}

parse_reports <- function(reports_body) {
  records <- compact_records(reports_body$REPORTARRAY)
  if (length(records) == 0) {
    return(tibble::tibble(
      report_date = as.Date(character()),
      report_title = character(),
      report_type = character(),
      report_page = character(),
      control_number = character()
    ))
  }

  tibble::tibble(
    report_date = as.Date(vapply(records, function(r) as.character(parse_date(r$REPORTDATE)), character(1))),
    report_title = vapply(records, function(r) empty_to_na(r$REPORTTITLE), character(1)),
    report_type = vapply(records, function(r) empty_to_na(r$REPORTTYPE), character(1)),
    report_page = vapply(records, function(r) empty_to_na(r$REPORTPAGE), character(1)),
    control_number = vapply(records, function(r) empty_to_na(r$CONTROLNUMBER), character(1))
  )
}

parse_complaints <- function(detail_body) {
  records <- compact_records((detail_body$FacilityDetail %||% list())$COMPLAINTARRAY)
  if (length(records) == 0) {
    return(tibble::tibble(
      complaint_date = as.Date(character()),
      allegation = character(),
      outcome = character()
    ))
  }

  tibble::tibble(
    complaint_date = as.Date(vapply(records, function(x) {
      as.character(parse_date(x$COMPLAINTDATE %||% x$DATE))
    }, character(1))),
    allegation = vapply(records, function(x) empty_to_na(x$ALLEGATION), character(1)),
    outcome = vapply(records, function(x) empty_to_na(x$OUTCOME), character(1))
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
    client_served_1 = empty_to_na(fd$CLIENTSERVED1),
    client_served_2 = empty_to_na(fd$CLIENTSERVED2),
    client_served_3 = empty_to_na(fd$CLIENTSERVED3),
    client_served_4 = empty_to_na(fd$CLIENTSERVED4),
    client_served_5 = empty_to_na(fd$CLIENTSERVED5),
    client_served_6 = empty_to_na(fd$CLIENTSERVED6),
    comments = empty_to_na(fd$COMMENTS),
    comments_2 = empty_to_na(fd$COMMENTS2),
    license_effective_date = parse_date(fd$LICENSEEFFECTIVEDATE),
    license_first_date = parse_date(fd$LICENSEFIRSTDATE),
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
    other_type_a = parse_int(fd$NBROTHERTYPA),
    other_type_b = parse_int(fd$NBROTHERTYPB),
    visit_date_all = parse_date(fd$VSTDATEALL),
    visit_date_complaint = parse_date(fd$VSTDATECMPLT),
    visit_date_inspection = parse_date(fd$VSTDATEINSP),
    visit_date_other = parse_date(fd$VSTDATEOTHER),
    district_office = empty_to_na(fd$DISTRICTOFFICE),
    district_office_address = empty_to_na(fd$DOADDRESS),
    district_office_city = empty_to_na(fd$DOCITY),
    district_office_state = empty_to_na(fd$DOSTATE),
    district_office_zip = empty_to_na(fd$DOZIPCODE),
    district_office_phone = empty_to_na(fd$DOTELEPHONE),
    complaint_count = parse_int(fd$CMPCOUNT),
    total_complaint_visits = parse_int(fd$TOTCMPVISITS),
    total_substantiated_allegations = parse_int(fd$TOTSUBALG),
    total_inconclusive_allegations = parse_int(fd$TOTINCALG),
    total_unsubstantiated_allegations = parse_int(fd$TOTUNSALG),
    total_unfounded_allegations = parse_int(fd$TOTUNFALG),
    total_type_a = parse_int(fd$TOTTYPEA),
    total_type_b = parse_int(fd$TOTTYPEB),
    reports = list(parse_reports(reports_body)),
    complaints = list(parse_complaints(detail_body))
  )
}

parse_search_array <- function(body) {
  records <- compact_records(body$FACILITYARRAY)
  if (length(records) == 0) {
    return(empty_slim_tibble())
  }

  rows <- lapply(records, function(item) {
    tibble::tibble(
      input = empty_to_na(item$FACILITYNUMBER),
      facility_number = ccld_pad(item$FACILITYNUMBER),
      found = TRUE,
      facility_name = empty_to_na(item$FACILITYNAME),
      facility_type = NA_character_,
      status = empty_to_na(item$STATUS),
      licensee_name = NA_character_,
      street_address = empty_to_na(item$STREETADDRESS),
      city = NA_character_,
      zip = empty_to_na(item$ZIPCODE),
      license_effective_date = as.Date(NA),
      date_closed = as.Date(NA),
      last_visit_date = as.Date(NA)
    )
  })
  do.call(rbind, rows)
}
