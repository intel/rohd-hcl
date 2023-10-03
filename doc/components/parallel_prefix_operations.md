# Parallel Prefix Operations

ROHD HCL implements a set of parallel prefix compute operations using
different parallel prefix computation trees.

For example, we have unary operations like a word 'or' [`OrScan`](https://intel.github.io/rohd-hcl/rohd_hcl/OrScan-class.html) class, and a priority encoder [`PriorityEncoder`](https://intel.github.io/rohd-hcl/rohd_hcl/PriorityEncoder-class.html) class. We have simple unary arithmetic operations like an increment [`PPIncr`](https://intel.github.io/rohd-hcl/rohd_hcl/PPIncr-class.html) class, and a decrement [`PPDecr`](https://intel.github.io/rohd-hcl/rohd_hcl/PPDecr-class.html) class. Finally, we have a binary adder [`PPAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/PPadder-class.html) class.

Each of these operations can be implemented with different ['ParallelPrefix'] types:
- ['Ripple'](https://intel.github.io/rohd-hcl/rohd_hcl/Ripple-class.html)
- ['Sklansky](https://intel.github.io/rohd-hcl/rohd_hcl/Sklansky-class.html)
- ['KoggeStone'](https://intel.github.io/rohd-hcl/rohd_hcl/KoggeStone-class.html)
- ['BrentKung](https://intel.github.io/rohd-hcl/rohd_hcl/BrentKung-class.html)

[PPAdder_BrentKung Schematic](https://intel.github.io/rohd-hcl/PPAdder_BrentKung.html)

