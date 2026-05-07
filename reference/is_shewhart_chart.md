# Shewhart chart S3 class

All chart constructors in the package return an object of class
`shewhart_chart` with a more specific subclass (`shewhart_i_mr`,
`shewhart_xbar_r`, `shewhart_p`, `shewhart_regression`, ...). The shared
slots are `type`, `augmented`, `limits`, `violations`, `fits`, `rules`,
`sigma_hat`, `sigma_method`, `phase`, `n`, `call`, and `metadata`.
`is_shewhart_chart()` tests inheritance.

## Usage

``` r
is_shewhart_chart(x)
```

## Arguments

- x:

  An object.

## Value

Logical scalar.

## Examples

``` r
fit <- shewhart_i_mr(data.frame(v = rnorm(30)), v)
is_shewhart_chart(fit)
#> [1] TRUE
```
