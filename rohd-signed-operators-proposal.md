# Proposal: Signed integer operations for ROHD

## Goal

Explore a natural, explicit API for two's-complement hardware arithmetic in
ROHD, inspired by Chisel's `SInt`, without changing the existing behavior of
ROHD `Logic` operators or introducing implicit truncation policies.

This is a proposal for a ROHD session, not an instruction to commit a particular
API. Prototype the alternatives and resolve the open semantic questions
before making a production compatibility commitment.

## Current context

- `Logic` is a bit vector. Its existing arithmetic and comparison operations
  should retain their current behavior. In particular, do not change the
  existing widths or signedness of `Logic` `+` and `*`.
- ROHD uses `Logic < value` for conditional assignment and
  `Logic <= value` for a connection. Its `>>` is arithmetic and `>>>` is
  logical; preserve these conventions.
- Dart permits only a fixed set of overloadable operators. It cannot define
  Chisel's `+&` or an additional signed spelling of `<` or `*`.
- Chisel distinguishes signed and unsigned numeric types. It provides
  width-growing `+&` and `-&`, while its ordinary `+` and `-` do not grow;
  its multiplication produces a full-width result. Those semantics should not
  be assumed to match existing ROHD operations.
- ROHD-HCL already has `NumericNarrowing`, which provides explicit rounding,
  saturation or wrapping, and status signals. ROHD-HCL also has configurable
  signed multiplication and multi-cycle division. The proposed ROHD work is
  about fundamental signal/value operations, not replacing those topologies
  or policies.

## Candidate APIs

### A. Explicit named operations on `Logic`

Provide named, signed operations, for example:

```dart
final less = a.signedLt(b);
final product = a.signedMultiplyFull(b);
```

Names and method placement are illustrative. This approach preserves existing
`Logic` connection and conditional-assignment syntax and makes the signed
interpretation visible at each operation. It is less concise for expressions
with many arithmetic operations.

### B. A distinct signed view

Explore a Dart extension type or separate wrapper representing a signed
interpretation of an underlying `Logic`:

```dart
// Illustrative API; not implemented.
final a = aBits.asSigned();
final b = bBits.asSigned();

final sum = a + b;
final less = a < b;       // hardware comparison
result <= sum.bits;       // ordinary ROHD connection
```

A small local experiment confirmed that a Dart extension type wrapping
`Logic` can overload `<` and `<=` to return hardware `Logic`. The example
does not validate the rest of the design or establish production semantics.

The view makes signed expressions concise and can retain signed interpretation
across chained operations. However, the wrapped value must be explicitly
unwrapped at ordinary `Logic` interfaces unless a safe integration is designed.
Extension types use static dispatch and do not provide a distinct runtime
representation, so investigate `dynamic`, generics, muxes, registers, module
ports, and accidental loss of the view.

`Logic` subclasses are constrained by the existing `<` and `<=` assignment
signatures. Dart extensions on `Logic` also cannot transparently replace
existing instance operators. Dart `==` returns a host-language `bool`, so
hardware equality should remain an explicit operation such as `.eq()` and
`.neq()`.

### Recommended investigation

Prototype both named operations and a signed view. Prefer the least complex
API that provides good readability while preserving ROHD composition and
compatibility. A signed view can build on shared named primitives; the two
approaches need not be mutually exclusive.

## Semantics to specify before implementation

1. **Representation and conversions:** Define whether `asSigned` is a
   bit-preserving reinterpretation. Define signed literal creation, range
   checks, signed-to-unsigned conversion, and sign extension separately from
   numerical conversion and narrowing.
2. **Widths:** Specify operand and result widths for every operation,
   including unequal-width operands. Consider requiring matching widths in a
   first version, consistent with existing ROHD `Logic` arithmetic. Decide
   whether mixed signed/unsigned operands are rejected or require explicit
   conversion.
3. **Wrapping versus full precision:** Signed `+`, `-`, and low-width `*` have
   the same modular bit results as unsigned operations at the same width.
   Signedness still matters for extension, interpretation, overflow, and
   full-width multiplication. Consider named `addFull`, `subtractFull`, and
   `multiplyFull` operations, with exact widths and operand extension rules
   specified explicitly. Do not silently change existing `Logic` operations.
4. **Comparison and shifts:** Specify signed ordering and X/Z behavior.
   Preserve existing ROHD shift conventions. If signed and unsigned views
   provide shifts, clearly document whether their behavior differs from
   underlying `Logic` and avoid changing existing code.
5. **Division and remainder:** Decide rounding, remainder sign, result width,
   division by zero, and minimum signed value divided by `-1`. For example,
   truncation toward zero gives `-7 / 3 == -2` and a remainder of `-1`.
   Dart integer `%` must not be assumed to implement the desired hardware
   signed-remainder convention.
6. **Overflow and narrowing:** Define whether arithmetic wraps or reports
   overflow; do not silently saturate. Keep configurable rounding, saturation,
   and discarded-bit reporting in ROHD-HCL unless a separate capability and
   compatibility review justifies moving a fundamental helper to ROHD.
7. **Unknown values and generated RTL:** Define X/Z propagation and ensure
   functional simulation and emitted SystemVerilog agree, including signed
   casts, expression sizing, and four-state values.

## Suggested validation

- Exhaustively compare small widths against an independent integer reference:
  negative and positive operands, zero, signed minimum/maximum, overflow,
  wrapping, and full-width results.
- Test equal and unequal widths, mixed signedness, literal boundaries,
  conversions, sign extension, and deliberate width mismatch errors.
- Test comparisons and shifts, including X/Z inputs, in ROHD simulation and
  generated RTL.
- Test division and remainder across all sign combinations and explicitly
  verify the chosen zero-divisor and minimum-value overflow behavior.
- Exercise chained expressions and integration with ports, muxes, registers,
  and conditional assignments; verify signedness is not silently lost.
- Run existing `Logic` and `LogicValue` tests to establish that old semantics
  are unchanged. Add reference-model and generated-RTL coverage before HCL
  adopts any new full-width or narrowing helpers.

## References

- [Dart overloadable operators](https://dart.dev/language/methods#operators)
- [Dart extension types](https://dart.dev/language/extension-types)
- [Chisel data types and casts](https://www.chisel-lang.org/docs/explanations/data-types)
- [Chisel operators](https://www.chisel-lang.org/docs/explanations/operators)
- [Chisel width inference](https://www.chisel-lang.org/docs/explanations/width-inference)
- [ROHD 0.7.0 `Logic` API](https://pub.dev/documentation/rohd/0.7.0/rohd/Logic-class.html)
