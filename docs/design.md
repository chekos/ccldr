# ccldr — Design Spec

R package wrapping the [CCLD Transparency API](https://github.com/chekos/ccld-open-data-snapshot/blob/main/docs/transparency-api.md). Built for the First 5 Alameda data team to verify license numbers, pull facility detail, and pull live Alameda snapshots from inside their existing R scripts.

> Status: design approved 2026-05-15. Implementation plan pending. See the brainstorm history in the F5 work vault.

## Why this exists

The data team already reconciles R&R intake against the canonical CDSS record by hand — opening <https://www.ccld.dss.ca.gov/carefacilitysearch/> in a browser, typing in license numbers, copying details into a spreadsheet. The May 2026 R&R reconciliation surfaced an undocumented JSON API that makes the same lookup a one-line function call. This package brings that capability into the team's existing tidyverse scripts so they can stop tabbing to a browser.

Bulk-inventory queries already have a home in [`chekos/ccld-open-data-snapshot`](https://github.com/chekos/ccld-open-data-snapshot) (CKAN scraper, refreshed every 2 days). This package is the **live, per-facility detail** layer. The two complement each other; the package documentation tells users which to reach for.

## Audience

- **Primary:** Jill Berkin (F5 data team) — tidyverse-native (dplyr, readr, magrittr `%>%`), works in flat `.R` scripts with `setwd()`, joins by license number constantly.
- **Secondary:** the rest of the F5 data team, expected to share the same style.
- **Not audience:** Python users — they have [`verify.py`](https://github.com/chekos/ccld-open-data-snapshot/blob/main/verify.py) in the sibling repo.

## Public API

Four exported functions, all prefixed `ccld_`. Idiomatic R: snake_case, `match.arg()` enums for type parameters, tibble returns throughout.

### `ccld_verify(facnums, ...)`

Bulk-verify a vector of license numbers. The 95% use case.

Accepts character or numeric input, with or without leading zeros. Pads internally. Unknown licenses do not drop — they return a row with `found = FALSE` and NAs in the data columns, so `nrow()` and `left_join` invariants hold.

**Return:** tibble, 14 columns:

| Column | Type | Notes |
|--------|------|-------|
| `input` | chr | Whatever the caller passed (numeric coerced to chr) |
| `facility_number` | chr | Canonical 9-digit padded form |
| `found` | lgl | `FALSE` for licenses unknown to the API |
| `facility_name` | chr | |
| `facility_type` | chr | E.g. `FAMILY DAY CARE HOME`, `DAY CARE CENTER` |
| `status` | chr | Granular API taxonomy — see transparency-api.md |
| `licensee_name` | chr | May differ from `facility_name` |
| `capacity` | int | Licensed capacity |
| `street_address` | chr | Free-text from CCLD; sometimes `Unavailable` |
| `city` | chr | |
| `zip` | chr | Stored as character to preserve leading zeros |
| `license_effective_date` | Date | |
| `date_closed` | Date | NA if open or missing |
| `last_visit_date` | Date | NA if never visited |

Including both `input` and `facility_number` makes round-trip joining frictionless in either format.

### `ccld_facility(facnum)`

Single-license rich detail. Returns a one-row tibble with the full 54-field `FacilityDetail` payload, plus list-columns `reports` (from `/FacilityReports/{padded}`) and `complaints` (from `FacilityDetail.COMPLAINTARRAY`). Users `unnest()` to flatten.

Use case: "I'm auditing this specific site closely and want everything CCLD knows."

### `ccld_alameda(type)`

Live Alameda snapshot for a child-care facility type. Single function, `type` argument picks the facility type:

```r
ccld_alameda(type = "centers")          # facType=845, Child Care Center
ccld_alameda(type = "preschools")       # facType=850, Center Preschool
ccld_alameda("infant_centers")          # facType=830 (partial match OK)
```

Accepted values (mapped to the API's `facType`):

| `type =` | `facType` | What it returns |
|----------|-----------|-----------------|
| `"large_fccs"` | 810 | Family Child Care Home (Large) |
| `"infant_centers"` | 830 | Child Care - Infant Center |
| `"school_age_centers"` | 840 | School Age Child Care Center |
| `"preschools"` | 850 | Child Care Center Preschool (the main "center" bucket) |
| `"single_licensed_centers"` | 860 | Single Licensed Child Care Center |

**Input validation:** `match.arg(type, choices)` does the work and supports partial matching. Anything else raises `cli::cli_abort()` with the valid options listed.

**Pagination:** the FacilitySearch endpoint caps at 250 results per call. The function walks the 17 Alameda cities under the hood (each city has well under 250 facilities of any type), unions the results, dedupes by `facility_number`. The caller sees one function call; the package handles the cost (~17 requests + 0.5s delay ≈ 10 seconds, cached after first run). The function emits `cli::cli_warn()` if any single city hits the 250-cap, since that would imply missed rows.

**Filter combinatorics gotcha (codified in the implementation):** the API silently returns 0 results when `city` and `county` filter parameters are populated together. The package uses `city` alone — the 17 ALAMEDA_CITIES are all in Alameda, so no downstream filter is needed.

**Two deliberate absences:**

- `type = "small_fccs"` — the API blocks `facType=0` searches entirely. Routed to the CKAN snapshot (`chekos/ccld-open-data-snapshot/data/homes.csv`).
- `type = "centers"` — `facType=845` ("Child Care Center") has only 4 records statewide in the API; the bulk of what people call "centers" live in `facType=850` (Preschool). Users wanting "Day Care Centers" should pass `"preschools"`; the error message explains.

Return shape matches `ccld_verify()` (same 14 columns).

### `ccld_pad(facnums)`

Trivial helper exposed because users will want to pad license columns before joining to data they got somewhere else. Vectorized, accepts numeric or char.

## Behavior contracts

### Caching

On by default. File-backed using `qs2::qs_save()` for speed, stored in `tools::R_user_dir("ccldr", "cache")`. Keyed by `endpoint + facility_number` (or `endpoint + query-params-hash` for FacilitySearch). Default TTL 24 hours (86400 seconds).

Caller-facing controls:

- `cache = FALSE` parameter on every fetching function — bypass for one call
- `options(ccldr.cache_ttl_seconds = ...)` — global TTL override
- `ccld_cache_clear()` / `ccld_cache_info()` — operate on the on-disk store

### Rate limiting

Fixed 0.5s delay between requests in batch mode (matches the politeness floor used by `verify.py` in the sibling repo). Configurable via `options(ccldr.delay = ...)`. Caching short-circuits delays for already-fetched licenses.

### Errors

- **Unknown license** → row with `found = FALSE` and NAs. No error.
- **Network failure / 5xx** → retry once with backoff, then `cli::cli_abort()` with the failed facility number and HTTP status. Easy to wrap in `tryCatch`.
- **Invalid input** (e.g., non-9-digit-paddable string) → `cli::cli_abort()` with the offending values.
- **API breaking change** (e.g., endpoint moved) → bubble up the raw response in the error message so we have something to debug from.

### Logging

Quiet by default. `options(ccldr.verbose = TRUE)` produces one `cli` line per request. Progress bar via `cli::cli_progress_bar` shown automatically when a batch has more than 10 items.

## Repo structure

Standard R package layout, `usethis::create_package()`-shaped:

```
ccldr/
├── DESCRIPTION              # Package metadata, deps: tibble, httr2, qs2, cli
├── NAMESPACE                # roxygen-generated
├── R/
│   ├── ccld_verify.R        # bulk verifier + slim-tibble shaping
│   ├── ccld_facility.R      # rich-detail fetcher + nested cols
│   ├── ccld_alameda.R       # type-arg dispatcher + ZIP-walk implementation
│   ├── ccld_pad.R           # padding helper
│   ├── cache.R              # qs2-backed cache layer
│   ├── http.R               # httr2 wrapper, retry, rate limit
│   └── ccldr-package.R      # package docs + .onLoad option defaults
├── man/                     # roxygen-generated .Rd files
├── tests/testthat/
│   ├── _snaps/              # snapshot tests
│   ├── fixtures/            # recorded JSON responses
│   ├── test-verify.R
│   ├── test-facility.R
│   └── test-alameda.R
├── vignettes/
│   └── getting-started.Rmd  # the docs entry point Jill reads first
├── .github/workflows/
│   ├── R-CMD-check.yaml     # r-lib/actions standard
│   └── lintr.yaml           # style check
├── docs/
│   └── design.md            # this document
├── README.md
└── LICENSE                  # MIT, matches sibling repo
```

## Distribution

- **Install:** `remotes::install_github("chekos/ccldr")` — no CRAN, no internal mirror, no auth gymnastics.
- **Versioning:** semver, tagged. `0.1.0` is the first working slice (verify + facility); `0.2.0` adds `ccld_alameda()`; `1.0.0` when the data team has shipped two real workflows on it.
- **README quickstart** shows the three workflows: bulk verify + join, single facility audit, Alameda snapshot.
- **Vignette** (`getting-started.Rmd`) walks through one end-to-end use case using a small canned input CSV, so a new analyst can copy-paste and have something working in five minutes.

## Test strategy

- `testthat` for unit tests.
- `httptest2` (or `vcr`) for HTTP record/replay — tests don't hit the live CCLD site.
- Recorded fixtures cover: known FCC, known Center, closed facility (`013423958` — AHMADI MARIAM), unknown license, network timeout simulation.
- `R-CMD-check` runs on push via GitHub Actions across `release` and `devel` R.

## Dependencies

Minimal:

- `tibble` — return type
- `httr2` — HTTP (modern, well-maintained)
- `qs2` — cache serialization (fast; successor to archived `qs` on R 4.6+)
- `cli` — error/progress messages
- `rlang` — `abort()`/`inform()` machinery (transitively via cli, but explicit)

No tidyverse-as-a-whole dep. Users can pipe results into dplyr without the package itself importing dplyr — keeps install footprint small and dependency conflicts unlikely.

## Out of scope

- **Bulk catalog enumeration of Small FCCs** — API blocks it; route to the CKAN snapshot.
- **Reading evaluation report PDFs** — `REPORTPAGE` URLs are CCLD-internal (`fakeout.gov`); nothing the package can do.
- **Probation status** — API hides it (returns `Licensed`); route to CKAN.
- **Scheduled jobs / audit logs** — infrastructure, not a library concern.
- **A write API** — the Transparency API is read-only.
- **Python wrapper** — sibling repo has `verify.py`.

## Use cases the package unlocks

| Workflow | Before | After |
|----------|--------|-------|
| R&R reconciliation | Manual CDSS website search per flagged license | One `ccld_verify(rr$license)` call, joins straight into the discrepancy report |
| AP voucher matching | Trust the AP feed's license # blindly | Sanity-check against CCLD before joining |
| Quarterly Alameda snapshot for D&E | Wait for next CKAN refresh (up to 2 weeks lag) | `ccld_alameda("preschools")` gives current state in ~10 seconds |
| Site-level closure audit | Pull CSV, scan manually | `ccld_facility()` returns visit/complaint counts and last visit date |

## References

- API surface and gotchas: [ccld-open-data-snapshot/docs/transparency-api.md](https://github.com/chekos/ccld-open-data-snapshot/blob/main/docs/transparency-api.md)
- Python sibling: [ccld-open-data-snapshot/verify.py](https://github.com/chekos/ccld-open-data-snapshot/blob/main/verify.py)
