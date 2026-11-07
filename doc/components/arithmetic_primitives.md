# Arithmetic Primitives

These synthesizable modules provide common unsigned and signed operations.
Import them from `package:rohd_hcl/rohd_hcl.dart`.

## Absolute Value

`AbsoluteValue(value)` interprets `value` as signed two's complement and
returns its non-negative magnitude on `result`. The output is one bit wider
than the input, so even the most-negative input is representable.

## Arithmetic With Overflow

`UnsignedAddWithOverflow(a, b, sumWidth: ...)` returns the truncated `sum`
and an `overflow` bit. `sumWidth` defaults to the wider operand width.
`UnsignedMulWithOverflow(a, b, productWidth: ...)` similarly returns `product`
and `overflow`; its default width is the sum of the operand widths, so it
holds the full product.

```dart
final a = Logic(width: 8);
final b = Logic(width: 8);
final addition = UnsignedAddWithOverflow(a, b, sumWidth: 8);
final multiplication = UnsignedMulWithOverflow(a, b, productWidth: 8);
final addOverflow = addition.overflow;
final product = multiplication.product;
```

## Division and Logarithms

`CeilDivide(dividend, divisor)` computes the unsigned quotient rounded up
when the remainder is nonzero. Its `quotient` is truncated to the dividend
width. Division by zero follows the underlying division and modulo behavior
and is not specified by this component.

`Log2Ceil(inp)` computes the ceiling of the base-2 logarithm on `log`; zero
and one both produce zero.

## Circular Pointer

`CircularPointer(clk, reset, increment, slots: ...)` is a registered pointer
over `0` through `slots - 1`. It resets to zero and advances by the runtime
increment; `wrapped` indicates that the current pointer plus increment reaches
the slot count. `slots` must be at least two and every increment must be less
than `slots`, so an advance crosses the boundary at most once.
