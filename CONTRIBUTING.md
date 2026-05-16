# Contributing to ccldr

Thanks for helping improve `ccldr`.

## Documentation workflow

Function documentation lives in roxygen2 comments above the function source.
After editing roxygen comments, regenerate help files:

```sh
Rscript -e 'roxygen2::roxygenise()'
```

The installed getting-started guide is `vignettes/ccldr.Rmd`. Longer live API
walk-throughs live in `vignettes/articles/` so pkgdown can publish them without
including them in the package bundle.

Examples and vignettes should not require live network access during package
checks. Use non-evaluated chunks or conditional execution for API calls.

## Local checks

Run these before opening a PR:

```sh
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'testthat::test_local(reporter = "summary")'
Rscript -e 'pkgdown::build_site()'
Rscript -e 'devtools::check(error_on = "never")'
```

`pkgdown::build_site()` writes a local preview to `pkgdown-site/`, which is
ignored by git. The public site is built and deployed by GitHub Actions.

## Release notes

User-facing changes should add a bullet to the current section of `NEWS.md`.
