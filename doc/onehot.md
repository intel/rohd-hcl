# One Hot Codecs

ROHD HCL implements a set of one hot encoder and decoders.

The encoders take a Logic bitvector, with the constraint that only a single bit is set to '1' and outputs the bit position in binary.

The decoders take a Logic input representing the bit position to be set to '1', and returns a Logic bitvector with that bit position set to '1', and all others set to '0'

[BinaryToOneHot Schematic](https://desmonddak.github.io/rohd-hcl/BinaryToOneHot.html)

[OneHotToBinary Schematic](https://desmonddak.github.io/rohd-hcl/OneHotToBinary.html)

[TreeOneHotToBinary Schematic](https://desmonddak.github.io/rohd-hcl/TreeOneHotToBinary.html)
