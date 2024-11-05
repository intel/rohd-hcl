# Fixed-Point Arithmetic

Fixed-point binary representation of numbers is useful several applications including digital signal processing and embedded systems. As a first step towards enabling fixed-point components, we created a new value system `FixedPointValue` similar to `LogicValue`.

## FixedPointValue

A `FixedPointValue` represents a signed or unsigned fixed-point value following the Q notation (Qm.n format) as introduced by [Texas Instruments](https://www.ti.com/lit/ug/spru565b/spru565b.pdf). It comprises an optional sign, integer part and/or a fractional part. `FixedPointValue`s can be constructed from individual fields or from a Dart `double`, converted to Dart `double`, can be compared and can be operated on (+, -, *, /).

## FixedPoint

The `FixedPoint` type is an extension of `Logic` with additional attributes (signed or unsigned, integer width and fraction width). This type is provided to simplify the design of fixed-point arithmetic blocks.

## FixedToFloat

This component converts a fixed-point signal to a floating point signal specified by exponent and mantissa width. The output is rounded to nearest even when applicable and set to infinity if the input exceed the representable range.

## FloatToFixed

This component converts a floating-point signal to a signed fixed-point signal. Infinities and NaN's are not supported. The integer and fraction widths are auto-calculated to achieve lossles conversion.

## Float8ToFixed

This component converts an 8-bit floating-point (FP8) representation (E5M2 or E4M3) to a signed fixed-point representation. This component offers using the same hardware for both FP8 formats. Therefore, both input and output are of type `Logic` and can be cast from/to floating point/fixed point by the producer/consumer based on the selected `mode`. Infinities and NaN's are not supported. The output width is 33 to accomodate E5M2 without loss.
