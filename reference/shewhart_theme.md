# Editorial-style ggplot2 theme used by every `autoplot.shewhart_*`

Shared across the package so charts look like one family. The visual
choices are inspired by data-journalism graphics (FT, Pew Research, The
Economist): off-white background, only horizontal grid lines, axis line
on the data side, left-aligned title block, and tonal grey for non-data
ink.

## Usage

``` r
shewhart_theme(base_size = 11, base_family = "")
```

## Arguments

- base_size:

  Base font size, in points.

- base_family:

  Base font family. Empty string uses the system default sans-serif. We
  do not hard-code a Google Font so the theme works in offline /
  CRAN-check environments.

## Value

A
[`ggplot2::theme()`](https://ggplot2.tidyverse.org/reference/theme.html)
object.

## Details

Use it from your own layers when you want a chart that matches the
package's identity:

    ggplot(d, aes(x, y)) + geom_line() + shewhart_theme()

## Examples

``` r
library(ggplot2)
df <- data.frame(x = 1:50, y = cumsum(rnorm(50)))
ggplot(df, aes(x, y)) + geom_line() + shewhart_theme()
```
