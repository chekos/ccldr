# ccldr 0.2.0

* Added a pkgdown documentation site configuration, GitHub Pages publishing
  workflow, expanded README, package vignette, website-only workflow articles,
  and contributor documentation.

* `ccld_alameda(type)` adds live Alameda snapshots per facility type, walking
  the 17 Alameda cities under the hood to work around the API's 250-result
  per-call cap.

# ccldr 0.1.0

Initial release.

* `ccld_verify()` bulk-verifies CCLD license numbers and returns a 12-column
  tibble keyed on `facility_number`.
* `ccld_facility()` returns full per-facility detail plus nested `reports` and
  `complaints` list-columns.
* `ccld_pad()` pads license numbers to the API's canonical 9-digit form.
* `ccld_cache_clear()` and `ccld_cache_info()` inspect and manage the on-disk
  response cache.
