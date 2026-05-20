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

Documentation is not complete when it only shows code. If a snippet returns a
table, vector, warning, error, file list, or plot, show representative output in
the page next to the snippet. For live API examples, keep the code
non-evaluated and add a static `text` output block or image preview so readers
can understand the result shape without running the code themselves.

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
