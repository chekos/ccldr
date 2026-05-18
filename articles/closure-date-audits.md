# Closure date audits

Use this workflow when you have a list of sites and need to know which
ones have closed, when they closed, and whether the CCLD record still
matches your local source.

The examples are not evaluated during site builds because they call the
live CCLD Transparency API.

## Start with your site list

Your source file only needs one column with CCLD license numbers. Keep
whatever site identifiers you use locally so the results can be joined
back cleanly.

``` r

library(ccldr)
library(dplyr)
library(readr)
library(tidyr)

sites <- read_csv("rr_sites_2026.csv", col_types = cols(.default = "c"))
```

## Verify first

Run
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
before requesting full detail. It screens unknown or invalid licenses
and returns current status for every input row.

``` r

verified <- ccld_verify(sites$license_number)

sites_verified <- sites |>
  left_join(verified, by = c("license_number" = "input"))

sites_verified |>
  count(found, status, sort = TRUE)
```

[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
is the right first pass for a full file, but it does not include the
closure date. Closure dates are part of the full facility detail record.

## Pull closure dates

Use
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
for the records where the API found a facility. The full record includes
`date_closed`, parsed from the CCLD `DATECLOSED` field.

``` r

closure_detail <- sites_verified |>
  filter(found) |>
  distinct(facility_number) |>
  mutate(
    detail = lapply(
      facility_number,
      function(.x) ccld_facility(.x) |>
        select(
          facility_number,
          facility_name,
          status,
          date_closed,
          license_effective_date,
          last_visit_date
        )
    )
  ) |>
  select(detail) |>
  unnest(detail)
```

Join the detail rows back to your original site list.

``` r

closure_audit <- sites_verified |>
  select(
    site_name,
    license_number,
    facility_number,
    found,
    verified_status = status
  ) |>
  left_join(
    closure_detail,
    by = "facility_number",
    suffix = c("_verified", "_detail")
  ) |>
  mutate(
    status = coalesce(status_detail, verified_status),
    is_closed = !is.na(date_closed) |
      grepl("^Closed", status, ignore.case = TRUE)
  )
```

## Review closed and unmatched sites

Closed facilities usually have a `status` beginning with `"Closed"` and
a non-missing `date_closed`. Open facilities usually return `NA` for
`date_closed`.

``` r

closure_audit |>
  filter(is_closed | !found) |>
  arrange(desc(is_closed), date_closed, site_name) |>
  select(
    site_name,
    license_number,
    found,
    facility_name,
    status,
    date_closed,
    last_visit_date
  )
```

If a facility is found but has `date_closed = NA`, treat it as not
having a closure date in the current CCLD detail response.

## Refresh deliberately

The package caches API responses while you work. For a closure audit,
clear the cache at the start of a scheduled run or bypass the cache when
checking one important facility.

``` r

ccld_cache_clear()

closure_detail <- ccld_facility("013423958", cache = FALSE) |>
  select(facility_number, facility_name, status, date_closed)
```

## A compact helper

For repeated audits, wrap the workflow in a small helper. This keeps the
one-detail-request-per-facility step explicit.

``` r

add_closure_dates <- function(data, license_col = license_number) {
  data <- data |>
    mutate(.license_input = as.character({{ license_col }}))

  verified <- ccld_verify(data$.license_input)

  with_status <- data |>
    left_join(verified, by = c(".license_input" = "input"))

  detail <- with_status |>
    filter(found) |>
    distinct(facility_number) |>
    mutate(
      detail = lapply(
        facility_number,
        function(.x) ccld_facility(.x) |>
          select(facility_number, status, date_closed, last_visit_date)
      )
    ) |>
    select(detail) |>
    unnest(detail)

  with_status |>
    left_join(
      detail,
      by = "facility_number",
      suffix = c("_verified", "_detail")
    ) |>
    mutate(
      status = coalesce(status_detail, status_verified),
      is_closed = !is.na(date_closed) |
        grepl("^Closed", status, ignore.case = TRUE)
    ) |>
    select(-.license_input)
}

closure_audit <- add_closure_dates(sites, license_number)
```
