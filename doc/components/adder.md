# Adder

ROHD-HCL provides a set of adder modules to get the sum from a pair of Logic. As of now, we have

- [Ripple Carry Adder](#ripple-carry-adder)
- [Parallel Prefix Adder](#parallel-prefix-adder)
- [One's Complement Adder Subtractor](#ones-complement-adder-subtractor)
- [Sign Magnitude Adder](#sign-magnitude-adder)
- [Compound Adder](#compound-adder)

## Ripple Carry Adder

A ripple carry adder is a digital circuit used for binary addition. It consists of a series of full adders connected in a chain, with the carry output of each adder linked to the carry input of the next one. Starting from the least significant bit (LSB) to most significant bit (MSB), the adder sequentially adds corresponding bits of two binary numbers.

The [`RippleCarryAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/RippleCarryAdder-class.html) module in ROHD-HCL accept input `Logic`s a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or a `RohdHclException` will be thrown.

An example is shown below to add two inputs of signals that have 8-bits of width.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final rippleCarryAdder = RippleCarryAdder(a, b);
final sum = rippleCarryAdder.sum;
```

## Parallel Prefix Adder

A parallel prefix adder is an adder that uses different varieties of a parallel prefix tree (see `Parallel Prefix Operations`) to efficiently connect a set of `Full Adder` circuits to form a complete adder.

Here is an example of instantiating a `ParallelPrefixAdder`:

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

## One's Complement Adder Subtractor

A ones-complement adder (and subtractor) is useful in efficient arithmetic operations as the
end-around carry can be bypassed and used later.

The `OnesComplementAdder` can take a subtraction command as either a Logic `subtractIn` or a boolean `subtract` (the Logic overrides the boolean).  If Logic `carry` is provided, the end-around carry is output on `carry` and the value will be one less than expected when `carry` is high.  An `adderGen` adder function can be provided that generates your favorite internal adder (such as a parallel prefix adder).

The output of `OnesComplementAdder` is a `sum` which is the magnitude and a `sign`.

Here is an example of instantiating a `OnesComplementAdder` as a subtractor, but saving the `carry`:

```dart
    const width = 4;
    final a = Logic(width: width);
    final b = Logic(width: width);

    a.put(av);
    b.put(bv);
    final carry = Logic();
    final adder = OnesComplementAdder(
        a, b, carryOut: carry, adderGen: RippleCarryAdder.new,
        subtract: true);
    final mag = adder.sum.value.toInt() + (carry.value.isZero ? 0 : 1));
    final out = (adder.sign.value.toInt() == 1 ? -mag : mag);
```

## Sign Magnitude Adder

A sign magnitude adder is useful in situations where the sign of the addends is separated from their magnitude (e.g., not 2s complement), such as in floating point multipliers.  The `SignMagnitudeAdder` inherits from `Adder` but adds the `Logic` inputs for the two operands.

If you can supply the largest magnitude number first, then you can disable a comparator generation inside by declaring the `largestMagnitudeFirst` option as true.

The `SignMagnitudeAdder` uses a `OnesComplementAdder` internally.

Here is an example of instantiating a `SignMagnitudeAdder`:

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

    final adder = SignMagnitudeAdder(aSign, a, bSign, b, adderGen: RippleCarryAdder.new,
        largestMagnitudeFirst: true);

    final sum = adder.sum;

    print('${sum.value.toBigInt()}');
```

## Compound Adder

A compound carry adder is a digital circuit used for binary addition. It produces sum and sum+1 outputs.
A trivial compound adder component `TrivialCompoundAdder` doesnt use any RTL code optimization.
Carry-select adder-based compound adder `CarrySelectCompoundAdder` uses carry-select adder as a basis. Like a carry-select adder it consists of a multiple blocks of two ripple-carry adders <https://en.wikipedia.org/wiki/Carry-select_adder>. But the first block has two ripple-carry adders and two separate carry-propagate chains are used to select sum and sum+1 output bits. sum selecting chain starts from carry input 'zero' driven block and sum+1 selecting chain starts from carry input 'one' driven block.
The delay of the adder is defined by combination ripple-carry adder and accumulated carry-select chain delay.

The `CarrySelectCompoundAdder` module in ROHD-HCL accept input `Logic`s a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or a `RohdHclException` will be thrown.
Compound adder generator provides two alogithms for splitting adder into ripple-carry blocks. `CarrySelectCompoundAdder.splitSelectAdderAlgorithm4Bit` algoritm splits adder into blocks of 4-bit ripple-carry adders with the first one width adjusted down. `CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock` algorithm generates only one block of full bitwidth of the adder. Input List\<int\> Function(int adderFullWidth) `widthGen` should be used to specify custom adder splitting algorithm that return a list of sub-adders width. The default one is `CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock`.

An example is shown below to add two inputs of signals that have 8-bits of width.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final rippleCarryAdder = CarrySelectCompoundAdder(a, b);
final sum = rippleCarryAdder.sum;
final sum1 = rippleCarryAdder.sum1;

final rippleCarryAdder4BitBlock = CarrySelectCompoundAdder(a, b,
        widthGen: CarrySelectCompoundAdder.splitSelectAdderAlgorithm4Bit);
```
