# Adder

ROHD HCL provides a set of adder modules to get the sum from a list of logic. As of now, we have

- [Ripple Carry Adder](#ripple-carry-adder)
- [Parallel Prefix Adder](#parallel-prefix-adder)
- [Sign Magnitude Adder](#sign-magnitude-adder)

## Ripple Carry Adder

A ripple carry adder is a digital circuit used for binary addition. It consists of a series of full adders connected in a chain, with the carry output of each adder linked to the carry input of the next one. Starting from the least significant bit (LSB) to most significant bit (MSB), the adder sequentially adds corresponding bits of two binary numbers.

The [`RippleCarryAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/RippleCarryAdder-class.html) module in ROHD-HCL accept input  `Logic`s a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or a `RohdHclException` will be thrown.

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

A parallel prefix adder is an adder that uses n instance of a parallel prefix tree (see `Parallel Prefix Operations`) to efficiently connect a set of `Full Adder` circuits to form a complete adder.

Here is an example of instantiating a `ParallelPrefixAdder`:

```dart
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);

    a.put(18);
    b.put(24);

    final adder = ParallelPrefixAdder(a, b, BrentKung.new);

    final sum = adder.sum;

    print('${sum.value.toBigInt()}');
```

## Sign Magnitude Adder

A sign magnitude adder is useful in situations where the sign of the addends is seperated from their magnitude (e.g., not 2s complement), such as in floating point multipliers.  The `SignMagnitudeAdder` inherits from `Adder` but adds the `Logic` inputs for the two operands.

If you can supply the largest magnitude number first, then you can disable a comparator generation inside by declaring the  `largestMagnitudeFirst` option as true.

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

    final adder = SignMagnitudeAdder(aSign, a, bSign, b, RippleCarryAdder.new,
        largestMagnitudeFirst: true);

    final sum = adder.sum;

    print('${sum.value.toBigInt()}');
```
