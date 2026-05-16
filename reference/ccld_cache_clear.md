# Clear cached CCLD API responses

Removes every cached response from the on-disk `ccldr` cache. This is
useful before a reproducibility run or when you want to force subsequent
calls to re-query the live CCLD Transparency API.

## Usage

``` r
ccld_cache_clear()
```

## Value

Invisibly, the number of cache files removed.

## See also

Other cache management:
[`ccld_cache_info()`](https://chekos.github.io/ccldr/reference/ccld_cache_info.md)

## Examples

``` r
ccld_cache_clear()
```
