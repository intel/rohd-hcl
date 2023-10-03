# Parallel Prefix Operations

ROHD HCL implements a set of parallel prefix compute operations using
different parallel prefix computation trees.

For example, we have unary operations like a word 'or' [`OrScan`] class, and a priority encoder [`PriorityEncoder`] class. We have simple unary arithmetic operations like an increment [`PPIncr`] class, and a decrement [`PPDecr`] class. Finally, we have a binary adder [`PPAdder`] class.

Each of these operations can be implemented with different ['ParallelPrefix'] types:

- ['Ripple']
- ['Sklansky]
- ['KoggeStone']
- ['BrentKung]

[PPAdder_BrentKung Schematic]
