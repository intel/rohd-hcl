# Adders

ROHD-HCL provides a set of adder modules to get the sum from a pair of Logic. Some adders provide an optional carry input provided in the base class of [Adder](https://intel.github.io/rohd-hcl/rohd_hcl/Adder-class.html). As of now, ROHD-HCL supplies:

- [Ripple Carry Adder](#ripple-carry-adder)
- [Parallel Prefix Adder](#parallel-prefix-adder)
- [Ones' Complement Adder Subtractor](#ones-complement-adder-subtractor)
- [Sign Magnitude Adder](#sign-magnitude-adder)
- [Compound Adder](#compound-adder)
- [Native Adder](#native-adder)

## Ripple Carry Adder

A ripple carry adder is a digital circuit used for binary addition. It consists of a series of  [FullAdder](https://intel.github.io/rohd-hcl/rohd_hcl/FullAdder-class.html)s connected in a chain, with the carry output of each adder linked to the carry input of the next one. Starting from the least significant bit (LSB) to most significant bit (MSB), the adder sequentially adds corresponding bits of two binary numbers.

The [adder](https://intel.github.io/rohd-hcl/rohd_hcl/Adder-class.html) module in ROHD-HCL accept input `Logic`s a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or a [RohdHclException](https://intel.github.io/rohd-hcl/rohd_hcl/RohdHclException-class.html) will be thrown.

An example is shown below to add two inputs of signals that have 8-bits of width.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final adder = adder(a, b);
final sum = adder.sum;
```

## Parallel Prefix Adder

A parallel prefix adder is an adder that uses different varieties of a parallel prefix tree (see [Parallel Prefix Operations](../components/parallel_prefix_operations.md)) to efficiently connect a set of `Full Adder` circuits to form a complete adder.

Here is an example of instantiating a [ParallelPrefixAdder](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefixAdder-class.html) :

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

## Ones' Complement Adder Subtractor

A ones'-complement adder (and subtractor) is useful in efficient arithmetic operations as the
end-around carry can be bypassed and used later.

The [OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html) can take a subtraction command as either a `Logic` `subtractIn` or a boolean `subtract` (the Logic overrides the boolean).  If Logic `carry` is provided, the end-around carry is output on `carry` and the value will be one less than expected when `carry` is high.  An `adderGen` adder function can be provided that generates your favorite internal adder (such as a parallel prefix adder).

The output of  [OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html) is a `sum` which is the magnitude and a `sign`.

Here is an example of instantiating a  [OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html) as a subtractor, but saving the `carry`:

```dart
    const width = 4;
    final a = Logic(width: width);
    final b = Logic(width: width);

    a.put(av);
    b.put(bv);
    final carry = Logic();
    final adder = OnesComplementAdder(
        a, b, carryOut: carry, adderGen: adder.new,
        subtract: true);
    final mag = adder.sum.value.toInt() + (carry.value.isZero ? 0 : 1));
    final out = (adder.sign.value.toInt() == 1 ? -mag : mag);
```

## Sign Magnitude Adder

A sign magnitude adder is useful in situations where the sign of the addends is separated from their magnitude (e.g., not twos' complement), such as in floating point multipliers.  The [SignMagnitudeAdder](https://intel.github.io/rohd-hcl/rohd_hcl/SignMagnitudeAdder-class.html) inherits from `Adder` but adds the `Logic` inputs for the two operands.

If you can supply the largest magnitude number first, then you can disable a comparator generation inside by declaring the `largestMagnitudeFirst` option as true.

The [SignMagnitudeAdder](https://intel.github.io/rohd-hcl/rohd_hcl/SignMagnitudeAdder-class.html) uses a [OnesComplementAdder](https://intel.github.io/rohd-hcl/rohd_hcl/OnesComplementAdder-class.html) internally.

Here is an example of instantiating a [SignMagnitudeAdder](https://intel.github.io/rohd-hcl/rohd_hcl/SignMagnitudeAdder-class.html):

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

    final adder = SignMagnitudeAdder(aSign, a, bSign, b, adderGen: adder.new,
        largestMagnitudeFirst: true);

    final sum = adder.sum;

    print('${sum.value.toBigInt()}');
```

## Compound Adder

A compound carry adder is a digital circuit used for binary addition. It efficiently produces both sum and sum+1 outputs.
A trivial compound adder component [TrivialCompoundAdder](https://intel.github.io/rohd-hcl/rohd_hcl/TrivialCompoundAdder-class.html) doesn't use any RTL code optimization, and uses the native '+' operation.
The [`CarrySelectCompoundAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySelectCompoundAdder-class.html) uses a carry-select adder as a basis. Like a carry-select adder it consists of a multiple blocks of two parallel adders <https://en.wikipedia.org/wiki/Carry-select_adder>. The first block has two adders and two separate carry-propagate chains are used to select sum and sum+1 output bits. The sum selecting chain starts from the carry input 0 driven block and sum+1 selecting chain starts from the carry input 1 driven block.
The delay of the adder is defined by the combination of the sub-adders and the accumulated carry-select chain delay.

The [CarrySelectCompoundAdder](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySelectCompoundAdder-class.html) module in ROHD-HCL accepts input `Logic`s a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or a [RohdHclException](https://intel.github.io/rohd-hcl/rohd_hcl/RohdHclException-class.html) will be thrown.

The compound adder forms a select chain around a set of adders specified by:

- `adderGen`: an adder generator functor option to build the block adders with the default being a closure returning a functor returning `ParallelPrefixAdder`.  This functor has the signature: This functor has the signature:  

```dart
(Logic a, Logic b, {Logic? carryIn, Logic? subtractIn, String name = ''})=> Adder
```

```dart
(Logic a, Logic b, {Logic? carryIn, Logic? subtractIn, String name = ''}) => Adder
```

- `splitSelectAdderAlgorithmSingleBlock:
  - The `CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit` algorithm splits the adder into blocks of n-bit adders with the first one width adjusted down.
  - The [CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySelectCompoundAdder/splitSelectAdderAlgorithmSingleBlock.html) algorithm generates only one sub-block with the full bit-width of the adder.

An example is shown below of using the `CarrySelectCompoundAdder` to add 2 8-bit numbers splitting at bit position 4.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final adder = CarrySelectCompoundAdder(a, b);
final sum = adder.sum;
final sum1 = adder.sum1;

final adder4BitBlock = CarrySelectCompoundAdder(a, b,
        widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
```

## Carry Select Ones Complement Compound Adder

ROHD-HCL has an implementation of a `CompoundAdder` that uses a `OnesComplement` adder to produce sum and sum plus one including for subtraction using ones-complement.

By providing optional outputs `carryOut` and `carryOutP1`, the user can ensure the adder does not convert to 2s complement but instead does the efficient 1s complement add (or subtract) and provides the end-around carry as an output.  Otherwise, the adder will add back the end-around carry to the result to convert back to 2s complement.  A sign is also output for the result.

Both Logic control and boolean control are provided for enabling subtraction.

```dart
    final carryOut = Logic();
    final carryOutP1 = Logic();
    final adder = CarrySelectOnesComplementCompoundAdder(a, b,
          subtract: doSubtract,
          carryOut: carryOut,
          carryOutP1: carryOutP1,
          widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
        widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
```

## Compound Ones Complement Adder

ROHD-HCL has an implementation of a `CompoundAdder` that uses a `OnesComplement` adder to produce sum and sum plus one including for subtraction using ones-complement.

By providing optional outputs `carryOut` and `carryOutP1`, the user can ensure the adder does not convert to 2s complement but instead does the efficient 1s complement add (or subtract) and provides the end-around carry as an output.  Otherwise, the adder will add back the end-around carry to the result to convert back to 2s complement.  A sign is also output for the result.

Both Logic control and boolean control are provided for enabling subtraction.

```dart
    final carryOut = Logic();
    final carryOutP1 = Logic();
    final adder = CarrySelectOnesComplementCompoundAdder(a, b,
          subtract: doSubtract,
          carryOut: carryOut,
          carryOutP1: carryOutP1,
          widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(4));
```

## Native Adder

As logic synthesis can replace a '+' in RTL with a wide variety of adder architectures on its own, we have a `NativeAdder` wrapper class that allows you to use the native '+' with any component that exposes an `Adder` functor as a parameter:

```dart
// API definition: FloatingPointAdderRound(super.a, super.b,
//       {Logic? subtract,
//       super.clk,
//       super.reset,
//       super.enable,
//       Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
//           ParallelPrefixAdder.new,
//       ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
//           ppTree = KoggeStone.new,
//       super.name = 'floating_point_adder_round'})

// Instantiate with a NativeAdder as the internal adder
final adder = FloatingPointAdderRound(a, b, adderGen: NativeAdder.new);
```
