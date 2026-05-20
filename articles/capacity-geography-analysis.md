# Capacity by geography

Use this workflow when you want a small analytical report from live CCLD
data: where licensed capacity is concentrated, how that varies by city
or Census geography, and which closed records should be separated from
current supply.

The examples are not evaluated during site builds because they call the
live CCLD Transparency API and the Census Geocoder.

The printed tables and chart previews below are representative outputs.
Your counts will change as CCLD records, closure dates, and geocoding
matches change.

## Build an analysis file

Start with one Alameda snapshot, then enrich it with the fields that
only come from the facility detail endpoint. This example uses
preschools, but the same pattern works for the other supported
[`ccld_alameda()`](https://chekos.github.io/ccldr/reference/ccld_alameda.md)
facility types.

``` r

library(ccldr)
library(dplyr)
library(ggplot2)

preschools <- ccld_alameda("preschools")

verified <- ccld_verify(preschools$facility_number) |>
  select(
    facility_number,
    verified_found = found,
    verified_status = status,
    verified_city = city,
    capacity,
    date_closed,
    license_effective_date,
    last_visit_date
  )

preschools_detail <- preschools |>
  select(-capacity, -date_closed, -license_effective_date, -last_visit_date) |>
  left_join(verified, by = "facility_number") |>
  mutate(
    found = coalesce(verified_found, found),
    status = coalesce(verified_status, status),
    city = coalesce(city, verified_city),
    is_closed = !is.na(date_closed) |
      grepl("^Closed", status, ignore.case = TRUE),
    is_open = found & !is_closed & !is.na(capacity)
  ) |>
  select(-verified_found, -verified_status, -verified_city)
```

The Alameda search endpoint is useful for finding records, but it does
not return `capacity` or `date_closed`. Calling
[`ccld_verify()`](https://chekos.github.io/ccldr/reference/ccld_verify.md)
for the facility numbers fills those fields from `FacilityDetail`.

Representative output:

``` text
#> # A tibble: 3 x 9
#>   facility_number facility_name          city    status   capacity date_closed is_open last_visit_date found
#>   <chr>           <chr>                  <chr>   <chr>       <int> <date>      <lgl>   <date>          <lgl>
#> 1 013423751       WILD CHILD SCHOOLHOUSE Oakland Licensed       24 NA          TRUE    2024-09-17      TRUE
#> 2 013423056       AGAPE LEARNING CENTER  Oakland Licensed       60 NA          TRUE    2024-11-06      TRUE
#> 3 013422467       COLIBRI PRESCHOOL      Oakland Licensed       42 NA          TRUE    2025-02-11      TRUE
```

## Add Census geographies

Append coordinates and geography identifiers before summarizing. Keep
unmatched geocodes in the analysis table so missing addresses remain
visible.

``` r

preschools_geo <- preschools_detail |>
  ccld_add_census_geographies()

preschools_geo |>
  count(geocode_status, sort = TRUE)
```

Representative output:

``` text
#> # A tibble: 3 x 2
#>   geocode_status     n
#>   <chr>          <int>
#> 1 geocoded         352
#> 2 not_geocoded      18
#> 3 unmatched          7
```

For a city-only report, you can skip the geocoding step and use
`preschools_detail` directly. For ZCTA, tract, block group, school
district, or legislative district summaries, use the geocoded table.

## Capacity by city

Treat open facilities as current supply. Closed facilities are still
valuable for audits, but mixing them into current capacity totals will
overstate supply.

``` r

open_preschools <- preschools_geo |>
  filter(is_open)

city_capacity <- open_preschools |>
  group_by(city) |>
  summarise(
    facilities = n(),
    total_capacity = sum(capacity),
    median_capacity = median(capacity),
    capacity_per_facility = total_capacity / facilities,
    .groups = "drop"
  ) |>
  arrange(desc(total_capacity))

city_capacity
```

Representative output:

``` text
#> # A tibble: 5 x 5
#>   city     facilities total_capacity median_capacity capacity_per_facility
#>   <chr>         <int>          <int>           <dbl>                 <dbl>
#> 1 Oakland          64           3080              45                  48.1
#> 2 Fremont          38           1930              48                  50.8
#> 3 Hayward          31           1520              44                  49.0
#> 4 Berkeley         22           1190              50                  54.1
#> 5 Alameda          18            965              48                  53.6
```

``` r

ggplot(city_capacity, aes(x = reorder(city, total_capacity), y = total_capacity)) +
  geom_col(fill = "#2b8cbe") +
  coord_flip() +
  labs(
    title = "Total licensed preschool capacity by city",
    subtitle = "Open facilities only",
    x = NULL,
    y = "Licensed capacity"
  ) +
  theme_minimal()
```

Representative chart:

![Horizontal bar chart of total licensed preschool capacity by
city.](figures/capacity-city-bars.svg)

Horizontal bar chart of total licensed preschool capacity by city.

Look at both total capacity and facility count. A city can have a high
total because it has many small sites, a few large sites, or both.

``` r

ggplot(city_capacity, aes(x = facilities, y = total_capacity)) +
  geom_point(aes(size = median_capacity), alpha = 0.7, color = "#225ea8") +
  geom_text(aes(label = city), check_overlap = TRUE, nudge_y = 25, size = 3) +
  scale_size_continuous(name = "Median capacity") +
  labs(
    title = "Facility count and licensed capacity move together, but not perfectly",
    x = "Open facilities",
    y = "Total licensed capacity"
  ) +
  theme_minimal()
```

Representative chart:

![Scatterplot comparing open facility count and total licensed capacity
by city.](figures/capacity-city-scatter.svg)

Scatterplot comparing open facility count and total licensed capacity by
city.

## Capacity by ZCTA

ZCTAs are useful for a first neighborhood-scale scan because they are
familiar to many partners and are returned by the Census Geocoder.

``` r

zcta_capacity <- open_preschools |>
  filter(!is.na(zcta_geoid)) |>
  group_by(zcta_geoid) |>
  summarise(
    facilities = n(),
    total_capacity = sum(capacity),
    median_capacity = median(capacity),
    cities = paste(sort(unique(city)), collapse = ", "),
    .groups = "drop"
  ) |>
  arrange(desc(total_capacity))

zcta_capacity |>
  slice_head(n = 15)
```

Representative output:

``` text
#> # A tibble: 5 x 5
#>   zcta_geoid facilities total_capacity median_capacity cities
#>   <chr>           <int>          <int>           <dbl> <chr>
#> 1 94621              37           1820              42 Oakland
#> 2 94538              28           1480              54 Fremont
#> 3 94606              25           1290              45 Oakland
#> 4 94704              18           1020              58 Berkeley
#> 5 94544              19            920              46 Hayward
```

``` r

zcta_capacity |>
  slice_max(total_capacity, n = 15) |>
  ggplot(aes(x = reorder(zcta_geoid, total_capacity), y = total_capacity)) +
  geom_col(fill = "#756bb1") +
  coord_flip() +
  labs(
    title = "Highest-capacity ZCTAs",
    subtitle = "Open preschool records with matched Census geographies",
    x = "ZCTA",
    y = "Licensed capacity"
  ) +
  theme_minimal()
```

Representative chart:

![Horizontal bar chart of highest-capacity
ZCTAs.](figures/capacity-zcta-bars.svg)

Horizontal bar chart of highest-capacity ZCTAs.

Capacity totals are not access rates. To turn this into an access
analysis, join child population, poverty, language, or other denominator
data to the same ZCTA or tract identifiers.

## Capacity by tract

Census tracts give a finer-grained view than ZCTAs. Use them to find
local clusters, then inspect the underlying facilities before drawing
conclusions.

``` r

tract_capacity <- open_preschools |>
  filter(!is.na(census_tract_geoid)) |>
  group_by(census_tract_geoid) |>
  summarise(
    facilities = n(),
    total_capacity = sum(capacity),
    median_capacity = median(capacity),
    cities = paste(sort(unique(city)), collapse = ", "),
    .groups = "drop"
  ) |>
  arrange(desc(total_capacity))

tract_capacity |>
  slice_head(n = 20)
```

Representative output:

``` text
#> # A tibble: 5 x 5
#>   census_tract_geoid facilities total_capacity median_capacity cities
#>   <chr>                   <int>          <int>           <dbl> <chr>
#> 1 06001409400                12            690              55 Oakland
#> 2 06001401100                10            575              48 Oakland
#> 3 06001433300                 9            500              54 Fremont
#> 4 06001442000                 8            420              45 Hayward
#> 5 06001450800                 7            352              42 Alameda
```

``` r

tract_capacity |>
  slice_max(total_capacity, n = 20) |>
  ggplot(aes(x = reorder(census_tract_geoid, total_capacity), y = total_capacity)) +
  geom_col(fill = "#31a354") +
  coord_flip() +
  labs(
    title = "Highest-capacity Census tracts",
    x = "Census tract GEOID",
    y = "Licensed capacity"
  ) +
  theme_minimal()
```

Representative chart:

![Horizontal bar chart of highest-capacity Census
tracts.](figures/capacity-tract-bars.svg)

Horizontal bar chart of highest-capacity Census tracts.

## Closed records

Use `date_closed` to keep closed records out of current-supply charts
and to summarize recently closed capacity for a separate audit. Treat
closed capacity as the facility’s recorded licensed capacity, not as a
confirmed seat-loss measure for any particular program year.

``` r

closed_capacity <- preschools_geo |>
  filter(is_closed, !is.na(date_closed)) |>
  mutate(closed_year = as.integer(format(date_closed, "%Y"))) |>
  group_by(city, closed_year) |>
  summarise(
    closed_facilities = n(),
    closed_capacity = sum(capacity, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(desc(closed_year), desc(closed_capacity))

closed_capacity
```

Representative output:

``` text
#> # A tibble: 6 x 4
#>   city     closed_year closed_facilities closed_capacity
#>   <chr>          <int>             <int>           <int>
#> 1 Oakland         2026                 3             120
#> 2 Fremont         2026                 2              90
#> 3 Hayward         2025                 2              72
#> 4 Berkeley        2025                 1              45
#> 5 Oakland         2024                 2              64
#> 6 Alameda         2024                 1              36
```

``` r

ggplot(closed_capacity, aes(x = closed_year, y = closed_capacity, group = city)) +
  geom_line(color = "#636363") +
  geom_point(color = "#de2d26") +
  facet_wrap(vars(city)) +
  labs(
    title = "Closed capacity records by city and year",
    x = "Closure year",
    y = "Recorded capacity on closed facilities"
  ) +
  theme_minimal()
```

Representative chart:

![Small-multiple line chart of closed capacity records by city and
year.](figures/capacity-closed-lines.svg)

Small-multiple line chart of closed capacity records by city and year.

## Export report tables

Save both summary tables and row-level records. The summaries are useful
for reporting; the row-level table is what you need when a city, ZCTA,
or tract looks surprising.

``` r

readr::write_csv(city_capacity, "capacity_by_city.csv")
readr::write_csv(zcta_capacity, "capacity_by_zcta.csv")
readr::write_csv(tract_capacity, "capacity_by_tract.csv")
readr::write_csv(preschools_geo, "capacity_analysis_rows.csv")
```

Representative output:

``` text
#> Wrote capacity_by_city.csv
#> Wrote capacity_by_zcta.csv
#> Wrote capacity_by_tract.csv
#> Wrote capacity_analysis_rows.csv
```
