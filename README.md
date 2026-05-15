# ccldr

An R client for the [CCLD Transparency API](https://www.ccld.dss.ca.gov/carefacilitysearch/). Verify license numbers, pull facility detail, snapshot Alameda — without leaving your R script.

> **Status: design only.** The implementation hasn't started yet — this repo currently holds the design spec at [`docs/design.md`](docs/design.md). When the package is implemented, this README will switch to a quickstart.

## What it will do

```r
library(ccldr)
library(dplyr)
library(readr)

# 1. Verify a column of license numbers
rr <- read_csv("rr_sites_2026.csv")
verified <- ccld_verify(rr$license_number)
rr |> left_join(verified, by = c("license_number" = "input"))

# 2. Pull rich detail for one facility
ccld_facility("13423996")

# 3. Live Alameda snapshot for a facility type
ccld_alameda(type = "centers")
```

See [`docs/design.md`](docs/design.md) for the full API surface, return schemas, behavior contracts, and what's deliberately not in scope.

## Related

- [`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot) — git-scraping snapshot of the CCLD CKAN open data + the Python `verify.py` and the reverse-engineered API reference at `docs/transparency-api.md`. The R package here is the live, per-facility-detail companion to that bulk inventory.
