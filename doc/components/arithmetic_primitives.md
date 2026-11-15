# Arithmetic Primitives

These synthesizable modules provide common unsigned and signed operations.
Import them from `package:rohd_hcl/rohd_hcl.dart`.

ROHD owns fundamental signal/value width, signedness, simulation, and backend
semantics; these HCL components provide explicit hardware policies without
changing ROHD `+` or `*`. ROHD's `>>` is arithmetic and `>>>` is logical.
Use explicit extension and narrowing when a datapath needs a different width.

## Accumulator

Use `Accumulator` for unsigned, increment-only state when arbitrary bounds,
decrements, and overflow/underflow status are unnecessary. Drive `amount` with
the value to add on an enabled edge and observe `value`. `width` sets the
stored width; by default the value wraps, while `saturates: true` clamps at
the largest unsigned value of that width.

`clear` loads `resetValue` without adding. `restart` loads `resetValue` and
then adds the enabled amount. Reset has priority and is synchronous unless
`asyncReset` is selected. Use [Counter](summation.md#counter) for up/down
counting or bounded accounting, and [Sum](summation.md#sum) for a combinational
sum rather than retained state.

## Numeric Narrowing

Use `NumericNarrowing` at a quantization or precision boundary where rounding,
discarded bits, and overflow policy must be explicit. It is combinational:
`signed` selects unsigned or two's-complement interpretation, `shiftRight`
sets how many low bits are discarded, and `outputWidth` sets the result width.
These are construction-time choices.

`roundingMode` supports nearest-even, nearest-ties-away, toward-zero, and
directed rounding. `truncate` and `towardZero` both truncate the magnitude, so
signed negative values round toward zero, not toward negative infinity.
Rounding occurs before `overflowMode` applies wrap or saturation.

The `result` output carries the converted value. `overflowed` reports a result
above the maximum, `underflowed` reports a signed result below the minimum,
and `inexact` reports nonzero discarded bits. Unknown bits follow the underlying
ROHD operations. The default is unsigned, no shift, truncation, and wrapping;
choose signedness and saturation deliberately for fixed-point datapaths.

## Absolute Value

`AbsoluteValue(value)` interprets `value` as signed two's complement and returns
its non-negative magnitude on `result`. The output is one bit wider than the
input, so even the most-negative input is representable.

## Arithmetic With Overflow

`UnsignedAddWithOverflow(a, b, sumWidth: ...)` returns the truncated `sum` and
an `overflow` bit. `sumWidth` defaults to the wider operand width.
`UnsignedMulWithOverflow(a, b, productWidth: ...)` similarly returns `product`
and `overflow`; its default width is the sum of the operand widths, so it holds
the full product.

```dart
final a = Logic(width: 8);
final b = Logic(width: 8);
final addition = UnsignedAddWithOverflow(a, b, sumWidth: 8);
final multiplication = UnsignedMulWithOverflow(a, b, productWidth: 8);
final addOverflow = addition.overflow;
final product = multiplication.product;
```

## Division and Logarithms

`CeilDivide(dividend, divisor)` computes the unsigned quotient rounded up when
the remainder is nonzero. Its `quotient` is truncated to the dividend width.
Division by zero follows the underlying division and modulo behavior and is not
specified by this component.

`Log2Ceil(inp)` computes the ceiling of the base-2 logarithm on `log`; zero and
one both produce zero.

## Circular Pointer

`CircularPointer(clk, reset, increment, slots: ...)` is a registered pointer
over `0` through `slots - 1`. It resets to zero and advances by the runtime
increment; `wrapped` indicates that the current pointer plus increment reaches
the slot count. `slots` must be at least two and every increment must be less
than `slots`, so an advance crosses the boundary at most once.
