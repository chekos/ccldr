# Troubleshooting and FAQ

## Why did my license become 9 digits?

CCLD’s Transparency API expects facility numbers in a 9-digit form. Many
public or local data files store the same number as 8 digits.
[`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md)
adds the leading zero so requests use the API’s canonical form.

``` r

ccld_pad("13423996")
```

Representative output:

``` text
#> [1] "013423996"
```

## Why does `ccld_verify()` return `found = FALSE`?

[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
keeps every input row. When the API does not return facility detail for
a license, the row stays in the result with `found = FALSE` and missing
facility fields. This makes failed matches visible after joins.

## Why did `ccld_pad()` error?

License inputs must contain only digits and must be 9 digits or fewer.

``` r

ccld_pad("13423996")
ccld_pad(13423996)
```

Representative output:

``` text
#> [1] "013423996"
#> [1] "013423996"
```

Values such as `"ABC123"` or `"0123456789"` are rejected with a
`ccldr_invalid_input` error.

Representative error:

``` text
#> Error:
#> ! Facility license numbers must contain digits only.
#> x Problem value: "ABC123"
```

## Why are `"small_fccs"` and `"centers"` unsupported?

[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
intentionally supports only API routes that return useful data:

- `"small_fccs"` is blocked by the API route used by the Transparency
  search.
- `"centers"` maps to a sparse legacy API bucket.

For small FCC enumeration, use the CKAN snapshot in
[`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot).
For center workflows, use `"preschools"`.

## What does the 250-result cap warning mean?

The CCLD search endpoint can cap individual responses at 250 records. To
reduce that risk,
[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
queries each Alameda city separately. If a city still reports 250 or
more results, the function warns because additional facilities may be
hidden by the API response cap.

## How do I force fresh data?

Use `cache = FALSE` for one call:

``` r

ccld_verify("13423996", cache = FALSE)
```

Representative output:

``` text
#> # A tibble: 1 x 14
#>   input    facility_number found facility_name       facility_type        status   licensee_name capacity street_address city    zip   license_effective_date date_closed last_visit_date
#>   <chr>    <chr>           <lgl> <chr>               <chr>                <chr>    <chr>            <int> <chr>          <chr>   <chr> <date>                 <date>      <date>
#> 1 13423996 013423996       TRUE  JOHNSON III, JOHNNY FAMILY DAY CARE HOME Licensed JOHNNY...           14 Unavailable    OAKLAND 94602 2024-11-04             NA          2024-11-04
```

Clear the whole cache before a reproducibility run:

``` r

ccld_cache_clear()
```

Representative output:

``` text
#> Cache cleared.
```

Inspect cached responses:

``` r

ccld_cache_info()
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

## How do I see API requests?

Set verbose mode before running a workflow:

``` r

options(ccldr.verbose = TRUE)
```

Representative output:

``` text
#> ccldr.verbose
#>           TRUE
```

Slow down batch requests when running larger jobs:

``` r

options(ccldr.delay = 1)
```

Representative output:

``` text
#> ccldr.delay
#>           1
```

## How should I run documentation checks locally?

Run the same core checks used for this package:

``` r

roxygen2::roxygenise()
testthat::test_local(reporter = "summary")
pkgdown::build_site()
devtools::check(error_on = "never")
```

Representative output:

``` text
#> testthat: DONE
#> pkgdown: Finished building pkgdown site
#> R CMD check: Status: OK
```

If a check fails only while executing live API examples, move that
example into a website-only article or make the chunk conditional.
