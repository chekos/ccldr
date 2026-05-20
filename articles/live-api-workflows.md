# Live API workflows

This article shows how the `ccldr` functions fit into recurring scripts.
The code is not evaluated during site builds because it calls the live
CCLD Transparency API.

## Verify intake records

Start with the source data you already maintain, then attach CCLD’s
current view of each license.

``` r

library(ccldr)
library(dplyr)
library(readr)

intakes <- read_csv("rr_sites_2026.csv", col_types = cols(.default = "c"))

verified <- ccld_verify(intakes$license_number)

audit <- intakes |>
  left_join(verified, by = c("license_number" = "input")) |>
  mutate(
    needs_follow_up = !found | is.na(facility_name)
  )

audit |>
  filter(needs_follow_up) |>
  select(site_name, license_number, found, status)
```

Representative output:

``` text
#> # A tibble: 2 x 4
#>   site_name    license_number found status
#>   <chr>        <chr>          <lgl> <chr>
#> 1 Unknown Site 99999999       FALSE <NA>
#> 2 Closed Site  013423958      TRUE  Closed, Licensee Initiated
```

[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
preserves input order and returns duplicate inputs as duplicate rows,
but it only fetches each distinct license once.

## Refresh intentionally

The default cache avoids repeated requests while you iterate on scripts.
For a scheduled job, clear the cache at the start of a run or bypass it
for the calls that must be fresh.

``` r

ccld_cache_clear()

verified <- ccld_verify(intakes$license_number)

fresh_one <- ccld_facility("13423996", cache = FALSE)
```

Representative output:

``` text
#> Cache cleared.
#> verified: 193 rows
#> fresh_one: 1 row, 57 columns
```

Use a longer delay if you are making many requests:

``` r

options(ccldr.delay = 1)
```

Representative output:

``` text
#> ccldr.delay
#>           1
```

## Drill into a facility

After a license is verified, fetch the full record only when you need
fields that are not present in the slim verification output.

``` r

facility <- ccld_facility("13423996")

facility |>
  transmute(
    facility_number,
    facility_name,
    status,
    date_closed,
    capacity,
    visits_total,
    visits_complaints,
    last_visit_date
  )
```

Representative output:

``` text
#> # A tibble: 1 x 8
#>   facility_number facility_name       status   date_closed capacity visits_total visits_complaints last_visit_date
#>   <chr>           <chr>               <chr>    <date>         <int>        <int>             <int> <date>
#> 1 013423996       JOHNSON III, JOHNNY Licensed NA                14            1                 0 2024-11-04
```

`capacity` and `date_closed` come from the facility detail endpoint and
are also included in
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
output for site-list audits.

Reports and complaints are list-columns. Unnest the piece you need.

``` r

facility |>
  select(facility_number, reports) |>
  tidyr::unnest(reports)

facility |>
  select(facility_number, complaints) |>
  tidyr::unnest(complaints)
```

Representative output:

``` text
#> # Reports
#> # A tibble: 1 x 5
#>   facility_number report_date report_title report_type control_number
#>   <chr>           <date>      <chr>        <chr>       <chr>
#> 1 013423996       2024-11-04  Facility...  Other       013423996-001
#>
#> # Complaints
#> # A tibble: 0 x 4
#> # i 4 variables: facility_number <chr>, complaint_date <date>,
#> #   allegation <chr>, outcome <chr>
```

## Build Alameda snapshots

[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
walks Alameda cities one by one because the API caps search responses at
250 records. The result uses the same slim 14-column schema as
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md),
which makes it easy to bind or compare outputs.

``` r

types <- c(
  "large_fccs",
  "infant_centers",
  "school_age_centers",
  "preschools",
  "single_licensed_centers"
)

snapshots <- lapply(types, ccld_alameda)
names(snapshots) <- types

all_facilities <- dplyr::bind_rows(snapshots, .id = "snapshot_type")
```

Representative output:

``` text
#> # A tibble: 3 x 6
#>   snapshot_type facility_number facility_name          status   city    zip
#>   <chr>         <chr>           <chr>                  <chr>    <chr>   <chr>
#> 1 preschools    013423751       WILD CHILD SCHOOLHOUSE Licensed Oakland 94611
#> 2 preschools    013423056       AGAPE LEARNING CENTER  Licensed Oakland 94621
#> 3 large_fccs    013423996       JOHNSON III, JOHNNY    Licensed Oakland 94602
```

If a city hits the 250-result cap,
[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
warns that the snapshot may be incomplete. Treat that warning as a cue
to supplement with the CKAN snapshot or a narrower workflow.

## Append Census geographies

Facility outputs include street address fields, so they can be enriched
with coordinates and Census geography identifiers. The Census Geocoder
route used by
[`ccld_add_census_geographies()`](https://chekos.github.io/ccldr/reference/ccld_add_census_geographies.md)
does not require an API key.

``` r

all_facilities_geo <- all_facilities |>
  ccld_add_census_geographies()

all_facilities_geo |>
  select(
    facility_number,
    geocode_status,
    latitude,
    longitude,
    census_tract_geoid,
    census_block_group_geoid,
    zcta_geoid,
    unified_school_district_name
  )
```

Representative output:

``` text
#> # A tibble: 3 x 8
#>   facility_number geocode_status latitude longitude census_tract_geoid census_block_group_geoid zcta_geoid unified_school_district_name
#>   <chr>           <chr>             <dbl>     <dbl> <chr>              <chr>                    <chr>      <chr>
#> 1 013423751       geocoded           37.8     -122. 06001401100        060014011001             94611      Oakland Unified School District
#> 2 013423056       geocoded           37.7     -122. 06001409400        060014094002             94621      Oakland Unified School District
#> 3 013423996       not_geocoded       NA         NA  <NA>               <NA>                     <NA>       <NA>
```

Rows without usable street addresses are kept with
`geocode_status = "not_geocoded"`. Addresses that the Census Geocoder
cannot match are kept with `geocode_status = "unmatched"`, which makes
follow-up review straightforward after a join or export.

## Make scripts easier to debug

Turn on request logging when you need to see which API paths are being
called.

``` r

options(ccldr.verbose = TRUE)
```

Representative output:

``` text
#> ccldr.verbose
#>           TRUE
```

Inspect cache contents when a result looks older than expected.

``` r

ccld_cache_info() |>
  arrange(desc(age_seconds))
```

Representative output:

``` text
#> # A tibble: 3 x 4
#>   key                                      size_bytes modified            age_seconds
#>   <chr>                                         <dbl> <dttm>                    <dbl>
#> 1 FacilityDetail/013423996.qs                    2134 2026-05-20 09:12:43        812
#> 2 FacilitySearch?facType=850&city=Oakland.qs    45210 2026-05-20 09:10:02        973
#> 3 CensusGeocoder/013423751.qs                    5821 2026-05-20 09:09:18       1017
```
