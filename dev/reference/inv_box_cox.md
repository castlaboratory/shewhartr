# Inverse Box-Cox transformation

Inverse Box-Cox transformation

## Usage

``` r
inv_box_cox(x, lambda)
```

## Arguments

- x:

  Numeric vector of strictly positive values.

- lambda:

  Numeric scalar. Power parameter.

## Value

A numeric vector on the original scale.

## Examples

``` r
y <- box_cox(1:10, lambda = 0.5)
inv_box_cox(y, lambda = 0.5)          # recovers 1:10
#>  [1]  1  2  3  4  5  6  7  8  9 10
inv_box_cox(log(1:10), lambda = 0)    # lambda = 0 is exp()
#>  [1]  1  2  3  4  5  6  7  8  9 10
```
