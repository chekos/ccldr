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

Use a longer delay if you are making many requests:

``` r

options(ccldr.delay = 1)
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

`date_closed` comes from the facility detail endpoint and is also
included in
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

## Build Alameda snapshots

[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
walks Alameda cities one by one because the API caps search responses at
250 records. The result uses the same slim 13-column schema as
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

Inspect cache contents when a result looks older than expected.

``` r

ccld_cache_info() |>
  arrange(desc(age_seconds))
```
