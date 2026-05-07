# Phase II monitoring against pre-calibrated limits

Applies the control limits (and rule set) from a calibrated
[shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
object to fresh data. The new data must contain the same columns used by
the original chart constructor.

## Usage

``` r
monitor(data, chart)
```

## Arguments

- data:

  A data frame with the same columns as the data used to fit `chart`.

- chart:

  A pre-calibrated
  [shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
  object.

## Value

A
[shewhart_chart](https://castlaboratory.github.io/shewhartr/reference/is_shewhart_chart.md)
object with `$phase = "phase_2"` and limits inherited from `chart`.

## Details

Limits are *not* re-estimated; they are the limits stored on the
calibration object. Only the violation table is recomputed against the
new observations.

## References

Woodall, W. H. (2000). Controversies and Contradictions in Statistical
Process Control. *Journal of Quality Technology*, 32(4), 341-350.

## Examples

``` r
set.seed(1)
base    <- data.frame(y = rnorm(50, mean = 100, sd = 2))
new_obs <- data.frame(y = rnorm(20, mean = 102, sd = 2))   # small shift
calib   <- calibrate(base, value = y, chart = "i_mr")
alarms  <- monitor(new_obs, calib)
alarms$violations
#> # A tibble: 3 × 5
#>   position rule               description            value severity      
#>      <int> <chr>              <chr>                  <dbl> <chr>         
#> 1        6 nelson_1_beyond_3s 1 point beyond 3 sigma  106. out_of_control
#> 2       11 nelson_1_beyond_3s 1 point beyond 3 sigma  107. out_of_control
#> 3       20 nelson_1_beyond_3s 1 point beyond 3 sigma  106. out_of_control
```
