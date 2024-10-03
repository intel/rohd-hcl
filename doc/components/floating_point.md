# Floating-Point Components

Floating-point operations require meticulous precision, and have standards like [IEEE-754](<https://standards.ieee.org/ieee/754/6210/>) which govern them.  To support floating-point components, we have created a parallel to `Logic`/`LogicValue` which are part of [ROHD](<https://intel.github.io/rohd-website/>). Here, `FloatingPoint` is the `Logic` wire in a component that carries `FloatingPointValue` literal values. An important distinction is that these classes are parameterized to create arbitrary size floating-point values.

## FloatingPointValue

The `FloatingPointValue` class comprises the sign, exponent, and mantissa `LogicValue`s that represent a floating-point number. `FloatingPointValue`s can be converted to and from Dart native `Double`s, as well as constructed from integer and string representations of their fields.  They can be operated on (+, -, *, /) and compared.

A `FloatingPointValue` has a mantissa in $[0,2)$ with

$$0 <= exponent <= maxExponent$$

A normal `isNormal` `FloatingPointValue` has:

$$minExponent <= exponent <= maxExponent$$

 And a mantissa in the range of $[1,2)$.  Subnormal numbers are represented with a zero exponent and leading zeros in the mantissa capture the negative exponent value.

The various IEEE constants representing corner cases of the field of floating-point values for a given size of `FloatingPointValue`: infinities, zeros, limits for normal (e.g. mantissa in the range of $[1,2])$ and sub-normal numbers (zero exponent, and mantissa <1).

Appropriate string representations, comparison operations, and operators are available.  The usefulness of `FloatingPointValue` is in the testing of `FloatingPoint` components, where we can leverage the abstraction of a floating-point value type to drive and compare floating-point values operated upon by floating-point components.

As 32-bit single precision and 64-bit double-precision floating-point types are most common, we have `FloatingPoint32Value` and `FloatingPoint64Value` subclasses with direct converters from Dart native Double.

Finally, we have a `FloatingPointValue` random generator for testing purposes, generating valid floating-point types, optionally constrained to normal range (mantissa in $[1, 2)$).

## FloatingPoint

The `FloatingPoint` type is a `LogicStructure` which comprises the `Logic` bits for the sign, exponent, and mantissa used in hardware floating-point.  These types are provided to simplify and abstract the declaration and manipulation of floating-point types in hardware.  This type is parameterized like `FloatingPointValue`, for exponent and mantissa width.

Again, like `FloatingPointValue`, `FloatingPoint64` and `FloatingPoint32` subclasses are provided as these are the most common floating-point number types.

## FloatingPointAdder

A very basic `FloatingPointAdder` component is available which does not perform any rounding. It takes two `FloatingPoint` `LogicStructure`s and adds them, returning a normalized `FloatingPoint` on the output.  An option on input is the type of `ParallelPrefixTree` used in the internal addition of the mantissas.

Currently, the `FloatingPointAdder` is close in accuracy (as it has no rounding) and is not optimized for circuit performance, but only provides the key functionalities of alignment, addition, and normalization.  Still, this component is a starting point for more realistic floating-point components that leverage the logical `FloatingPoint` and literal `FloatingPointValue` type abstractions.
