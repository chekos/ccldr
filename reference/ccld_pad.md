# Pad facility license numbers to the API's canonical 9-digit form

The CCLD Transparency API requires every facility number to be
left-padded with leading zeros to exactly 9 digits. CDSS-side data
usually stores the 8-digit form. `ccld_pad()` makes the conversion
explicit and vectorised.

## Usage

``` r
ccld_pad(facnums)
```

## Arguments

- facnums:

  Character or numeric vector of license numbers. Numeric inputs are
  converted without scientific notation before padding.

## Value

Character vector of 9-digit zero-padded license numbers. `NA` inputs
return `NA_character_`.

## Details

`NA` values are preserved. Non-digit inputs and values longer than 9
digits raise a `ccldr_invalid_input` error.

## See also

Other license helpers:
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)

## Examples

``` r
ccld_pad("13423996")
#> [1] "013423996"
ccld_pad(c(13423996, 15700561))
#> [1] "013423996" "015700561"
```
