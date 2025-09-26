# Integer Multiplier

ROHD-HCL provides an abstract [Multiplier](https://intel.github.io/rohd-hcl/rohd_hcl/Multiplier-class.html) module which multiplies two
numbers represented as two `Logic`s, potentially of different widths,
treating them as either signed (twos' complement) or unsigned. It
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
[MultiplierAccumulate](https://intel.github.io/rohd-hcl/rohd_hcl/MultiplyAccumulate-class.html) module which multiplies two numbers represented
as two `Logic`s and adds the result to a third `Logic` with width
equal to the sum of the widths of the main inputs. Similar to the `Multiplier`,
the signs of the operands are either fixed by a parameter,
or runtime selectable, e.g.:   `signedMultiplicand` or `selectSignedMultiplicand`.
The output of the multiply-accumulate also has a signal telling us if the result is to be
treated as signed.

We have a
high-performance implementation:

- [Compression Tree Multiply Accumulate](#compression-tree-multiply-accumulate)

The compression tree based arithmetic units are built from a set of components for Booth-encoding, column compression, and parallel prefix adders described in the [`Booth Encoding Multiplier Building Blocks`](./multiplier_components.md#booth-encoding-multiplier-building-blocks) section.

## Carry Save Multiplier

The carry-save multiplier is a digital circuit used for performing multiplication operations. It
is particularly useful in applications that require high speed
multiplication, such as digital signal processing.

The
[`CarrySaveMultiplier`](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySaveMultiplier-class.html)
module in ROHD-HCL accept input parameters the clock `clk` signal,
reset `reset` signal, `Logic`s' a and b as the input pin and the name
of the module `name`. Note that the width of the inputs must be the
same or `RohdHclException` will be thrown.  The output latency is equal to the width of the inputs
given by `latency` on the component.

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
compression tree for reducing addends to a final pair, and a final adder
generated from a parallel prefix tree functor parameter. It is particularly
useful in applications that require high speed and varying width multiplication,
such as digital signal processing.

The parameters of the
[CompressionTreeMultiplier](https://intel.github.io/rohd-hcl/rohd_hcl/CompressionTreeMultiplier-class.html) are:

- Two input terms `a` and `b` which can be different widths.
- The radix used for Booth encoding (2, 4, 8, and 16 are currently supported).
- `seGen` parameter: the type of `PartialProductSignExtension` functor to use which has derived classes for different styles of sign extension. In some cases this adds an extra row to hold a sign bit (default `CompactRectSignExtension` does not).  See [Sign Extension Options](./multiplier_components.md#sign-extension-option).
- Signed or unsigned operands:
  - `signedMultiplicand` parameter: whether the multiplicand (first arg) should be treated as signed (twos' complement) or unsigned.
  - `signedMultiplier` parameter: whether the multiplier (second arg) should be treated as signed (twos' complement) or unsigned.
- As booleans, these parameters satically configure the multiplier to support signed opernads.  Alternatively the multiplier supports runtime control of signage by passing a `Logic` signal instead and control logic will be added to support signed or unsigned operands.
- An optional `clk`, as well as `enable` and `reset` that are used to add a pipestage in the `ColumnCompressor` to allow for pipelined operation, making the multiplier operate in 2 cycles.

Here is an example of use of the `CompressionTreeMultiplier` with one signed input:

```dart
    const widthA = 6;
    const widthB = 9;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);

    a.put(15);
    b.put(3);

    final multiplier =
        CompressionTreeMultiplier(a, b, radix: radix, signedMultiplicand: true);

    final product = multiplier.product;

    print('${product.value.toBigInt()}');
```

## Compression Tree Multiply Accumulate

A compression tree multiply-accumulate is similar to a compress tree
multiplier, but it inserts an additional addend into the compression
tree to allow for accumulation into this third input.

The additional parameters of the
[CompressionTreeMultiplyAccumulate](https://intel.github.io/rohd-hcl/rohd_hcl/CompressionTreeMultiplyAccumulate-class.html) over the [CompressionTreeMltiplier](#compression-tree-multiplier) are:

- The accumulate input term `c` which must have width as sum of the two operand widths + 1.
- Addend signage:
  - `signedAddend` parameter: whether the addend (third argument) should be treated as signed (twos' complement) or unsigned
OR
  - An optional `selectSignedAddend` control signal allows for runtime control of signed or unsigned operation with the same hardware. `signedAddend` must be false if using this control signal.
- An optional `clk`, as well as `enable` and `reset` that are used to add a pipestage in the `ColumnCompressor` to allow for pipelined operation.

The output width of the `CompressionTreeMultiplier` is the sum of the product term widths plus one to accommodate the additional accumulate term.

Here is an example of using the `CompressionTreeMultiplyAccumulate` with all inputs as signed:

```dart
    const widthA = 6;
    const widthB = 9;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB);

    a.put(-15);
    b.put(3);
    c.put(-5);


    final multiplier = CompressionTreeMultiplyAccumulate(a, b, c, radix: radix, signedMultiplicand: true, signedMultiplier: true, signedAddend: true);

    final accumulate = multiplier.accumulate;

    print('${accumulate.value.toBigInt().toSigned(widthA + widthB)}');
```

## Dot Product

The `DotProduct` component is built from multiplier components but rather than instantiating full multipliers for each product and then adding those, it builds a large compression tree of all products and the uses `CompressionTree` to reduce to a pair of addends, and then does the final addition using a provided `adderGen` function (defaulting to `NativeAdder`).

The parameters to the `DotProduct` are two `List<Logic>`s for the multiplicands and multipliers.  The current restriction is that these must all be the same width. The `radix` to encode the partial products is another argument (default = 4).  Finally, two parameters are available to control whether the multiplicands and the multipliers are signed: these parameters can either be `bool` for static generation of signedness, or `Logic` for runtime control. The default, `null` results in an unsigned dot-product component.

Here is an example use of `DotProduct` for a simple depth-2 dot-product computation.

```dart
    const width = 4;
    final multiplicands = [Logic(width: width), Logic(width: width)];
    final multipliers = [Logic(width: width), Logic(width: width)];

    final multiplicandValues = [4, 8];
    final multiplierValues = [2, 3];

    for (var i = 0; i < multiplicands.length; i++) {
      multiplicands[i].put(multiplicandValues[i]);
      multipliers[i].put(multiplierValues[i]);
    }
    final dotProduct = DotProduct(multiplicands, multipliers);

    final dotValue = dotProduct.product;
    // Should be 4*2 + 8*3 = 32
```
