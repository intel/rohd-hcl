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
case, the prefix trees are carrying two-bit words at each node.

Each of these operations can be implemented with different
['ParallelPrefix'](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefix-class.html)
types:

- ['Ripple'](https://intel.github.io/rohd-hcl/rohd_hcl/Ripple-class.html)
- ['Sklansky](https://intel.github.io/rohd-hcl/rohd_hcl/Sklansky-class.html)
- ['Kogge-Stone'](https://intel.github.io/rohd-hcl/rohd_hcl/KoggeStone-class.html)
- ['Brent-Kung](https://intel.github.io/rohd-hcl/rohd_hcl/BrentKung-class.html)

Here is an example adder schematic:
<!-- [ParallelPrefixAdder Schematic](https://intel.github.io/rohd-hcl/ParallelPrefixAdder.html) -->
