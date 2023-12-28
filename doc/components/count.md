# Count

ROHD HCL comes with a `Count` component.  The detailed API docs are available [here](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html).

A `Count` will count all one(`1`)/zero(`0`) within a given Logic `bus`.

It takes a binary Logic `bus` and counts all one or zero within the `bus`. A Count function without any constructor arguments will only count all Ones (`1`).
That is to say, by default a Count will go for counting with a `countOne` which is set as `true` by default.
The boolean `countOne` is optional. Only Logic `bus` is mandatory argument.

This will return a Logic value labeled as `countOne` for `1` and `countZero` for `0`. The value is a result of count of all occurrence parsed (with `countOne` as `1` or `0`) through the entire Logic `bus`.

## Count One

To count all ones just pass in the `bus` with `countOne` as `true`. By default countOne is `true`.

## Count Zero

To count all zeros just pass in the `bus` with `countOne` as `false`.
