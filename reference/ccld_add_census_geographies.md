# Add Census geographies to CCLD facility rows

Geocodes facility address columns with the U.S. Census Geocoder and
appends Census geography identifiers, including tract, block, block
group, ZCTA, place, county subdivision, urban area, legislative
districts, and school district fields when the geocoder returns them.

## Usage

``` r
ccld_add_census_geographies(
  data,
  address_col = "street_address",
  city_col = "city",
  state_col = NULL,
  zip_col = "zip",
  default_state = "CA",
  benchmark = "Public_AR_Current",
  vintage = "Current_Current",
  layers = "all",
  cache = TRUE
)
```

## Arguments

- data:

  A data frame containing facility address columns.

- address_col:

  Name of the street address column. Defaults to `"street_address"`.

- city_col:

  Name of the city column. Defaults to `"city"`.

- state_col:

  Optional name of the state column. When `NULL`, missing, or blank,
  `default_state` is used.

- zip_col:

  Name of the ZIP code column. Defaults to `"zip"`.

- default_state:

  State abbreviation used when `state_col` is absent or blank. Defaults
  to `"CA"`.

- benchmark:

  Census Geocoder benchmark. Defaults to `"Public_AR_Current"`.

- vintage:

  Census Geocoder vintage. Defaults to `"Current_Current"`.

- layers:

  Census geography layers to request. Defaults to `"all"` so ZCTA and
  school district layers are included when available.

- cache:

  Logical value (default `TRUE`) controlling whether the on-disk
  response cache is used.

## Value

A tibble containing the input columns plus Census geocoding and
geography columns.

## Details

`ccld_add_census_geographies()` works with rows returned by
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md),
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md),
and
[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md).
Inputs are returned in the same order, and unmatched or ungeocodable
rows are kept with `geocode_status = "unmatched"` or `"not_geocoded"`.

The Census Geocoder does not require an API key. Results are cached in
the package cache using the same cache controls as the CCLD API helpers.

## Examples

``` r
if (FALSE) { # \dontrun{
ccld_alameda("preschools") |>
  ccld_add_census_geographies()
} # }
```
