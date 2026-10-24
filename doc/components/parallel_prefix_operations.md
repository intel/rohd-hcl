# Parallel Prefix Operations

Parallel prefix or 'scan' trees are useful for efficient
implementation of computations which involve associative
operators. They are used in computations like encoding, or-reduction,
and addition. By leveraging advanced programming idioms, like
functors, allowing for passing of a function that generates prefix trees
into a scan-based generator for that computation, we can have a wide
variety of that computation supported by our component library. For
example, we have tree patterns defined by ripple, Sklansky,
Kogge-Stone, and Brent-Kung which gives us those four varieties of
prefix reduction trees we can use across addition, or-reduction, and
priority encoding.

ROHD-HCL implements a set of parallel prefix compute operations using
different parallel prefix computation trees based on the
['ParallelPrefix'](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefix-class.html)
node class.

For example, we have unary operations like a word-level 'or'
[`ParallelPrefixOrScan`](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixOrScan-class.html)
class, and a priority encoder
[`ParallelPrefixPriorityEncoder`](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixPriorityEncoder-class.html)
class which computes the position of the first bit set to '1'. We have
simple unary arithmetic operations like an increment
[`ParallelPrefixIncr`](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixIncr-class.html)
class, and a decrement
[`ParallelPrefixDecr`](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixDecr-class.html)
class. Finally, we have a binary adder
[`ParallelPrefixAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixAdder-class.html)
class. For background on basic parallel prefix adder structures, see
<https://en.wikipedia.org/wiki/Kogge%E2%80%93Stone_adder>. In this
case, the prefix trees carry named `GeneratePropagate` records at each node.

## Typed Prefix Networks

`ParallelPrefix<T>`, `Ripple<T>`, `Sklansky<T>`, `KoggeStone<T>`, and
`BrentKung<T>` retain `T` on their input ports, intermediate aliases, callbacks,
and output `val` lists. Structures, enums, floating/fixed-point signals, and
typed arrays retain their recursive layouts, mappings, dimensions, and codecs.
The output list is read-only.

```dart
Sample combine(Sample left, Sample right) =>
    mux<Sample>(left.valid, left, right, outputGenerator: left.cloneTyped);

final prefix = KoggeStone<Sample>(samples, combine);
final Sample firstValid = prefix.val.last;
```

Each output `i` combines inputs `0` through `i`. The callback must be
associative, but need not be commutative: all four networks preserve operand
order. Empty input sequences are rejected. Singleton sequences pass through
without calling the operation. There are no added pipeline stages.

Structured inputs and callback results must have matching schemas. These scans
do not perform automatic field alignment or format widening. Ordinary scalar
`Logic` retains its existing per-output widths and bit-vector behavior.
For scalar constant inputs, explicitly request `KoggeStone<Logic>(...)` (or the
corresponding topology) to construct mutable ports rather than infer `Const`.

`ParallelPrefixGenerator<T>` names the callback that constructs a network:

```dart
ParallelPrefix<Sample> makeTree(
    List<Sample> inputs, Sample Function(Sample left, Sample right) operation) =>
  BrentKung<Sample>(inputs, operation);
```

### Adder Generator Migration

`ParallelPrefixAdder.ppGen` now accepts
`ParallelPrefixGenerator<GeneratePropagate>`, rather than a generator of packed
`Logic` pairs. Custom generators must retain the named `generate` and
`propagate` fields. Built-in constructor tear-offs such as `BrentKung.new`
continue to work unchanged.

OR scans, priority finding/encoding, incrementers, and decrementers remain
bit-oriented and use `ParallelPrefixGenerator<Logic>`. Their external ports and
arithmetic semantics are unchanged.

Each of these operations can be implemented with different
['ParallelPrefix'](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefix-class.html)
types:

- ['Ripple'](https://intel.github.io/rohd-hcl/rohd_hcl/Ripple-class.html)
- ['Sklansky](https://intel.github.io/rohd-hcl/rohd_hcl/Sklansky-class.html)
- ['Kogge-Stone'](https://intel.github.io/rohd-hcl/rohd_hcl/KoggeStone-class.html)
- ['Brent-Kung](https://intel.github.io/rohd-hcl/rohd_hcl/BrentKung-class.html)

Here is an example adder schematic:
[ParallelPrefixAdder Schematic](https://intel.github.io/rohd-hcl/ParallelPrefixAdder.html)
