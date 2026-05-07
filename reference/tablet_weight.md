# Pharmaceutical tablet weights

A synthetic dataset modelled on classical pharmaceutical quality
control. Tablet weights are recorded in subgroups of 5 tablets each,
across 25 production batches. Target weight is 250 mg with a process
sigma of 1.5 mg; a small mean shift to 251.5 mg is embedded in subgroups
18-25.

## Usage

``` r
tablet_weight
```

## Format

A tibble with 125 rows and 3 columns:

- subgroup:

  Integer batch identifier (1-25).

- tablet:

  Integer tablet position within the batch (1-5).

- weight:

  Numeric tablet weight in milligrams.

## Source

Synthetic. See `data-raw/build_all.R`.

## See also

[`shewhart_xbar_r()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_r.md),
[`shewhart_xbar_s()`](https://castlaboratory.github.io/shewhartr/reference/shewhart_xbar_s.md).

## Examples

``` r
fit <- shewhart_xbar_r(tablet_weight, value = weight, subgroup = subgroup)
# \donttest{
ggplot2::autoplot(fit)

# }
```
