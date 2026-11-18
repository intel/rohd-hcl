# One Hot Codecs

ROHD-HCL implements a set of one hot encoder and decoders.

[`BinaryToOneHot`](https://intel.github.io/rohd-hcl/rohd_hcl/BinaryToOneHot-class.html)
converts a binary index to a one-hot vector. `OneHotToBinary` converts a one-hot
vector to an index, selecting between `CaseOneHotToBinary` and
`TreeOneHotToBinary` implementations based on input width.

`OneHotToBinary` expects a one-hot input; `BinaryToOneHot` accepts the binary
position of the bit to set.

Both conversions are also available as `binaryToOneHot()` and
`oneHotToBinary()` extensions on `Logic` and `LogicValue`. The signal
extensions instantiate the corresponding codec; the value extensions evaluate
the same codec on a constant. Binary-to-one-hot produces `2^width` bits;
one-hot-to-binary produces `widthFor(width)` bits. One-hot-to-binary inputs
should contain exactly one set bit; invalid and
unknown inputs follow the default codec's behavior, which depends on input
width. Use `OneHotToBinary` directly with `generateError: true` when error
detection is required.

For inputs containing X or Z, the default case-based decoder can differ
between ROHD simulation and generated RTL. For example, an unknown case input
can produce X in ROHD while the RTL takes the default case and produces zero.
The `LogicValue` extension reflects ROHD simulation.

[OneHotToBinary Schematic](https://intel.github.io/rohd-hcl/OneHotToBinary.html)
