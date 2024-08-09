# Multiplier

ROHD HCL provides an abstract `Multiplier` module which multiplies two
numbers represented as two `Logic`s, potentially of different widths,
treating them as either signed (2s complement) or unsigned. It
produces the product as a `Logic` with width equal to the sum of the
widths of the inputs. As of now, we have the following implementations
of this abstract `Module`:

- [Carry Save Multiplier](#carry-save-multiplier)
- [Compression Tree Multiplier](#compression-tree-multiplier)

An additional kind of abstract module provided is a
`MultiplyAccumulate` module which multiplies two numbers represented
as two `Logic`s and adds the result to a third `Logic` with width
equal to the sum of the widths of the main inputs. We have a
high-performance implementation:

- [Compression Tree Multipy Accumulate](#compression-tree-multiply-accumulate)

## Carry Save Multiplier

Carry save multiplier is a digital circuit used for performing multiplication operations. It
is particularly useful in applications that require high speed
multiplication, such as digital signal processing.

The
[`CarrySaveMultiplier`](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySaveMultiplier-class.html)
module in ROHD-HCL accept input parameters the clock `clk` signal,
reset `reset` signal, `Logic`s' a and b as the input pin and the name
of the module `name`. Note that the width of the inputs must be the
same or `RohdHclException` will be thrown.

An example is shown below to multiply two inputs of signals that have 4-bits of width.

```dart
const bitWidth = 4;
final a = Logic(name: 'a', width: bitWidth);
final b = Logic(name: 'b', width: bitWidth);
final reset = Logic(name: 'reset');
final clk = SimpleClockGenerator(10).clk;

final csm = CarrySaveMultiplier(clk: clk, reset: reset, a, b);

await csm.build();

reset.inject(0);

Simulator.setMaxSimTime(10000);

unawaited(Simulator.run());

Future<void> waitCycles(int numCycles) async {
    for (var i = 0; i < numCycles; i++) {
        await clk.nextPosedge;
    }
}

a.put(10);
b.put(3);

await waitCycles(csm.latency).then(
    (value) {
        print(csm.product.value.toInt());
    },
);

Simulator.endSimulation();
```

## Compression Tree Multiplier

A compression tree multiplier is a digital circuit used for performing
multiplication operations, using Booth encoding to produce addends, a
compression tree for reducing addends to a final pair, and a final
adder generated from a parallel prefix tree option. It is particularly
useful in applications that require high speed multiplication, such as
digital signal processing.

The parameters of the
`CompressionTreeMultiplier` are:

- Two input terms a and b
- The radix used for Booth encoding (2, 4, 8, and 16 are currently supported)
- The type of `ParallelPrefix` tree used in the final `ParallelPrefixAdder`
- Whether the operands should be treated as signed (2s complement) or unsigned

## Compression Tree Multiply Accumulate

A compression tree multiply accumulate is similar to a compress tree
multiplier, but it inserts an additional addend into the compression
tree to allow for accumulation into this third input.

The parameters of the
`CompressionTreeMultiplier` are:

- Two input terms a and b
- The accumulate input term c
- The radix used for Booth encoding (2, 4, 8, and 16 are currently supported)
- The type of `ParallelPrefix` tree used in the final `ParallelPrefixAdder`
- Whether the operands should be treated as signed (2s complement) or unsigned
