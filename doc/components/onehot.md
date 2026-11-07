# One Hot Codecs

ROHD-HCL implements a set of one hot encoder and decoders.

[`BinaryToOneHot`](https://intel.github.io/rohd-hcl/rohd_hcl/BinaryToOneHot-class.html)
converts a binary index to a one-hot vector. `OneHotToBinary` converts a
one-hot vector to an index, selecting between `CaseOneHotToBinary` and
`TreeOneHotToBinary` implementations based on input width.

`OneHotToBinary` expects a one-hot input; `BinaryToOneHot` accepts the binary
position of the bit to set.

[OneHotToBinary Schematic](https://intel.github.io/rohd-hcl/OneHotToBinary.html)
