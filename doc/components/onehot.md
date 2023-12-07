# One Hot Codecs

ROHD HCL implements a set of one hot encoder and decoders.

For example, we have an encoder [`BinaryToOneHot`](https://intel.github.io/rohd-hcl/rohd_hcl/BinaryToOneHot-class.html) class, and a couple of implementations of decoder classes like [`OneHotToBinary`](https://intel.github.io/rohd-hcl/rohd_hcl/OneHotToBinary-class.html) and a more performant [`TreeBinaryToOneHot`](https://intel.github.io/rohd-hcl/rohd_hcl/TreeOneHotToBinary-class.html).

The encoders take a Logic bitvector, with the constraint that only a single bit is set to '1' and outputs the bit position in binary.

The decoders take a Logic input representing the bit position to be set to '1', and returns a Logic bitvector with that bit position set to '1', and all others set to '0'

[OneHotToBinary Schematic](https://intel.github.io/rohd-hcl/One_hot_Converter.html)