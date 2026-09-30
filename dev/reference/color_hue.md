# Generate a qualitative HCL palette

Internal palette used as a default when a number of phases or subgroups
need distinct colours. For most plots, ggplot2's default palette is
fine; this is provided for backward compatibility and quick prototyping.

## Usage

``` r
color_hue(n)
```

## Arguments

- n:

  Integer (\>= 1). Number of colours to generate.

## Value

A character vector of `n` hex colour strings.

## Examples

``` r
color_hue(5)
#> [1] "#F8766D" "#A3A500" "#00BF7D" "#00B0F6" "#E76BF3"
```
