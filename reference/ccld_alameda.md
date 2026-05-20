# Live Alameda snapshot for a child-care facility type

Pulls the current set of Alameda County child-care facilities of the
given type from the live CCLD Transparency API. Internally, the function
walks the 17 Alameda cities to work around the API's 250-result per-call
cap, unions the rows, and deduplicates by `facility_number`.

## Usage

``` r
ccld_alameda(type, cache = TRUE)
```

## Arguments

- type:

  One of `"large_fccs"`, `"infant_centers"`, `"school_age_centers"`,
  `"preschools"`, or `"single_licensed_centers"`. Partial matching via
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html) is supported.

- cache:

  Logical value (default `TRUE`) controlling whether the on-disk
  response cache is used.

## Value

A 14-column slim tibble, matching
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md).
Search responses do not include capacity or closure dates, so `capacity`
and `date_closed` are `NA`.

## Details

Two facility types are deliberately unsupported: `"small_fccs"` because
the API blocks `facType = 0` searches, and `"centers"` because the API's
`facType = 845` bucket only contains a few legacy records statewide. For
the center workflow, use `"preschools"` (`facType = 850`).

If any city query reports 250 or more results, `ccld_alameda()` warns
that the API cap may have hidden additional facilities. The returned
rows are deduplicated by `facility_number`.

## See also

[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
for the shared slim return schema.

## Examples

``` r
if (FALSE) { # \dontrun{
ccld_alameda("preschools")
ccld_alameda("large_fccs")
} # }
```
