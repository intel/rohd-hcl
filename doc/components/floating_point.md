# Floating-Point Components

Floating-point operations require meticulous precision, and have standards like [IEEE-754](<https://standards.ieee.org/ieee/754/6210/>) which govern them.  To support floating-point components, we have created a parallel to [Logic](https://intel.github.io/rohd/rohd/Logic-class.html)/[LogicValue](https://intel.github.io/rohd/rohd/LogicValue-class.html) which are part of [ROHD](<https://intel.github.io/rohd-website/>). Here, [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) is the [Logic](https://intel.github.io/rohd/rohd/Logic-class.html) wire in a component that carries [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) literal values, a subclass of [LogicValue](https://intel.github.io/rohd/rohd/LogicValue-class.html). An important distinction is that these classes are parameterized to create arbitrary size floating-point values.

## FloatingPointValue

The [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) class comprises the sign, exponent, and mantissa [LogicValue](https://intel.github.io/rohd/rohd/LogicValue-class.html)s that represent a floating-point number. [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html)s can be converted to and from Dart native [Double](https://api.dart.dev/stable/3.6.0/dart-core/double-class.html)s, as well as constructed from integer and string representations of their fields.  They can be operated on (+, -, *, /) and compared. This is useful for helping validate [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) logic components.

A [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) has a mantissa in $[0,2)$ with

$$0 <= exponent <= maxExponent$$

A normal `isNormal` [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) has:

$$minExponent <= exponent <= maxExponent$$

 And a mantissa in the range of $[1,2)$.  Subnormal numbers are represented with a zero exponent and leading zeros in the mantissa capture the negative exponent value.

Conversions from the native `double` are supported, both in rounded and unrounded forms.  This is quite useful in testing narrower width floating point components leveraging the `double` native operations for validation.

Appropriate string representations, comparison operations, and operators are available.  The usefulness of  [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) is in the testing of [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) components, where we can leverage the abstraction of a floating-point value type to drive and compare floating-point values operated upon by floating-point components.

### Floating Point Constants

The various IEEE constants representing corner cases of the field of floating-point values for a given size of [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html): infinities, zeros, limits for normal (e.g. mantissa in the range of $[1,2)$ and sub-normal numbers (zero exponent, and mantissa <1).

For any basic arbitrary width `FloatingPointValue` ROHD-HCL supports the following constants in that format.

- `negativeInfinity`: smallest possible number
- `negativeZero`: The number zero, negative form
- `positiveZero`: The number zero, positive form
- `smallestPositiveSubnormal`: Smallest possible number, most exponent negative, LSB set in mantissa
- `largestPositiveSubnormal`: Largest possible subnormal, most negative exponent, mantissa all 1s
- `smallestPositiveNormal`: Smallest possible positive number, most negative exponent, mantissa is 0
- `largestLessThanOne`: Largest number smaller than one
- `one`: The number one
- `smallestLargerThanOne`: Smallest number greater than one
- `largestNormal`: Largest positive number, most positive exponent, full mantissa
- `infinity`: Largest possible number:  all 1s in the exponent, all 0s in the mantissa
- `nan`:  Not a Number, demarked by all 1s in exponent and any 1 in mantissa (we use the LSB)

### Special subtypes

As 64-bit double-precision and 32-bit single-precision floating-point types are most common, we have [FloatingPoint32Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint32Value-class.html) and [FloatingPoint64Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint64Value-class.html) subclasses with direct converters from Dart native [Double](https://api.dart.dev/stable/3.6.0/dart-core/double-class.html).

Other special widths of floating-point values supported are:

- [FloatingPoint16Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint16Value-class.html)
- [FloatingPoint8E4M3Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E4M3Value-class.html)
- [FloatingPoint8E5M2Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E5M2Value-class.html)
- [FloatingPointBF16Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointBF16Value-class.html)
- [FloatingPointTF32Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointTF32Value-class.html)

Finally, we have a [random value constructor](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue/FloatingPointValue.random.html) generator for testing purposes, generating valid [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) types, optionally constrained to normal range (mantissa in $[1, 2)$).

## FloatingPoint

The [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) type is a [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html) which comprises the [Logic](https://intel.github.io/rohd/rohd/Logic-class.html) bits for the sign, exponent, and mantissa used in hardware floating-point.  This type is provided to simplify and abstract the declaration and manipulation of floating-point bits in hardware.  This type is parameterized like [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html), for exponent and mantissa width.

Again, like  [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html), [FloatingPoint64](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint64-class.html) and [FloatingPoint32](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint32-class.html) subclasses are provided as these are the most common floating-point number types.

## FloatingPointAdder

A very basic [FloatingPointAdderSimple](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointAdderSimple-class.html) component is available which does not perform any rounding. It takes two [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html)s and adds them, returning a normalized [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) on the output.  An option on input is the type of ['ParallelPrefix'](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefix-class.html) used in the critical internal addition of the mantissas.

Currently, the [FloatingPointAdderSimple](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointAdderSimple-class.html) is close in accuracy (as it has no rounding) and is not optimized for circuit performance, but only provides the key functionalities of alignment, addition, and normalization.  Still, this component is a starting point for more realistic floating-point components that leverage the logical [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) and literal [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) type abstractions.

A second [FloatingPointAdderRound](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointAdderRound-class.html) component is available which does perform rounding.  It is based on "Delay-Optimized Implementation of IEEE Floating-Point Addition", by Peter-Michael Seidel and Guy Even, using an R-path and an N-path to process far-apart exponents and use rounding and an N-path for exponents within 2 and subtraction, which is exact.  If you pass in an optional clock, a pipestage will be added to help optimize frequency; an optional reset and enable are can control the pipestage.

## FloatingPointMultiplier

A very basic [FloatingPointMultiplierSimple] component is available which does not perform any rounding. It takes two [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html)s and multiplies them, returning a normalized [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) on the output 'product'.  

It has options to control its performance:

- 'radix':  used to specify the radix of the Booth encoder (default radix=4: options are [2,4,8,16])'.
- adderGen':  used to specify the kind of [Adder] used for key functions like the mantissa addition. Defaults to [NativeAdder], but you can select a [ParallelPrefixAdder] of  your choice.
- 'ppTree':  used to specify the type of ['ParallelPrefix'](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefix-class.html) used in the pther critical functions like leading-one detect.
