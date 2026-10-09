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
[MultiplyAccumulate](https://intel.github.io/rohd-hcl/rohd_hcl/MultiplyAccumulate-class.html)
module which multiplies two numbers represented as `Logic`s and adds the
result to a third `Logic` addend. Its default output width is the sum of the
input operand widths plus one; `outputWidth` can select another width.
`GenericMultiplyAccumulate` supports a `c` addend of arbitrary width, while
`CompressionTreeMultiplyAccumulate` requires `c` to be `a.width + b.width + 1`
bits wide. Similar to `Multiplier`, operand signedness can be configured
statically or selected at runtime.

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

A compression tree multiply-accumulate is similar to a compression tree
multiplier, but it inserts an additional addend into the compression
tree to allow for accumulation into this third input.

The additional parameters of the
[CompressionTreeMultiplyAccumulate](https://intel.github.io/rohd-hcl/rohd_hcl/CompressionTreeMultiplyAccumulate-class.html) over the [CompressionTreeMultiplier](#compression-tree-multiplier) are:

- The accumulate input term `c` which must have width as sum of the two operand widths + 1.
- Addend signage:
  - `signedAddend` parameter: whether the addend (third argument) should be treated as signed (twos' complement) or unsigned
OR
  - An optional `selectSignedAddend` control signal allows for runtime control of signed or unsigned operation with the same hardware. `signedAddend` must be false if using this control signal.
- An optional `clk`, as well as `enable` and `reset` that are used to add a pipestage in the `ColumnCompressor` to allow for pipelined operation.

The default output width is the sum of the operand widths plus one to
accommodate the additional accumulate term.

Here is an example of using the `CompressionTreeMultiplyAccumulate` with all inputs as signed:

```dart
    const widthA = 6;
    const widthB = 9;
    const radix = 8;
    final a = Logic(name: 'a', width: widthA);
    final b = Logic(name: 'b', width: widthB);
    final c = Logic(name: 'c', width: widthA + widthB + 1);

    a.put(-15);
    b.put(3);
    c.put(-5);


    final multiplier = CompressionTreeMultiplyAccumulate(a, b, c, radix: radix, signedMultiplicand: true, signedMultiplier: true, signedAddend: true);

    final accumulate = multiplier.accumulate;

    print('${accumulate.value.toBigInt().toSigned(widthA + widthB + 1)}');
```

## Generic Multiply-Accumulate

`GenericMultiplyAccumulate` composes a selected multiplier generator with a
separately selected adder generator. Unlike the fused compression-tree MAC,
this provides flexibility to use a native, compression-tree, or custom
multiplier strategy, at the cost of a separate multiplication and addition
path. It also supports an addend `c` wider than the product without discarding
its upper bits internally.

The optional `outputWidth` sets the `accumulate` output width. It defaults to
`a.width + b.width + 1`; narrower outputs keep the low bits, while wider
outputs extend according to the result signedness. Select a width sufficient
for the desired range, especially when `c` is wider than the product.
`multiplierIdentity` and `adderIdentity` should be supplied when custom
generators need distinct automatic HDL definition names.

```dart
final mac = GenericMultiplyAccumulate(
  a,
  b,
  c,
  NativeMultiplier.new,
  signedMultiplicand: true,
  signedMultiplier: true,
  signedAddend: true,
  outputWidth: 24,
);
```

## Dot Product

ROHD-HCL provides `CompressionTreeDotProduct` and `GeneralDotProduct`.
`CompressionTreeDotProduct` combines every multiply's partial products into
one column-compression tree and requires equal multiplicand and multiplier
widths. `GeneralDotProduct` instantiates a selected multiplier per lane and
uses a balanced `ReductionTree` for lossless accumulation.

Both components accept two equal-length `List<Logic>` operand vectors. Every
multiplicand must have one common width and every multiplier must have one
common width. The two common widths may differ when using `GeneralDotProduct`
with a multiplier generator that supports mixed widths, such as
`CompressionTreeMultiplier`. `CompressionTreeDotProduct` retains its
equal-width requirement because its fused partial-product matrix assumes a
common lane geometry.

Signedness for each operand vector can be a static `bool` or runtime 1-bit
`Logic`. Static values are passed to child multipliers as static
configuration; runtime values are passed as internal module inputs. The
accumulated output widens by one bit at each reduction level as required to
preserve the lossless sum.

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
    final dotProduct = GeneralDotProduct(multiplicands, multipliers);

    final dotValue = dotProduct.product;
    // Should be 4*2 + 8*3 = 32
```
