# Changelog

## ccldr 0.4.0

- Documented the full
  [`ccld_facilities()`](https://chekos.github.io/ccldr/reference/ccld_facilities.md)
  column set, including the nested `reports` and `complaints` schemas,
  so users know which variables they can select after pulling full
  facility detail.

- Added
  [`ccld_facilities()`](https://chekos.github.io/ccldr/reference/ccld_facilities.md)
  to pull full facility detail for a vector of license numbers while
  preserving input rows, duplicate licenses, and unknown licenses.

- Clarified the documented split between the slim bulk-verification
  output from
  [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  and the full single-facility detail from
  [`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md).

- Expanded workflow articles so result-producing examples show
  representative output, and documented that future examples must do the
  same.

- Added a capacity-by-geography analysis article with city, ZCTA, tract,
  and closure-date summaries plus `ggplot2` chart examples.

- Added a capacity audit article showing how to compare local
  licensed-capacity records against
  [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  output.

- [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  now includes `capacity`, parsed from the CCLD `CAPACITY` field, so
  licensed capacity is available in bulk verification output.

- [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  now includes `date_closed`, parsed from the CCLD `DATECLOSED` field,
  so closure audits can run across a vector of license numbers.

## ccldr 0.3.0

- [`ccld_add_census_geographies()`](https://chekos.github.io/ccldr/reference/ccld_add_census_geographies.md)
  adds no-key U.S. Census Geocoder enrichment for facility rows,
  including latitude/longitude, Census tract, block, block group, ZCTA,
  place, county subdivision, urban area, legislative districts, and
  school district fields when available.

- Census Geocoder responses are deduplicated by address and cached on
  disk, matching the package’s existing cache behavior.

## ccldr 0.2.0

- Added a pkgdown documentation site configuration, GitHub Pages
  publishing workflow, expanded README, package vignette, website-only
  workflow articles, and contributor documentation.

- `ccld_alameda(type)` adds live Alameda snapshots per facility type,
  walking the 17 Alameda cities under the hood to work around the API’s
  250-result per-call cap.

## ccldr 0.1.0

Initial release.

- [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  bulk-verifies CCLD license numbers and returns a 12-column tibble
  keyed on `facility_number`.
- [`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
  returns full per-facility detail plus nested `reports` and
  `complaints` list-columns.
- [`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md)
  pads license numbers to the API’s canonical 9-digit form.
- [`ccld_cache_clear()`](https://chekos.github.io/ccldr/reference/ccld_cache_clear.md)
  and
  [`ccld_cache_info()`](https://chekos.github.io/ccldr/reference/ccld_cache_info.md)
  inspect and manage the on-disk response cache.
