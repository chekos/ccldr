# Package index

## License helpers

Validate, normalize, and verify CCLD facility license numbers.

- [`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md) :
  Pad facility license numbers to the API's canonical 9-digit form
- [`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
  : Verify CCLD facility license numbers in bulk

## Facility detail

Pull detailed fields, visits, reports, and complaints for one or many
facilities.

- [`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
  : Pull the full CCLD facility detail for one license
- [`ccld_facilities()`](https://chekos.github.io/ccldr/reference/ccld_facilities.md)
  : Pull full CCLD facility detail for many licenses

## Alameda snapshots

Fetch current Alameda County child-care facility snapshots by facility
type.

- [`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
  : Live Alameda snapshot for a child-care facility type

## Geography helpers

Geocode facility rows and append Census geography identifiers.

- [`ccld_add_census_geographies()`](https://chekos.github.io/ccldr/reference/ccld_add_census_geographies.md)
  : Add Census geographies to CCLD facility rows

## Cache management

Inspect and clear cached API responses.

- [`ccld_cache_info()`](https://chekos.github.io/ccldr/reference/ccld_cache_info.md)
  : Inspect cached API responses
- [`ccld_cache_clear()`](https://chekos.github.io/ccldr/reference/ccld_cache_clear.md)
  : Clear cached API responses
