# Parallel Prefix Operations

ROHD HCL implements a set of parallel prefix compute operations using different parallel prefix computation trees based on the ['ParallelPrefix'] node class carrying carry/save or generate/propagate bits.

For example, we have unary operations like a word-level 'or' [`ParallelPrefixOrScan`] class, and a priority encoder [`ParallelPrefixPriorityEncoder`] class which computes the position of the first bit set to '1'. We have simple unary arithmetic operations like an increment [`ParallelPrefixIncr`] class, and a decrement [`ParallelPrefixDecr`] class. Finally, we have a binary adder [`ParallelPrefixAdder`] class. For background on basic parallel prefix adder structures, see <https://en.wikipedia.org/wiki/Kogge%E2%80%93Stone_adder>.

Each of these operations can be implemented with different ['ParallelPrefix'] types:

- ['Ripple']
- ['Sklansky]
- ['KoggeStone']
- ['BrentKung]
