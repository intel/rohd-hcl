# Find

ROHD HCL comes with a Find.  The detailed API docs are available [here](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html).

A Find will search for first/nth occurrence of one(`1`)/zero(`0`) within a given Logic `bus`.
The underlying implementation uses a `Count` to count 1's or 0's whenever a Logic `n` value
is passed within the constructor argument.

It takes a Binary Logic `bus` and finds the position of any one or zero within the `bus`. A Find function without any constructor arguments will find the first one.
That is to say, By default a Find will go for finding the first occurrence when no `n` is passed. In addition, with `countOne` which is set as `true` by default to
search only one (`1`). Both boolean `countOne` and Logic `n` are optional. Only Logic `bus` is mandatory argument.

This has an output pin named as `find`, for the index position on the occurrence searched (`1`s or `0`s) taken from the LSB (Least significant bit).

## Find First

To find the first occurrence just pass in the `bus` without mentioning any value for `n`.

### Find First One

To find the first occurrence just pass in `bus` without mentioning any value for `n`. In addition to finding first occurrence of One (`1`), set the argument `countOne` to `true`.
By default `countOne` is already set to `true`.

### Find First Zero

To find the first occurrence just pass in `bus` without mentioning any value for `n`. In addition to finding first occurrence of Zero (`0`), set the argument `countOne` to `false`.

## Find Nth

To find the nth occurrence just pass in `bus` along with Logic value `n` passed in as an argument.

### Find Nth One

To find the nth occurrence just pass in `bus` along with Logic value `n` passed in as an argument. In addition to finding occurrence of One (`1`), set the argument `countOne` to `true`.

### Find Nth Zero

To find the nth occurrence just pass in `bus` along with Logic value `n` passed in as an argument. In addition to finding occurrence of Zero (`0`), set the argument `countOne` to `false`.
