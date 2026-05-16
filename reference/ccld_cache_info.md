# Inspect cached CCLD API responses

Returns one row per cached response. Cache entries older than
`getOption("ccldr.cache_ttl_seconds")` are ignored by API helpers, but
they can still appear here until the cache is cleared.

## Usage

``` r
ccld_cache_info()
```

## Value

A tibble with one row per cached response and columns `key`,
`age_seconds`, and `size_bytes`.

## See also

Other cache management:
[`ccld_cache_clear()`](https://chekos.github.io/ccldr/reference/ccld_cache_clear.md)

## Examples

``` r
ccld_cache_info()
#> # A tibble: 0 × 3
#> # ℹ 3 variables: key <chr>, age_seconds <dbl>, size_bytes <dbl>
```
