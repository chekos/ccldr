# Pull full CCLD facility detail for many licenses

`ccld_facilities()` is the bulk full-detail companion to
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md).
It calls the one-facility CCLD detail endpoints for each unique license,
then expands results back to the original input order. Unknown or
invalid licenses are kept as `found = FALSE` rows with missing scalar
fields and empty `reports` and `complaints` list-columns.

## Usage

``` r
ccld_facilities(facnums, cache = TRUE)
```

## Arguments

- facnums:

  Character or numeric vector of facility license numbers. Accepts 8- or
  9-digit forms; padded internally via
  [`ccld_pad()`](https://chekos.github.io/ccldr/reference/ccld_pad.md).

- cache:

  Logical value (default `TRUE`) controlling whether the on-disk
  response cache is used.

## Value

A tibble with one row per input, a `found` column, scalar facility
detail fields, and list-columns `reports` and `complaints`.

## Details

Use
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
when you only need the slim verification schema. Use `ccld_facilities()`
when you need full detail for a whole column of facilities, including
visit counts, reports, and itemized complaints.

Available top-level columns are: `input`, `facility_number`, `found`,
`facility_name`, `facility_type`, `status`, `licensee_name`, `contact`,
`street_address`, `city`, `state`, `zip`, `county`, `telephone`,
`capacity`, `client_served_1`, `client_served_2`, `client_served_3`,
`client_served_4`, `client_served_5`, `client_served_6`, `comments`,
`comments_2`, `license_effective_date`, `license_first_date`,
`date_closed`, `last_visit_date`, `visits_total`, `visits_complaints`,
`visits_inspections`, `visits_other`, `cmplt_type_a`, `cmplt_type_b`,
`cmplt_substantiated`, `cmplt_unsubstantiated`, `cmplt_inconclusive`,
`cmplt_unfounded`, `insp_type_a`, `insp_type_b`, `other_type_a`,
`other_type_b`, `visit_date_all`, `visit_date_complaint`,
`visit_date_inspection`, `visit_date_other`, `district_office`,
`district_office_address`, `district_office_city`,
`district_office_state`, `district_office_zip`, `district_office_phone`,
`complaint_count`, `total_complaint_visits`,
`total_substantiated_allegations`, `total_inconclusive_allegations`,
`total_unsubstantiated_allegations`, `total_unfounded_allegations`,
`total_type_a`, `total_type_b`, `reports`, and `complaints`.

The `reports` list-column contains tibbles with `report_date`,
`report_title`, `report_type`, `report_page`, and `control_number`. The
`complaints` list-column contains tibbles with `complaint_date`,
`allegation`, and `outcome`.

## See also

[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)
for the scalar full-detail helper and
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
for slim bulk verification.

Other facility detail:
[`ccld_facility()`](https://chekos.github.io/ccldr/reference/ccld_facility.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ccld_facilities(c("13423996", "99999999"))
} # }
```
