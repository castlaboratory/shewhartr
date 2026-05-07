# Apply / invert a Box-Cox power transformation

The Box-Cox transformation (Box & Cox, 1964) is \$\$y(\lambda) =
\begin{cases} (x^\lambda - 1) / \lambda & \lambda \neq 0 \\ \log(x) &
\lambda = 0. \end{cases}\$\$

## Usage

``` r
box_cox(x, lambda)
```

## Arguments

- x:

  Numeric vector of strictly positive values.

- lambda:

  Numeric scalar. Power parameter.

## Value

A numeric vector of transformed values.

## Details

For `lambda = 0` this returns `log(x)`; for `lambda = 1` it returns
`x - 1` (no shape change). Use
[`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
to estimate `lambda` from the data via profile log-likelihood.

## References

Box, G. E. P., & Cox, D. R. (1964). An Analysis of Transformations.
*Journal of the Royal Statistical Society, Series B*, 26(2), 211-252.
[doi:10.1111/j.2517-6161.1964.tb00553.x](https://doi.org/10.1111/j.2517-6161.1964.tb00553.x)

## See also

[`shewhart_box_cox()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_box_cox.md)
to estimate lambda from data.

## Examples

``` r
box_cox(1:10, lambda = 0)      # equivalent to log(1:10)
#>  [1] 0.0000000 0.6931472 1.0986123 1.3862944 1.6094379 1.7917595 1.9459101
#>  [8] 2.0794415 2.1972246 2.3025851
box_cox(1:10, lambda = 0.5)
#>  [1] 0.0000000 0.8284271 1.4641016 2.0000000 2.4721360 2.8989795 3.2915026
#>  [8] 3.6568542 4.0000000 4.3245553
```
