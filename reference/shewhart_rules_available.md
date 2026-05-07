# List available runs rules

List available runs rules

## Usage

``` r
shewhart_rules_available()
```

## Value

A tibble with columns `rule` (the key) and `description`.

## Examples

``` r
shewhart_rules_available()
#> # A tibble: 9 × 2
#>   rule                    description                                           
#>   <chr>                   <chr>                                                 
#> 1 nelson_1_beyond_3s      1 point beyond 3 sigma                                
#> 2 nelson_2_nine_same      9 points in a row on same side of center              
#> 3 nelson_3_six_trend      6 points in a row, all increasing or decreasing       
#> 4 nelson_4_alternating    14 points in a row, alternating                       
#> 5 nelson_5_two_of_three   2 out of 3 consecutive points beyond 2 sigma (same si…
#> 6 nelson_6_four_of_five   4 out of 5 consecutive points beyond 1 sigma (same si…
#> 7 nelson_7_stratification 15 points in a row within 1 sigma                     
#> 8 nelson_8_mixture        8 points in a row outside 1 sigma (either side)       
#> 9 we_seven_same           7 points in a row on same side of center (Western Ele…
```
