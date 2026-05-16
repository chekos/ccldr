# Get started with ccldr

`ccldr` is built for analysts who need California Community Care
Licensing Division (CCLD) facility data in R without leaving their
scripts. It focuses on three workflows:

- verify license numbers;
- fetch full detail for one facility;
- build current Alameda County child-care snapshots.

The examples are not evaluated when the vignette is built because they
call the live CCLD Transparency API.

## Normalize license numbers

The API expects facility numbers in a 9-digit form. Many source files
store the same license as 8 digits, so start by making that conversion
explicit.

``` r

library(ccldr)

ccld_pad(c("13423996", "15700561"))
```

[`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md) is
vectorized, preserves `NA`, and errors on non-digit inputs.

## Verify a column

Use
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
when you have a vector or a data-frame column of possible license
numbers. It returns one row per input, including unknown licenses.

``` r

library(dplyr)
library(readr)

rr <- read_csv("rr_sites.csv")

verified <- ccld_verify(rr$license_number)

rr |>
  left_join(verified, by = c("license_number" = "input")) |>
  select(site_name, license_number, found, facility_name, status)
```

Keeping `found = FALSE` rows in the result makes audits easier: your
original records stay visible instead of disappearing during a join.

## Inspect one facility

Use
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
when you need the full API record for one known license. The result is a
one-row tibble with scalar facility fields and nested list-columns for
reports and complaints.

``` r

facility <- ccld_facility("13423996")

facility |>
  select(facility_name, status, capacity, last_visit_date)

facility |>
  tidyr::unnest(reports)

facility |>
  tidyr::unnest(complaints)
```

[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
is scalar by design. For a column of candidate licenses, run
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
first and request full detail only for the facilities you need.

## Pull an Alameda snapshot

Use
[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
when you need the current set of Alameda County facilities for a
supported child-care type.

``` r

preschools <- ccld_alameda("preschools")
large_fccs <- ccld_alameda("large_fccs")
```

Supported values are:

- `"large_fccs"`
- `"infant_centers"`
- `"school_age_centers"`
- `"preschools"`
- `"single_licensed_centers"`

`"small_fccs"` is not supported because the API blocks that search
route. `"centers"` is not supported because the API bucket is sparse and
legacy; use `"preschools"` for the center workflow.

## Cache behavior

Every API response is cached on disk for 24 hours by default.

``` r

ccld_cache_info()
ccld_cache_clear()
```

For a fresh response in one call, set `cache = FALSE`:

``` r

ccld_verify("13423996", cache = FALSE)
```

For debugging, these options are useful:

``` r

options(ccldr.verbose = TRUE)
options(ccldr.delay = 1)
options(ccldr.cache_ttl_seconds = 3600)
```

Read the website articles for recurring script patterns and
troubleshooting:

- <https://chekos.github.io/ccldr/articles/live-api-workflows.html>
- <https://chekos.github.io/ccldr/articles/troubleshooting.html>
