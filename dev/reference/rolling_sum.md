# Rolling sum with a configurable window

Slides over `x` summing the last `.window` elements (including the
current one). Treats `NA` as zero. Used internally by the runs tests.

## Usage

``` r
rolling_sum(x, .window = 7L)
```

## Arguments

- x:

  Numeric vector.

- .window:

  Integer window size (\>= 1). Default: 7.

## Value

A numeric vector the same length as `x`.

## Examples

``` r
rolling_sum(c(1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1), .window = 7)
#>  [1] 1 1 2 3 4 4 5 5 6 6 6 6 7 7
```
