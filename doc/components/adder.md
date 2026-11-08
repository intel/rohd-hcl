# Adders

ROHD-HCL provides a set of adder modules to get the sum from a pair of Logic.
Some adders provide an optional carry input provided in the base class of
[Adder](https://intel.github.io/rohd-hcl/rohd_hcl/Adder-class.html). As of now,
ROHD-HCL supplies:

- [Ripple Carry Adder](#ripple-carry-adder)
- [Parallel Prefix Adder](#parallel-prefix-adder)
- [Ones' Complement Adder Subtractor](#ones-complement-adder-subtractor)
- [Sign Magnitude Adder](#sign-magnitude-adder)
- [Compound Adder](#compound-adder)
- [Native Adder](#native-adder)

## Ripple Carry Adder

A ripple carry adder is a digital circuit used for binary addition. It consists
of a series of
[FullAdder](https://intel.github.io/rohd-hcl/rohd_hcl/FullAdder-class.html)s
connected in a chain, with the carry output of each adder linked to the carry
input of the next one. Starting from the least significant bit (LSB) to most
significant bit (MSB), the adder sequentially adds corresponding bits of two
binary numbers.

The [adder](https://intel.github.io/rohd-hcl/rohd_hcl/Adder-class.html) module
in ROHD-HCL accept input `Logic`s a and b as the input pin and the name of the
module `name`. Note that the width of the inputs must be the same or a
[RohdHclException](https://intel.github.io/rohd-hcl/rohd_hcl/RohdHclException-class.html)
will be thrown.

An example is shown below to add two inputs of signals that have 8-bits of
width.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final adder = RippleCarryAdder(a, b);
final sum = adder.sum;
```

## Parallel Prefix Adder

A parallel prefix adder is an adder that uses different varieties of a parallel
prefix tree (see [Parallel Prefix
Operations](../components/parallel_prefix_operations.md)) to efficiently connect
a set of `Full Adder` circuits to form a complete adder.

Here is an example of instantiating a
[ParallelPrefixAdder](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixAdder-class.html)
:

```dart
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    a.put(18);
    b.put(24);

    final adder = ParallelPrefixAdder(a, b, ppGen: BrentKung.new);

    final sum = adder.sum;

    print('${sum.value.toBigInt()}');
```

Prefix adders retain carry-generation and carry-propagation signals as
`GeneratePropagate` records through every prefix node, rather than concatenating
and indexing two-bit vectors. The external operands, carry input, sum width, and
combinational timing are unchanged. Custom `ParallelPrefixAdder.ppGen` callbacks
must accept and return this record type; see [typed prefix
networks](parallel_prefix_operations.md#adder-generator-migration).

## Ones' Complement Adder Subtractor

A ones'-complement adder (and subtractor) is useful in efficient arithmetic
operations as the end-around carry can be bypassed and used later.

The
[OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html)
accepts `subtract` as a `StaticOrRuntimeParameter` containing a static boolean
or one-bit runtime `Logic`. The deprecated `subtractIn` argument remains for
compatibility; use `subtract` for new code. If `generateEndAroundCarry` is true,
the end-around carry is output on `endAroundCarry` instead of being added to the
sum. An `adderGen` function can provide the internal adder.

The output of
[OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html)
is a `sum` which is the magnitude, an optional `endAroundCarry` and a `sign`.

Here is an example of instantiating a
[OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html)
as a subtractor, but saving the `endAroundCarry`:

```dart
    const width = 4;
    final a = Logic(width: width);
    final b = Logic(width: width);

    a.put(7);
    b.put(3);
    final adder = OnesComplementAdder(
        a, b, generateEndAroundCarry: true, adderGen: NativeAdder.new,
        subtract: StaticOrRuntimeParameter.staticValue(value: true));
    final mag = adder.sum.value.toInt() +
        (adder.endAroundCarry!.value.isZero ? 0 : 1);
    final out = (adder.sign.value.toInt() == 1 ? -mag : mag);
```

## Sign Magnitude Adder

A sign magnitude adder is useful in situations where the sign of the addends is
separated from their magnitude (e.g., not twos' complement), such as in floating
point adders.  The
[SignMagnitudeAdder](https://intel.github.io/rohd-hcl/rohd_hcl/SignMagnitudeAdder-class.html)
inherits from `Adder` but adds the `Logic` inputs for the two operands.

If you can supply the largest magnitude number first, then you can disable a
comparator generation inside by declaring the `largestMagnitudeFirst` option as
true. Otherwise, the component will first sort the inputs.

The
[SignMagnitudeAdder](https://intel.github.io/rohd-hcl/rohd_hcl/SignMagnitudeAdder-class.html)
uses a
[OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html)
internally. An optional `carryIn` can inject an additional carry into the
magnitude computation, for example, a rounding increment from discarded bits.

Here is an example of instantiating a
[SignMagnitudeAdder](https://intel.github.io/rohd-hcl/rohd_hcl/SignMagnitudeAdder-class.html):

```dart
    const width = 6;
    final aSign = Logic(name: 'aSign');
    final a = Logic(name: 'a', width: width);
    final bSign = Logic(name: 'bSign');
    final b = Logic(name: 'b', width: width);

    aSign.put(1);
    a.put(24);
    b.put(18);
    bSign.put(0);

    final adder = SignMagnitudeAdder(aSign, a, bSign, b, adderGen: NativeAdder.new,
        largestMagnitudeFirst: true);

    final sum = adder.sum;

    print('${sum.value.toBigInt()}');
```

A variant provided is `SignMagnitudeDualAdder` which does not require sorting
and simply runs two subtractions in parallel, choosing the one that yields the
magnitude and correct sign.

## Compound Adder

A compound carry adder is a digital circuit used for binary addition. It
efficiently produces both sum and sum+1 outputs. A trivial compound adder
component
[TrivialCompoundAdder](https://intel.github.io/rohd-hcl/rohd_hcl/TrivialCompoundAdder-class.html)
doesn't use any RTL code optimization, and uses the native '+' operation. The
[`CarrySelectCompoundAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySelectCompoundAdder-class.html)
uses a carry-select adder as a basis. Like a carry-select adder it consists of a
multiple blocks of two parallel adders
<https://en.wikipedia.org/wiki/Carry-select_adder>. The first block has two
adders and two separate carry-propagate chains are used to select sum and sum+1
output bits. The sum selecting chain starts from the carry input 0 driven block
and sum+1 selecting chain starts from the carry input 1 driven block. The delay
of the adder is defined by the combination of the sub-adders and the accumulated
carry-select chain delay.

The
[CarrySelectCompoundAdder](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySelectCompoundAdder-class.html)
module in ROHD-HCL accepts input `Logic`s a and b as the input pin and the name
of the module `name`. Note that the width of the inputs must be the same or a
[RohdHclException](https://intel.github.io/rohd-hcl/rohd_hcl/RohdHclException-class.html)
will be thrown.

The compound adder forms a select chain around a set of adders specified by:

- `adderGen`: an adder generator for the block adders. The default constructs a
  `ParallelPrefixAdder`. Its signature is:

```dart
(Logic a, Logic b, {Logic? carryIn, StaticOrRuntimeParameter? subtract, String name = ''}) => Adder
```

`subtract` is a static-or-runtime boolean control forwarded to each block. The
`subtractIn` constructor argument remains available as a legacy runtime input,
but custom `adderGen` callbacks must accept `subtract`.

- `widthGen` selects the block widths:
  - The `CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit` algorithm
    splits the adder into blocks of n-bit adders with the first one width
    adjusted down.
  - The
    [CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySelectCompoundAdder/splitSelectAdderAlgorithmSingleBlock.html)
    algorithm generates only one sub-block with the full bit-width of the adder.

An example is shown below of using the `CarrySelectCompoundAdder` to add 2 8-bit
numbers splitting at bit position 4.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final adder = CarrySelectCompoundAdder(a, b);
final sum = adder.sum;
final sum1 = adder.sumP1;

final adder4BitBlock = CarrySelectCompoundAdder(a, b,
        widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
```

## Carry Select Ones Complement Compound Adder

ROHD-HCL has an implementation of a `CompoundAdder` that uses a `OnesComplement`
adder to produce sum and sum plus one including for subtraction using
ones-complement.

By providing `outputCarryOut` and/or `outputCarryOutP1` settings, the outputs
`carryOut` and `carryOutP1` are provided which also ensures the adder does not
convert to 2s complement but instead does the efficient 1s complement subtract
(or add) and provides the end-around carry as an output.  Otherwise, the adder
will add back the end-around carry to the result to convert back to 2s
complement.  A `sign` and `signP1` is also output for the result.

The `subtract` option accepts a `StaticOrRuntimeParameter` for static or runtime
control. The deprecated `subtractIn` argument is retained for compatibility; use
`subtract` for new code.

```dart
    final adder = CarrySelectOnesComplementCompoundAdder(a, b,
          subtract: StaticOrRuntimeParameter.runtime(doSubtract, name: 'subtract'),
          generateCarryOut: true,
          generateCarryOutP1: true,
          widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
    final carryOut = adder.carryOut;
    final carryOutP1 = adder.carryOutP1;
    final sum = adder.sum;
    final sumP1 = adder.sumP1;
```

## Native Adder

As logic synthesis can replace a '+' in RTL with a wide variety of adder
architectures on its own, we have a `NativeAdder` wrapper class that allows you
to use the native '+' with any component that exposes an `Adder` functor as a
parameter:

```dart
final a = FloatingPoint32();
final b = FloatingPoint32();
final adder = FloatingPointAdderSinglePath(a, b, adderGen: NativeAdder.new);
```

`FloatingPointAdderSinglePath` defaults to `NativeAdder`. Its `widthGen` can
also configure the block splitting used by its internal compound adder.
