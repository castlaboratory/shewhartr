# Access the package's named colour palettes

Returns one of the curated colour vectors that every chart in the
package draws from. Useful when extending an
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
chart with your own layers and you want them to match the rest of the
package's visual identity.

## Usage

``` r
shewhart_palette(
  name = c("phase_seq", "family", "signal", "neutral"),
  n = NULL
)
```

## Arguments

- name:

  One of `"phase_seq"`, `"family"`, `"signal"`, `"neutral"`. See
  *Details* for the contents and intended use of each.

- n:

  Optional integer. Number of colours to return. If `NULL` (default) the
  full palette is returned. If `n` exceeds the palette length, a smooth
  ramp
  ([`grDevices::colorRampPalette()`](https://rdrr.io/r/grDevices/colorRamp.html))
  is interpolated.

## Value

A character vector of colour hex codes; for `family` and `signal`, the
vector is named.

## Details

- `phase_seq`:

  Sequential palette for time-ordered phase indices in regression /
  multi-phase charts. Cool blues at the baseline, warming through
  neutral to terracotta as phase index grows. Avoids saturated red
  (reserved for `signal`).

- `family`:

  Named categorical palette for the four chart families: variables,
  attributes, memory-based, multivariate. Identical to the colours used
  in the architecture diagram.

- `signal`:

  Two-colour palette: `in_control` (deep blue) and `out_of_control`
  (firebrick). Used to colour violation points on every chart so the
  alarm signal is consistent.

- `neutral`:

  Structural greys used by
  [`shewhart_theme()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_theme.md)
  for backgrounds, gridlines and text colour.

## Examples

``` r
shewhart_palette("phase_seq", n = 4)
#> [1] "#0F4C81" "#2A6BA0" "#4F8DBE" "#7AAFD3"
shewhart_palette("family")["multivariate"]
#> multivariate 
#>    "#7030A0" 
shewhart_palette("signal")
#>     in_control out_of_control 
#>      "#1F4068"      "#C3423F" 
```
