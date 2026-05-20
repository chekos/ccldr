# Verify CCLD facility license numbers in bulk

Looks up each license number against the live CCLD Transparency API and
returns a tibble with one row per input. Unknown licenses are not
dropped: they appear as rows with `found = FALSE` and `NA`s in the data
columns.

## Usage

``` r
ccld_verify(facnums, cache = TRUE)
```

## Arguments

- facnums:

  Character or numeric vector of facility license numbers. Accepts 8- or
  9-digit forms; padded internally via
  [`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md).

- cache:

  Logical value (default `TRUE`) controlling whether the on-disk
  response cache is used.

## Value

A tibble with 14 columns: `input`, `facility_number`, `found`,
`facility_name`, `facility_type`, `status`, `licensee_name`, `capacity`,
`street_address`, `city`, `zip`, `license_effective_date`,
`date_closed`, `last_visit_date`.

## Details

Inputs are padded with
[`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md)
before requests are made. Duplicate license numbers are fetched once and
then expanded back to the original input order, which keeps joins
predictable and avoids unnecessary API calls.

`ccld_verify()` always returns the slim bulk-verification schema
documented in the return value. It does not have a full-detail mode.
After identifying the facilities that need deeper review, use
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
for one license or
[`ccld_facilities()`](https://chekos.github.io/ccldr/reference/ccld_facilities.md)
for a whole vector to pull the full API detail, including reports and
complaints.

## See also

[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
for full detail on one verified facility and
[`ccld_facilities()`](https://chekos.github.io/ccldr/reference/ccld_facilities.md)
for full detail on many facilities.

Other license helpers:
[`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ccld_verify("13423996")
ccld_verify(c(13423996, 99999999))
} # }
```
