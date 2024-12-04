# Multiplier

ROHD-HCL provides an abstract `Multiplier` module which multiplies two
numbers represented as two `Logic`s, potentially of different widths,
treating them as either signed (2s complement) or unsigned. It
produces the product as a `Logic` with width equal to the sum of the
widths of the inputs. The signs of the operands are either fixed by a parameter,
or runtime selectable, e.g.:   `signedMultiplicand` or `selectSignedMultiplicand`.
The output of the multiplier also has a signal telling us if the result is to be
treated as signed.

As of now, we have the following implementations
of this abstract `Module`:

- [Carry Save Multiplier](#carry-save-multiplier)
- [Compression Tree Multiplier](#compression-tree-multiplier)

An additional kind of abstract module provided is a
`MultiplyAccumulate` module which multiplies two numbers represented
as two `Logic`s and adds the result to a third `Logic` with width
equal to the sum of the widths of the main inputs. Similar to the `Multiplier`,
the signs of the operands are either fixed by a parameter,
or runtime selectable, e.g.:   `signedMultiplicand` or `selectSignedMultiplicand`.
The output of the multiplier also has a signal telling us if the result is to be
treated as signed.

We have a
high-performance implementation:

- [Compression Tree Multiply Accumulate](#compression-tree-multiply-accumulate)

The compression tree based arithmetic units are built from a set of components for Booth-encoding, column compression, and parallel prefix adders described in the [`Booth Encoding Multiplier Building Blocks`](./multiplier_components.md#booth-encoding-multiplier-building-blocks) section.

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

- Two input terms `a` and `b` which can be different widths.
- The radix used for Booth encoding (2, 4, 8, and 16 are currently supported).
- The type of `ParallelPrefix` tree used in the final `ParallelPrefixAdder` (optional).
- `ppGen` parameter: the type of `PartialProductGenerator` to use which has derived classes for different styles of sign extension. In some cases this adds an extra row to hold a sign bit.
- `signedMultiplicand` parameter: whether the multiplicand (first arg) should be treated as signed (2s complement) or unsigned.
- `signedMultiplier` parameter: whether the multiplier (second arg) should be treated as signed (2s complement) or unsigned.
- An optional `selectSignedMultiplicand` control signal which overrides the `signedMultiplicand` parameter allowing for runtime control of signed or unsigned operation with the same hardware. `signedMultiplicand` must be false if using this control signal.
- An optional `selectSignedMultiplier` control signal which overrides the `signedMultiplier` parameter allowing for runtime control of signed or unsigned operation with the same hardware. `signedMultiplier` must be false if using this control signal.
- An optional `clk`, as well as `enable` and `reset` that are used to add a pipestage in the `ColumnCompressor` to allow for pipelined operation.

Here is an example of use of the `CompressionTreeMultiplier`:

```dart
    const widthA = 6;
    const widthB = 9;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);

    a.put(15);
    b.put(3);

    final multiplier =
        CompressionTreeMultiplier(a, b, radix, signed: true);

    final product = multiplier.product;

    print('${product.value.toBigInt()}');
```

## Compression Tree Multiply Accumulate

A compression tree multiply-accumulate is similar to a compress tree
multiplier, but it inserts an additional addend into the compression
tree to allow for accumulation into this third input.

The parameters of the
`CompressionTreeMultiplyAccumulate` are:

- Two input product terms `a` and `b` which can be different widths
- The accumulate input term `c` which must have width as sum of the two operand widths + 1.
- The radix used for Booth encoding (2, 4, 8, and 16 are currently supported)
- The type of `ParallelPrefix` tree used in the final `ParallelPrefixAdder` (default Kogge-Stone).
- `ppGen` parameter: the type of `PartialProductGenerator` to use which has derived classes for different styles of sign extension. In some cases this adds an extra row to hold a sign bit (default `PartialProductGeneratorCompactRectSignExtension`).
- `signedMultiplicand` parameter: whether the multiplicand (first arg) should be treated as signed (2s complement) or unsigned
- `signedMultiplier` parameter: whether the multiplier (second arg) should be treated as signed (2s complement) or unsigned
- `signedAddend` parameter: whether the addend (third arg) should be treated as signed (2s complement) or unsigned
- An optional `selectSignedMultiplicand` control signal which overrides the `signedMultiplicand` parameter allowing for runtime control of signed or unsigned operation with the same hardware. `signedMultiplicand` must be false if using this control signal.
- An optional `selectSignedMultiplier` control signal which overrides the `signedMultiplier` parameter allowing for runtime control of signed or unsigned operation with the same hardware. `signedMultiplier` must be false if using this control signal.
- An optional `selectSignedAddend` control signal which overrides the `signedAddend` parameter allowing for runtime control of signed or unsigned operation with the same hardware. `signedAddend` must be false if using this control signal.
- An optional `clk`, as well as `enable` and `reset` that are used to add a pipestage in the `ColumnCompressor` to allow for pipelined operation.

Here is an example of using the `CompressionTreeMultiplyAccumulate`:

```dart
    const widthA = 6;
    const widthB = 9;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB);

    a.put(15);
    b.put(3);
    c.put(5);

    final multiplier = CompressionTreeMultiplyAccumulate(a, b, c, radix, signed: true);

    final accumulate = multiplier.accumulate;
    
    print('${accumulate.value.toBigInt()}');
```
