# Capacity audits

Use this workflow when you have a list of sites and need to compare your
local licensed-capacity records against the current CCLD facility
record.

The examples are not evaluated during site builds because they call the
live CCLD Transparency API.

## Start with your site list

Your source file needs one column with CCLD license numbers and, if you
want to compare local values, one column with your local capacity value.

``` r

library(ccldr)
library(dplyr)
library(readr)

sites <- read_csv("rr_sites_2026.csv", col_types = cols(.default = "c")) |>
  mutate(local_capacity = as.integer(local_capacity))
```

Representative output:

``` text
#> # A tibble: 3 x 3
#>   site_name                 license_number local_capacity
#>   <chr>                     <chr>                   <int>
#> 1 Johnson Family Child Care 13423996                   14
#> 2 Agape Learning Center     013423056                  60
#> 3 Unknown Site              99999999                   24
```

## Verify first

Run
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
first. It screens unknown or invalid licenses and returns licensed
capacity for every facility found by the API.

``` r

verified <- ccld_verify(sites$license_number)

sites_verified <- sites |>
  bind_cols(verified |> select(-input))

sites_verified |>
  count(found, status, sort = TRUE)
```

Representative output:

``` text
#> # A tibble: 3 x 3
#>   found status                         n
#>   <lgl> <chr>                      <int>
#> 1 TRUE  Licensed                     184
#> 2 TRUE  Closed, Licensee Initiated     6
#> 3 FALSE <NA>                           3
```

`capacity` is parsed from the CCLD `CAPACITY` field. If a license is
unknown, invalid, or not found, `capacity` is `NA`.

## Compare capacities

Compare your local capacity value with the current CCLD value. Keep
missing values visible so they can be reviewed instead of silently
dropping out.

``` r

capacity_audit <- sites_verified |>
  mutate(
    capacity_delta = capacity - local_capacity,
    capacity_matches = !is.na(capacity) &
      !is.na(local_capacity) &
      capacity == local_capacity,
    needs_capacity_review = !found |
      is.na(capacity) |
      is.na(local_capacity) |
      capacity != local_capacity
  )
```

Representative output:

``` text
#> # A tibble: 3 x 6
#>   site_name                 local_capacity capacity capacity_delta capacity_matches needs_capacity_review
#>   <chr>                              <int>    <int>          <int> <lgl>            <lgl>
#> 1 Johnson Family Child Care             14       14              0 TRUE             FALSE
#> 2 Agape Learning Center                 54       60              6 FALSE            TRUE
#> 3 Unknown Site                          24       NA             NA FALSE            TRUE
```

## Review mismatches

Sort records that need review by the size of the difference, then keep
the fields that make follow-up easy.

``` r

capacity_audit |>
  filter(needs_capacity_review) |>
  arrange(desc(abs(capacity_delta)), site_name) |>
  select(
    site_name,
    license_number,
    found,
    facility_name,
    status,
    local_capacity,
    capacity,
    capacity_delta,
    date_closed
  )
```

Representative output:

``` text
#> # A tibble: 3 x 9
#>   site_name             license_number found facility_name         status   local_capacity capacity capacity_delta date_closed
#>   <chr>                 <chr>          <lgl> <chr>                 <chr>             <int>    <int>          <int> <date>
#> 1 Agape Learning Center 013423056      TRUE  AGAPE LEARNING CENTER Licensed             54       60              6 NA
#> 2 Unknown Site          99999999       FALSE <NA>                  <NA>                 24       NA             NA NA
#> 3 Closed Site           013423958      TRUE  AHMADI, MARIAM        Closed...             8        8              0 2026-04-17
```

If `capacity = NA` for a found facility, treat it as missing in the
current CCLD detail response and review the facility manually.

## Refresh deliberately

The package caches API responses while you work. For a capacity audit,
clear the cache at the start of a scheduled run or bypass the cache when
checking one important facility.

``` r

ccld_cache_clear()

ccld_verify("013423996", cache = FALSE) |>
  select(facility_number, facility_name, status, capacity)
```

Representative output:

``` text
#> # A tibble: 1 x 4
#>   facility_number facility_name       status   capacity
#>   <chr>           <chr>               <chr>       <int>
#> 1 013423996       JOHNSON III, JOHNNY Licensed       14
```

## A compact helper

For repeated audits, wrap the workflow in a small helper. This keeps the
bulk verification step explicit and makes the local capacity column
configurable.

``` r

add_capacity_audit <- function(data, license_col = license_number, capacity_col = local_capacity) {
  data <- data |>
    mutate(
      .license_input = as.character({{ license_col }}),
      .local_capacity = as.integer({{ capacity_col }})
    )

  verified <- ccld_verify(data$.license_input)

  data |>
    bind_cols(verified |> select(-input)) |>
    mutate(
      capacity_delta = capacity - .local_capacity,
      capacity_matches = !is.na(capacity) &
        !is.na(.local_capacity) &
        capacity == .local_capacity,
      needs_capacity_review = !found |
        is.na(capacity) |
        is.na(.local_capacity) |
        capacity != .local_capacity
    ) |>
    select(-.license_input)
}

capacity_audit <- add_capacity_audit(sites, license_number, local_capacity)
```

Representative output:

``` text
#> # A tibble: 3 x 5
#>   site_name                 capacity local_capacity capacity_delta needs_capacity_review
#>   <chr>                        <int>          <int>          <int> <lgl>
#> 1 Johnson Family Child Care       14             14              0 FALSE
#> 2 Agape Learning Center           60             54              6 TRUE
#> 3 Unknown Site                    NA             24             NA TRUE
```
