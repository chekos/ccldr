# Pull the full CCLD facility detail for one license

Returns the facility detail fields exposed by the Transparency API, plus
nested list-columns for evaluation reports and itemized complaints. Use
[`tidyr::unnest()`](https://tidyr.tidyverse.org/reference/unnest.html)
to flatten either list-column after inspecting the scalar facility
fields.

## Usage

``` r
ccld_facility(facnum, cache = TRUE)
```

## Arguments

- facnum:

  A single facility license number, character or numeric. Accepts 8- or
  9-digit forms; padded internally via
  [`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md).

- cache:

  Logical value (default `TRUE`) controlling whether the on-disk
  response cache is used.

## Value

A one-row tibble with scalar facility fields and list-columns `reports`
and `complaints`.

## Details

`ccld_facility()` is intentionally scalar: pass one facility license
number at a time. Use
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
first when you need to screen a vector of candidate licenses. Unknown
facilities raise a `ccldr_not_found` error.

## See also

[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
to check whether licenses exist before requesting full detail.

Other facility detail:
[`ccld_facilities()`](https://chekos.github.io/ccldr/reference/ccld_facilities.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ccld_facility("13423996")
} # }
```
