# Fixed-Point Arithmetic

Fixed-point binary representation of numbers is useful several applications including digital signal processing and embedded systems. As a first step towards enabling fixed-point components, we created a new value system [FixedPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FixedPointValue-class.html) similar to [LogicValue](https://intel.github.io/rohd/rohd/LogicValue-class.html).

## FixedPointValue

A [FixedPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FixedPointValue-class.html) represents a signed or unsigned fixed-point value following the Q notation (Qm.n format) as introduced by [Texas Instruments](https://www.ti.com/lit/ug/spru565b/spru565b.pdf). It comprises an optional sign, integer part and/or a fractional part. [FixedPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FixedPointValue-class.html)s can be constructed from individual fields or from a Dart [double](https://api.dart.dev/stable/3.6.0/dart-core/double-class.html), converted to Dart [double](https://api.dart.dev/stable/3.6.0/dart-core/double-class.html), can be compared and can be operated on (+, -, *, /). A `FixedPointValuePopulator` can be used to construct `FixedPointValue` using different kinds of converters.

## FixedPointValue Populator

A `FixedPointValuePopulator` is similar to a builder design pattern that helps populate the components of a `FixedPointValue` predictably across different special subtypes. The general pattern is to call the `populator` static function on a `FixedPointValue` (or special subtype), then subsequently call one of the population methods on the provided populator to receive a completed object.

Included in the `FixedPointValuePopulator` is a `random()` floating-point value generator that can generate `FixedPointValue`s in a constrained range such as

$$lowerBoundFXV < generatedFXV <= upperBoundFXV$$

or

$$lowerBoundFXV <= generatedFXV < upperBoundFXV$$

or any other variants of $<$, $<=$, $>$, and $>=$. An example of its use is

```dart
const m = 4;
const n = 4;
FixedPointValuePopulator populator() => FixedPointValue.populator(signed: true,
        integerWidth: m, fractionWidth: n);

final lt = populator().ofDouble(0.0);
final gt = populator().ofDouble(0.5);
final fxv = populator().random(Random(), lt: lt, gt: gt);
```

This example produces random `FixedPointValue` `fxv`s in the range $0.0 < fxv.toDouble() < 0.5$.

## FixedPoint

The [FixedPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FixedPoint-class.html) type is an extension of [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html) with additional attributes (signed or unsigned, integer width and fraction width). This type is provided to simplify the design of fixed-point arithmetic blocks.  

## FixedToFloat

The [FixedToFloat](https://intel.github.io/rohd-hcl/rohd_hcl/FixedToFloat-class.html) component converts a fixed-point signal to a floating point signal specified by exponent and mantissa width. The output is rounded to the nearest even (RNE) when applicable and set to infinity if the input exceed the representable range.

## FloatToFixed

This component converts a floating-point signal to a signed fixed-point signal. Infinities and NaN's are not supported. The integer and fraction widths are auto-calculated to achieve lossless conversion.

If the `integerWidth` and `fractionWidth` integer and fraction widths are supplied, then lossy conversion is performed to fit the floating-point value into the fixed-point value. For testing, [FixedPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FixedPointValue-class.html) has a `canStore` method to predetermine if a given double can fit.  For execution, [FloatToFixed](https://intel.github.io/rohd-hcl/rohd_hcl/FloatToFixed-class.html) can perform overflow detection by setting a `checkOverflow` option, which is a property of the class and set in the constructor (default is false as it must add significant logic to do the check).

Currently, the FloatToFixed converter, when in lossy mode, is not performing any real rounding (just truncating).

## Float8ToFixed

This component converts an 8-bit floating-point (FP8) representation ([FloatingPoint8E4M3Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E4M3Value-class.html) or [FloatingPoint8E5M2Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E5M2Value-class.html)) to a signed fixed-point representation. This component offers using the same hardware for both FP8 formats. Therefore, both input and output are of type [Logic](https://intel.github.io/rohd/rohd/Logic-class.html) and can be cast from/to floating point/fixed point by the producer/consumer based on the selected `mode`. Infinities and NaN's are not supported. The output width is 33bits to accommodate [FloatingPoint8E5M2Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E5M2Value-class.html) without loss.

## FixedPointSqrt

This component computes the square root of a 3.x fixed-point value, returning a result in the same format. The square root value is rounded to the ordered number of bits. The integral part must be 3 bits, and the fractional part may be any odd value <= 51. Even numbers of bits are currently not supported, integral bits in numbers other than 3 are currently not supported.
