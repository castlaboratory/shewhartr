# Look up Shewhart control chart constants

Returns the classical Shewhart constants (A2, A3, c4, d2, d3, B3-B6,
D3-D4) for a given subgroup size `n`. Tabulated values are used for
`n <= 25`; for larger samples, c4 is computed from its closed form and
the remaining constants are derived analytically when known (otherwise
NA is returned with a warning).

## Usage

``` r
shewhart_constants(n)
```

## Arguments

- n:

  Integer scalar or vector. Subgroup size (\>= 2).

## Value

A data frame with columns `n`, `A2`, `A3`, `c4`, `d2`, `d3`, `B3`, `B4`,
`B5`, `B6`, `D3`, `D4`.

## References

Montgomery, D. C. (2019). *Introduction to Statistical Quality Control*
(8th ed.). Wiley. Appendix VI.

## Examples

``` r
shewhart_constants(5)
#>   n    A2    A3   c4    d2    d3 B3    B4 B5    B6 D3    D4
#> 1 5 0.577 1.427 0.94 2.326 0.864  0 2.089  0 1.964  0 2.114
shewhart_constants(c(2, 5, 10, 25))
#>    n    A2    A3     c4    d2    d3    B3    B4    B5    B6    D3    D4
#> 1  2 1.880 2.659 0.7979 1.128 0.853 0.000 3.267 0.000 2.606 0.000 3.267
#> 2  5 0.577 1.427 0.9400 2.326 0.864 0.000 2.089 0.000 1.964 0.000 2.114
#> 3 10 0.308 0.975 0.9727 3.078 0.797 0.284 1.716 0.276 1.669 0.223 1.777
#> 4 25 0.153 0.606 0.9896 3.931 0.708 0.565 1.435 0.559 1.420 0.459 1.541
```
