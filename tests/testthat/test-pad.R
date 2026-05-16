test_that("ccld_pad pads 8-digit char to 9", {
  expect_equal(ccld_pad("13423996"), "013423996")
})

test_that("ccld_pad accepts numeric input", {
  expect_equal(ccld_pad(13423996), "013423996")
})

test_that("ccld_pad is vectorized", {
  expect_equal(
    ccld_pad(c("13423996", "15700561")),
    c("013423996", "015700561")
  )
})

test_that("ccld_pad leaves already-9-digit input untouched", {
  expect_equal(ccld_pad("013423996"), "013423996")
})

test_that("ccld_pad returns NA for NA input", {
  expect_equal(ccld_pad(NA), NA_character_)
  expect_equal(ccld_pad(c("13423996", NA)), c("013423996", NA_character_))
})

test_that("ccld_pad errors on non-numeric strings", {
  expect_error(ccld_pad("not-a-number"), class = "ccldr_invalid_input")
})

test_that("ccld_pad errors on inputs > 9 digits", {
  expect_error(ccld_pad("0123456789"), class = "ccldr_invalid_input")
})
