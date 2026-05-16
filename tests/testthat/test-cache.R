test_that("cache_dir creates the user dir if missing", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  path <- ccldr_cache_dir()
  expect_true(dir.exists(path))
  expect_match(path, "ccldr")
})

test_that("cache_get returns NULL when key not present", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  expect_null(cache_get("missing_key"))
})

test_that("cache_set then cache_get round-trips a list", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("hello", list(a = 1, b = "x"))
  expect_equal(cache_get("hello"), list(a = 1, b = "x"))
})

test_that("cache_get returns NULL when entry is stale", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  withr::local_options(ccldr.cache_ttl_seconds = 0)
  cache_set("k", list(a = 1))
  Sys.sleep(0.01)
  expect_null(cache_get("k"))
})

test_that("ccld_cache_clear removes all entries", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("a", 1)
  cache_set("b", 2)
  ccld_cache_clear()
  expect_null(cache_get("a"))
  expect_null(cache_get("b"))
})

test_that("ccld_cache_info returns a tibble with rows for each entry", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  cache_set("a", 1)
  cache_set("b", 2)
  info <- ccld_cache_info()
  expect_s3_class(info, "tbl_df")
  expect_equal(nrow(info), 2)
  expect_true(all(c("key", "age_seconds", "size_bytes") %in% names(info)))
})
