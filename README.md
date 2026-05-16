# ccldr

An R client for the [CCLD Transparency API](https://www.ccld.dss.ca.gov/carefacilitysearch/). Verify license numbers, pull facility detail, snapshot Alameda — all from inside your R script.

## Installation

```r
remotes::install_github("chekos/ccldr")
```

## Quickstart

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

# 3. Live Alameda snapshot
ccld_alameda("preschools")
```

See `vignette("getting-started")` for a longer walkthrough and [`docs/design.md`](docs/design.md) for the design.

## Related

- [`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot) — bulk CKAN snapshot of Alameda CCLD data and the Python `verify.py` companion. This package is the live, per-facility-detail layer.
