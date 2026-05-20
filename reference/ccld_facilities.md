# Pull full CCLD facility detail for many licenses

`ccld_facilities()` is the bulk full-detail companion to
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md).
It calls the one-facility CCLD detail endpoints for each unique license,
then expands results back to the original input order. Unknown or
invalid licenses are kept as `found = FALSE` rows with missing scalar
fields and empty `reports` and `complaints` list-columns.

## Usage

``` r
ccld_facilities(facnums, cache = TRUE)
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

A tibble with one row per input, a `found` column, scalar facility
detail fields, and list-columns `reports` and `complaints`.

## Details

Use
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
when you only need the slim verification schema. Use `ccld_facilities()`
when you need full detail for a whole column of facilities, including
visit counts, reports, and itemized complaints.

## See also

[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
for the scalar full-detail helper and
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
for slim bulk verification.

Other facility detail:
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ccld_facilities(c("13423996", "99999999"))
} # }
```
