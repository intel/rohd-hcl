# Adder

ROHD HCL provides an adder module to get the sum from a list of logic. As of now, we have

- [Ripple Carry Adder](#ripple-carry-adder)

## Ripple Carry Adder

An ripple carry adder is a digital circuit used for binary addition. It consists of a series of full adders connected in a chain, with the carry output of each adder linked to the carry input of the next one. Starting from the least significant bit (LSB) to most significant bit (MSB), the adder sequentially adds corresponding bits of two binary numbers.

The [`RippleCarryAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/RippleCarryAdder-class.html) module in ROHD-HCL accept input parameters `Logic`s' a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or `RohdHclException` will be thrown.

An example is shown below to multiply two inputs of signals that have 8-bits of width.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final rippleCarryAdder = RippleCarryAdder(a, b);
final sum = rippleCarryAdder.sum;
```
