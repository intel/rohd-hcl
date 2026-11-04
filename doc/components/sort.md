# Sort

ROHD-HCL provides a component to perform sort of a list of Logic. As of now, we have

- [Bitonic Sort](#bitonic-sort)

## Bitonic Sort

Bitonic sort is a pipelined sorting algorithm commonly used in hardware implementations that recursively constructs a bitonic sequence and merges and compares pairs of elements to sort the sequence in ascending or descending order.

The [`BitonicSort`](https://intel.github.io/rohd-hcl/rohd_hcl/BitonicSort-class.html) module in ROHD-HCL accept four inputs: the clock `clk` signal, reset `reset` signal, a List of Logic()'s `toSort`, sort order `isAscending` and the name of the module `name`.

Note that bitonic sort **MUST** have List of inputs Logic of length power of two. To sort inputs that do not have length power of two, you must pre-process the inputs ahead by padding with `Const(0)` to have inputs length of power of two. Additionally, all the widths in the List of `toSort` must have same width.

An example is shown below sorting 4 inputs of Logic signal that have width 8-bits to descending order.

```dart
const dataWidth = 8;
final clk = SimpleClockGenerator(10).clk;
final reset = Logic(name: 'reset');
final toSort = <Logic>[
    Const(1, width: dataWidth),
    Const(7, width: dataWidth),
    Const(2, width: dataWidth),
    Const(8, width: dataWidth)
];

final sortMod = BitonicSort(clk, reset, toSort: toSort,  isAscending: false, name: 'top_level');

await sortMod.build();
```

## Typed payloads

`BitonicSort<T>` preserves `T` on its input ports, intermediate registers, and
`sorted` outputs. Structures and typed arrays must have matching recursive
layouts, including array dimensions and codecs. A singleton remains
combinational; the pipeline latency for larger sequences is unchanged.

The default comparison calls the payload's `lt` method, so floating-point and
signed fixed-point signals use their numeric comparisons rather than unsigned
packed-bit ordering. To retain packed ordering, pass the signals' `.packed`
representations instead.

For records, supply a strict one-bit `isLessThan` comparison:

```dart
final sorter = BitonicSort<Sample>(clk, reset,
    toSort: samples,
    isLessThan: (a, b) => a.key.lt(b.key));
final Sample first = sorter.sorted.first;
```

The complete record travels with its key. The comparison is propagated through
all recursive sort and merge stages, in both ascending and descending modes.
For scalar constant inputs, request `BitonicSort<Logic>(...)` explicitly so
mutable ports and pipeline registers are not inferred as `Const`.
