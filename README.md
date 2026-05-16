<img class="ccldr-readme-logo" src="man/figures/logo.png" align="right" alt="ccldr logo" width="160" />

# ccldr

<!-- badges: start -->
[![R-CMD-check](https://github.com/chekos/ccldr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chekos/ccldr/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/chekos/ccldr/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/chekos/ccldr/actions/workflows/pkgdown.yaml)
<!-- badges: end -->

`ccldr` is a small R client for the [California Community Care Licensing Division (CCLD) Transparency API](https://www.ccld.dss.ca.gov/carefacilitysearch/).

Use it when you need to:

- verify CCLD child-care facility license numbers from an R script;
- fetch the full detail record for a single facility;
- pull a live Alameda County child-care facility snapshot by facility type.

The package returns tibbles, keeps unknown licenses in your output, and caches API responses on disk so repeated development runs are gentler on the upstream service.

## Installation

```r
# install.packages("pak")
pak::pak("chekos/ccldr")
```

You can also install with `remotes`:

```r
remotes::install_github("chekos/ccldr")
```

## Quickstart

```r
library(ccldr)
library(dplyr)
library(readr)

# CCLD's API expects canonical 9-digit facility numbers.
ccld_pad(c("13423996", "15700561"))

# Verify a column of license numbers without dropping unknown inputs.
rr <- read_csv("rr_sites_2026.csv")

verified <- ccld_verify(rr$license_number)

rr |>
  left_join(verified, by = c("license_number" = "input")) |>
  select(site_name, license_number, found, facility_name, status)
```

Pull one full facility record when you need visits, complaint counts, reports, or itemized complaints:

```r
facility <- ccld_facility("13423996")

facility |>
  select(facility_name, status, capacity, last_visit_date)

facility |>
  tidyr::unnest(reports)
```

Build a current Alameda snapshot for a supported child-care facility type:

```r
preschools <- ccld_alameda("preschools")
large_fccs <- ccld_alameda("large_fccs")
```

Supported Alameda types are `"large_fccs"`, `"infant_centers"`, `"school_age_centers"`, `"preschools"`, and `"single_licensed_centers"`.

## Live API behavior

`ccldr` talks to an undocumented public API. For reproducible scripts, keep these habits in mind:

- Use `cache = FALSE` when you need a fresh API response for a single call.
- Use `ccld_cache_clear()` before rerunning a full workflow from scratch.
- Use `options(ccldr.verbose = TRUE)` to print request paths while debugging.
- Use `options(ccldr.delay = 1)` to slow down batch requests.

`ccld_alameda()` walks the 17 Alameda cities to avoid the API's 250-result response cap. If any city still hits that cap, the function warns that the snapshot may be incomplete.

## Documentation

- Get started: `vignette("ccldr")`
- Reference site: <https://chekos.github.io/ccldr/>
- Live workflow guide: <https://chekos.github.io/ccldr/articles/live-api-workflows.html>
- Troubleshooting and FAQ: <https://chekos.github.io/ccldr/articles/troubleshooting.html>
- Design notes: [`docs/design.md`](docs/design.md)

## Related

- [`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot) provides bulk CKAN snapshots of Alameda CCLD data and the Python `verify.py` companion. `ccldr` is the live, per-facility-detail R layer.
