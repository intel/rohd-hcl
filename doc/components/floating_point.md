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

Appropriate string representations, comparison operations, and operators are available.  The usefulness of [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) is in the testing of [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) components, where we can leverage the abstraction of a floating-point value type to drive and compare floating-point values operated upon by floating-point components.

### Subnormals As Zero

Both for compatibility and for optimization we provide an option to flag floating-point numbers to be treated as zero when they become subnormal.  On input to a component, this is commonly known as Denormal-as-Zero (or DAZ).  On output from a component this is commonly known as Flush-to-Zero (FTZ).  By setting the boolean on the input `FloatingPoint` called `subNormalAsZero` you indicate DAZ for components that support this mode (our floating-point adders, currently).  By setting the same flag on the output `FloatingPoint`, you indicate FTZ.

### Explicit J-Bit

In intermediate floating-point computations, it may be necessary to avoid normalization and simply store the current mantissa without shifting it left to move its leading 1 into the implicit j-bit location (no zeros before) and adjust the exponent.  We allow this by representing the j-bit explicitly in the mantissa as a leading '1', even when the floating-point is 'normal', or has a positive exponent field.  Typically, only sub-normals can have the leading j-bit stored in the mantissa.  While, in general, this can create a loss in accuracy, in some specific cases we can leverage avoiding normalization without loss of accuracy if we tailor our components to carry more precision and save the latency of normalization.

Our `FloatingPointAdderSinglePath` and `FloatingPointConverter` modules currently support operations with either input or output explicit j-bit representations.

`FloatingPointAdderSinglePath` can be specified to produce an explicit j-bit output by providing an output of that type.  If an output is not provided, then the adder will produce an output of implicit-j-type unless both inputs are explicit-jbit.  

Explicit J-bit computations are enabled by an `explicitJBit` constructor flag for `FloatingPoint` as well as `FloatingPointValue`.

### Floating Point Constants

The various IEEE constants representing corner cases of the field of floating-point values for a given size of [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html): infinities, zeros, limits for normal (e.g. mantissa in the range of $[1,2)$) and sub-normal numbers (zero exponent, and mantissa <1).

For any basic arbitrary width `FloatingPointValue` ROHD-HCL supports the following constants in that format.

- `negativeInfinity`: smallest possible number
- `positiveInfinity`: Largest possible number: all 1s in the exponent, all 0s in the mantissa
- `negativeZero`: The number zero, negative form
- `positiveZero`: The number zero, positive form
- `smallestPositiveSubnormal`: Smallest possible number, most exponent negative, LSB set in mantissa
- `largestPositiveSubnormal`: Largest possible subnormal, most negative exponent, mantissa all 1s
- `smallestPositiveNormal`: Smallest possible positive number, most negative exponent, mantissa is 0
- `largestLessThanOne`: Largest number smaller than one
- `one`: The number one
- `smallestLargerThanOne`: Smallest number greater than one
- `largestNormal`: Largest positive number, most positive exponent, full mantissa
- `nan`: Not a Number, designated by all 1s in exponent and any 1 in mantissa (we use the LSB)

### Special subtypes

As 64-bit double-precision and 32-bit single-precision floating-point types are most common, we have [FloatingPoint32Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint32Value-class.html) and [FloatingPoint64Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint64Value-class.html) subclasses with direct converters from Dart native [Double](https://api.dart.dev/stable/3.6.0/dart-core/double-class.html).

Other special widths of floating-point values supported are:

- [FloatingPoint16Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint16Value-class.html)
- [FloatingPoint8E4M3Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E4M3Value-class.html)
- [FloatingPoint8E5M2Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint8E5M2Value-class.html)
- [FloatingPointBF16Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointBF16Value-class.html)
- [FloatingPointTF32Value](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointTF32Value-class.html)

Finally, we have a [random value constructor](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValuePopulator/random.html) generator for testing purposes, generating valid [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) types, optionally constrained to normal range (mantissa in $[1, 2)$).

### Populators

A `FloatingPointValuePopulator` is similar to a builder design pattern that helps populate the components of a `FloatingPointValue` predictably across different special subtypes. The general pattern is to call the `populator` static function on a `FloatingPointValue` (or special subtype), then subsequently call one of the population methods on the provided populator to receive a completed object.  Some examples are shown below:

```dart
// a [FloatingPointBF16Value] with a value representing the selected constant
FloatingPointBF16Value.populator()
    .ofConstant(FloatingPointConstants.smallestLargerThanOne);

// a custom exponent and mantissa width for a non-special-subtype
FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 6)
    .ofDouble(1.23);
```

Included in the `FloatingPointValuePopulator` is a `random()` floating-point value generator that can generate `FloatingPointValue`s in a constrained range such as

$$lowerBoundFPV < generatedFPV <= upperBoundFPV$$

or

$$lowerBoundFPV <= generatedFPV < upperBoundFPV$$

or any other variants of $<$, $<=$, $>$, and $>=$, as well as limiting the `FloatingPointValue` generation to normals or subnormals. An example of its use is

```dart
const exponentWidth = 4;
const mantissaWidth = 4;
FloatingPointValuePopulator populator() => FloatingPointValue.populator(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

final lt = populator().ofBinaryStrings('0', '1100', '0001');
final gt = populator().ofBinaryStrings('0', '1011', '1111');
final expected = populator().ofBinaryStrings('0', '1100', '0000');
final fpv = populator().random(Random(), lt: lt, gt: gt);
```

This example produces the single available `FloatingPointValue` available in the range denoted by `expected`.

`FloatingPointValue` types also have a `clonePopulator` function which creates a new `FloatingPointValuePopulator` with the same characteristics (e.g. mantissa and exponent widths) to construct a similar `FloatingPointValue` as the original.

## FloatingPoint

The [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) type is a [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html) which comprises the [Logic](https://intel.github.io/rohd/rohd/Logic-class.html) bits for the sign, exponent, and mantissa used in hardware floating-point.  This type is provided to simplify and abstract the declaration and manipulation of floating-point bits in hardware.  This type is parameterized like [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html), for exponent and mantissa width.

Again, like [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html), [FloatingPoint64](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint64-class.html) and [FloatingPoint32](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint32-class.html) subclasses are provided as these are the most common floating-point number types.

## FloatingPointAdder

A single path [FloatingPointAdderSinglePath](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointAdderSinglePath-class.html) component is available which performs a straightforward processing of adding, normalizing, and rounding, but includes implicit and explicit j-bit handling. It takes two [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html)s and adds them, returning a normalized [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) on the output.  An option on input is the type of ['ParallelPrefix'](https://intel.github.io/rohd-hcl/rohd_hcl/ParallelPrefix-class.html) used in the critical internal addition of the mantissas.  Another is to use a width generator for partitioning the internal compound adder to tradeoff area for reduced latency in producing the mantissa and mantissa + 1 for rounding. If you pass in an optional clock, a pipe stage will be added to help optimize frequency; an optional reset and enable are can control the pipe stage.

A second `FloatingPointAdderDualPath` component is available which is optimized for latency.  It is based on "Delay-Optimized Implementation of IEEE Floating-Point Addition", by Peter-Michael Seidel and Guy Even, using an R-path and an N-path to process far-apart exponents and use rounding and an N-path for exponents within 2 and subtraction, which is exact.  If you pass in an optional clock, a pipe stage will be added to help optimize frequency; an optional reset and enable are can control the pipe stage.

## FloatingPointSqrt

A very basic [FloatingPointSqrtSimple] component is available which does not perform any
rounding and does not support DeNorm numbers. It also only operates on variable mantissas of an odd value (1,3,5,etc) but these odd mantissas can be of variable length up to 51. It takes one
[FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html) and
performs a square root on it, returning the [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) value on the output.

Currently, the [FloatingPointSqrtSimple](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointSqrtSimple-class.html) is close in accuracy (as it has no rounding) and is not
optimized for circuit performance, but provides the key functionalities of floating-point square root. Still, this component is a starting point for more realistic
floating-point components that leverage the the logical [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) and literal [FloatingPointValue](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPointValue-class.html) type abstractions.

## FloatingPointMultiplier

A very basic [FloatingPointMultiplierSimple] component is available which does not perform any rounding. It takes two [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) [LogicStructure](https://intel.github.io/rohd/rohd/LogicStructure-class.html)s and multiplies them, returning a normalized [FloatingPoint](https://intel.github.io/rohd-hcl/rohd_hcl/FloatingPoint-class.html) on the output 'product'.  

It has options to control its performance:

- `radix`: used to specify the radix of the Booth encoder (default radix=4: options are [2,4,8,16])'.
- `adderGen`: used to specify the kind of [Adder] used for key functions like the mantissa addition. Defaults to [NativeAdder], but you can select a [ParallelPrefixAdder] of your choice.
- `seGen`: type of sign extension routine used, base class is [PartialProductSignExtension].
- `priorityGen`: used to specify the type of [PriorityEncoder] used in the other critical functions like leading-one detect.

## FloatingPointConverter

A [FloatingPointConverter] component translates arbitrary width floating-point logic structures from one size to another, including handling subnormals, infinities, and performs RNE rounding.

Here is an example using the converter to translate from 32-bit single-precision floating point to 16-bit brain (bfloat16) floating-point format.

```dart
    final fp32 = FloatingPoint32();
    final bf16 = FloatingPointBF16();

    final one = FloatingPoint32Value.getFloatingPointConstant(
        FloatingPointConstants.one);

    fp32.put(one);
    FloatingPointConverter(fp32, bf16);
    expect(bf16.floatingPointValue.toDouble(), equals(1.0));
```

## Wider Outputs

`FloatingPointAdderSinglePath` provides for wider mantissa output currently, but the exponent must match.

`FloatingPointMultiplierSimple` provides for wider exponents and wider mantissas on output.

Eventually, these components will provide for arbitrary output widths.
