# Bit Operations

The following components complement the [count](count.md), [find](find.md), and
[rotate](rotate.md) modules. They are exported by
`package:rohd_hcl/rohd_hcl.dart`.

## Bitwise Population Count

`XorPopcount(a, b)` counts differing bit positions and `XnorPopcount(a, b)`
counts equal positions. Inputs must have equal widths; both expose `count` and
the underlying count tree's `treeDepth`.

## Majority

`Majority(bits).majority` and `bits.majority()` for `Logic` produce one when
strictly more than half of the bits are one. An even-width tie produces zero.
X and Z inputs are treated as unknown: the output is known when all possible
assignments agree, and X otherwise. The general hardware uses a sorting network
of AND/OR comparators; the three-input case shares the existing full-adder
carry logic.

The existing `LogicValue.majority()` instead returns a Dart `bool` and returns
false whenever any bit is X or Z. It cannot represent an unknown result.

## Leading and Trailing Zeros

`CountLeadingZeros(inp)` and `CountTrailingZeros(inp)` expose the number of
zeros from the most- or least-significant end on `count`. For an all-zero input,
the result is the input width.

## Multiplexers

`OneHotMux(selector, cases)` combines every selected case with bitwise OR. No
selected bits produce zero; multiple selected bits OR the selected words.
`PriorityMux<T>` selects the lowest-index asserted selector bit or a
supplied default when none is asserted, preserving the payload type and layout.
Structured constants are supported when their clones are driveable, including
when the static payload type is `Logic`. Declared payload clones must preserve
their runtime type and semantic format.
The flat-port `PriorityMux` remains in the main barrel but is deprecated. Use
the generalized module with:

```dart
import 'package:rohd_hcl/rohd_hcl.dart' hide PriorityMux;
import 'package:rohd_hcl/priority_mux.dart';
```

`BitwiseMux(selects, inputs)` makes an independent selection for each bit
position. Each select and input has the same width, with one select per input.
At each bit, selected inputs are ORed, so one-hot selection per bit is the
intended use. `OneHotMux` and `BitwiseMux` are packed-bit operations: combining
multiple words can produce a value that does not belong to a payload's semantic
type. Use `PriorityMux<T>` when selecting an intact typed payload.

## First-Match Prefix

`FirstMatchPrefix` takes equal-width `eligibleMask` and `matchMask` inputs.
Lane zero is considered first. `selectedMask` identifies the first eligible
matching lane, and `keepMask` retains eligible lanes up to and including it.
When there is no eligible match, `keepMask` retains every eligible lane,
`selectedMask` is zero, and `anyMatch` is low. `keptCount` counts the retained
lanes.

Use this for a lane group that must stop at the first qualifying event while
retaining earlier eligible work. It does not compact data or retain state;
`keepMask` can still contain gaps where lanes were ineligible.

## Boolean Sparse-to-Dense Scatter

`SparseToDense(indices, valids, outputWidth: n)` produces an `n`-bit vector
with a bit set for each valid, in-range unsigned index. Repeated indices are
combined with OR; out-of-range indices contribute zero. Indices must be
nonempty and equal-width, with one single-bit valid per index.

The implementation uses bounded-width shifts and a `ReductionTree`, without
constructing a `2^indexWidth` decoder. See the
[reduction-tree example](reduction_tree.md#boolean-sparse-to-dense-scatter)
for the composition and four-state behavior.

## Padding and Bit Replacement

`Pad(inp, atLeast: n)` extends the input to at least `n` bits. It pads the
least-significant end by default; `lsbs: false` pads the other end, and `fill`
selects the inserted bit value. Inputs already at least `n` bits are unchanged.

`SetBits(inp, count)` sets a runtime-selected number of bits at one end to
`fill`; `lsbs` chooses the end and counts at or above the input width affect
every bit. `WithSet(subject, start, value)` overwrites a runtime-selected range.
Bits above the subject width are discarded, and a start at or beyond that width
leaves the subject unchanged.
