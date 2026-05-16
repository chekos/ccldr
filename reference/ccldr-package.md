# ccldr: R client for the CCLD Transparency API

Verify facility license numbers, pull rich per-facility detail, and
snapshot Alameda child-care facilities from the California Community
Care Licensing Division's undocumented Transparency API.

## Package options

- `ccldr.delay`:

  Seconds between requests in batch mode. Default `0.5`.

- `ccldr.cache_ttl_seconds`:

  Cache TTL in seconds. Default `86400` (24 hours).

- `ccldr.verbose`:

  If `TRUE`, log one line per HTTP request. Default `FALSE`.

## See also

- [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  to verify many license numbers.

- [`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
  to fetch full detail for one license.

- [`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
  to build live Alameda facility snapshots.

## Author

**Maintainer**: Sergio Sanchez <sergio.sanchez@first5alameda.org>

Authors:

- Sergio Sanchez <sergio.sanchez@first5alameda.org>
