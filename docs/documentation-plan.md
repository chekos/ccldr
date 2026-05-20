# ccldr documentation plan

## Research summary

The practical best setup for `ccldr` is the standard R package documentation stack, tuned for a small API client:

- Keep function help in roxygen2 comments because R Packages recommends co-locating source and help, then generating `man/*.Rd` with roxygen2.
- Use a package-named vignette, `vignette("ccldr")`, as the installed long-form guide. pkgdown recommends naming the intro article after the package so it appears as "Get started".
- Put live API walk-throughs and troubleshooting material in pkgdown website-only articles, because R Packages explicitly recommends articles when examples are painful to ship or execute during package checks, which is common for web API clients.
- Configure `_pkgdown.yml` with a site URL, curated reference groups, curated article navigation, and the source repository. pkgdown and R Packages both call out URL configuration as important for links and external discovery.
- Publish with a pkgdown GitHub Actions workflow to a `gh-pages` branch. pkgdown, usethis, and R Packages recommend `usethis::use_pkgdown_github_pages()` or the equivalent r-lib Actions workflow.

Primary sources used:

- pkgdown introduction: https://pkgdown.r-lib.org/articles/pkgdown.html
- R Packages, function documentation: https://r-pkgs.org/man.html
- R Packages, vignettes and articles: https://r-pkgs.org/vignettes
- R Packages, websites: https://r-pkgs.org/website.html
- roxygen2 markdown support: https://roxygen2.r-lib.org/articles/rd-formatting.html
- usethis pkgdown setup: https://usethis.r-lib.org/reference/use_pkgdown.html
- GitHub Pages custom workflows: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- rOpenSci packaging guide: https://devguide.ropensci.org/pkg_building.html

## Recommended documentation architecture

- `README.md`: entry point for GitHub and pkgdown home page, focused on installation, "what problem does this solve?", and the three core workflows.
- roxygen2 comments in `R/*.R`: authoritative reference docs with clear argument defaults, return schemas, errors, cache behavior, and cross-links.
- `vignettes/ccldr.Rmd`: installed getting-started guide that uses non-evaluated live API examples.
- `vignettes/articles/*.Rmd`: website-only articles for deeper workflows and troubleshooting, excluded from the package bundle.
- `NEWS.md`: release notes rendered by pkgdown.
- `_pkgdown.yml`: site structure, reference grouping, article grouping, navbar links, source URL, and site URL.
- `.github/workflows/pkgdown.yaml`: automated site build on pushes and releases, deployment to `gh-pages`.
- `CONTRIBUTING.md`: developer workflow for documentation, checks, and releases.

## Proposed pkgdown site structure

- Home: README-derived overview, install, quickstart, reliability notes, and links.
- Get started: `vignette("ccldr")`.
- Articles:
  - "Live API workflows": verifying license columns, pulling facility detail, Alameda snapshots, caching.
  - "Troubleshooting and FAQ": bad licenses, unsupported Alameda types, stale cache, API limits, package checks.
- Reference:
  - License helpers: `ccld_pad()`, `ccld_verify()`
  - Facility detail: `ccld_facility()`
  - Alameda snapshots: `ccld_alameda()`
  - Cache management: `ccld_cache_info()`, `ccld_cache_clear()`
- News: rendered from `NEWS.md`.
- Developer: repository, issues, and contributing guide.

## README improvements and quickstart flow

The README should answer four questions quickly:

1. What does `ccldr` do?
2. How do I install it?
3. What are the three most common workflows?
4. What should I know about live API behavior?

The quickstart should move from the safest zero-network helper (`ccld_pad()`) to the core live workflow (`ccld_verify()`), then to full-detail helpers (`ccld_facility()` and `ccld_facilities()`) and `ccld_alameda()`. It should show `cache = FALSE` as an intentional refresh option and link out to the vignette and troubleshooting article.

## Reference documentation standards

- `ccld_pad()`: document accepted input types, vectorization, NA behavior, validation errors, and canonical 9-digit output.
- `ccld_verify()`: document deduped fetching, row preservation, unknown-license behavior, 14-column schema, cache default, and live API side effects.
- `ccld_facility()`: document single-license constraint, not-found error class, scalar fields, `reports` and `complaints` list-columns, and unnesting.
- `ccld_facilities()`: document bulk full-detail fetching, deduped one-site API calls, row preservation, unknown-license behavior, the full selectable column set, nested list-column schemas, and when to prefer `ccld_verify()`.
- `ccld_alameda()`: document accepted types, rejected API buckets, 17-city strategy, 250-result cap warning, deduping, and the slim return schema.
- `ccld_cache_clear()` and `ccld_cache_info()`: document cache location conceptually, return values, TTL option, and safe use during debugging.

All reference pages should use markdown links, `@family` tags, examples that do not hit the live API during checks, and explicit default values in parameter descriptions.

Documentation is not done if it only shows code. Every code snippet that would
produce a visible result should be followed by representative output: a printed
table, vector, warning/error text, file-writing message, or rendered chart
preview. For live API workflows, keep chunks non-evaluated and use static
representative outputs so package checks remain deterministic while readers
still see what the workflow produces.

## Vignette and article plan

- `ccldr.Rmd`: Audience is analysts installing the package or reading local help. Outline: install/load, license number padding, verify a column, inspect one facility, pull an Alameda snapshot, cache behavior, next links.
- `articles/capacity-audits.Rmd`: Audience is analysts comparing local site capacity records against CCLD. Outline: source data shape, verifying licenses, comparing local and CCLD capacity, reviewing mismatches, refreshing cache, reusable helper.
- `articles/capacity-geography-analysis.Rmd`: Audience is analysts preparing a report. Outline: build a current Alameda analysis file, add verified capacity and closure fields, append Census geographies, summarize and plot capacity by city/ZCTA/tract, separate closed records, export report tables.
- `articles/live-api-workflows.Rmd`: Audience is applied data users building recurring scripts. Outline: source data shape, joining verification results, refreshing cache, drilling into facility detail, building Alameda snapshots, reproducibility tips.
- `articles/troubleshooting.Rmd`: Audience is users debugging unexpected results. Outline: unknown licenses, invalid license formats, unsupported Alameda types, API caps, stale cache, HTTP failures, running package checks locally.

## Troubleshooting and FAQ content

FAQ should cover:

- Why a known 8-digit license becomes 9 digits.
- Why `found = FALSE` is returned instead of dropping rows.
- Why `"small_fccs"` and `"centers"` are not supported by `ccld_alameda()`.
- What the 250-result cap warning means.
- How to clear or bypass the cache.
- How to make HTTP behavior more visible with `options(ccldr.verbose = TRUE)`.
- How to slow requests with `options(ccldr.delay = 1)`.

## Developer documentation needs

- Add a short `CONTRIBUTING.md` with the roxygen, testthat, pkgdown, and R CMD check commands.
- Document that vignettes and examples should avoid live network execution during checks.
- Document where website-only articles live and why they are excluded from package builds.
- Add `URL` and `BugReports` fields to `DESCRIPTION` for pkgdown linking and GitHub navigation.

## GitHub Pages and CI/CD publishing plan

- Add `_pkgdown.yml` with `url: https://chekos.github.io/ccldr/` and `destination: pkgdown-site` so the rendered site does not overwrite the repo's tracked `docs/` planning notes.
- Add `.github/workflows/pkgdown.yaml` based on the r-lib pkgdown workflow.
- Build the site on pushes to `main` or `master`, on pull requests, release publication, and manual dispatch.
- Deploy only for non-PR events to `gh-pages`.
- Keep rendered `pkgdown-site/` ignored locally; the canonical public site is generated in CI.

## Repo and package changes for documentation UX/DX

- Add `pkgdown` to `Suggests` because the site is a supported development artifact.
- Add `URL` and `BugReports` to `DESCRIPTION`.
- Update `.Rbuildignore` and `.gitignore` for pkgdown config, generated site output, and website-only articles.
- Update `NEWS.md` with documentation-site improvements.
- Keep custom styling minimal and use pkgdown defaults for accessibility and maintainability.

## Phased implementation plan

1. Configure pkgdown and CI.
2. Rewrite README as the documentation front door.
3. Improve roxygen reference docs and regenerate `man/*.Rd`.
4. Replace the current getting-started vignette with `vignettes/ccldr.Rmd`.
5. Add website-only articles and developer documentation.
6. Build and verify docs locally.
7. Commit, push, and open a draft PR.

## Acceptance criteria

- `docs/documentation-plan.md` exists.
- `_pkgdown.yml` exists and groups reference/articles intentionally.
- `README.md` has installation, quickstart, API behavior, and documentation links.
- Every exported function has updated roxygen documentation.
- `vignettes/ccldr.Rmd` exists.
- Website-only articles exist for live workflows and troubleshooting.
- `CONTRIBUTING.md` exists.
- pkgdown site builds locally.
- Required validation commands run and results are recorded.
- Changes are committed, pushed, and represented in a GitHub PR.
