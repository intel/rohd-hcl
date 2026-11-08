# Divider

ROHD HCL provides two multi-cycle integer divider modules that share a common interface:

* `MultiCycleDivider` — uses **two's complement** signed arithmetic.
* `OnesComplementDivider` — uses **one's complement** signed arithmetic.

Both modules compute an integer quotient and, optionally, a remainder. The dividers are not pipelined and have a minimum latency of 3 cycles. The maximum latency depends on the width of the operands and the selected mode:

| Mode | Algorithm | Latency upper bound |
|------|-----------|---------------------|
| `computeRemainder: true` (default) | O(n²) greedy | `O(WIDTH²)` |
| `computeRemainder: false` | O(n) binary long-division | `O(WIDTH)` |

In both modes, latency increases as the absolute difference between dividend and divisor increases (worst case: largest possible dividend, divisor of 1).

## Interface

Both modules share `MultiCycleDividerInterface`. The inputs are:

* `clock` => clock for synchronous logic
* `reset` => reset for synchronous logic (active high, synchronous to `clock`)
* `dividend` => the numerator operand
* `divisor` => the denominator operand
* `isSigned` => should the operands of the division be treated as signed integers
* `validIn` => indication that a new division operation is being requested
* `readyOut` => indication that the result of the current division can be consumed

The outputs are:

* `quotient` => the result of the division
* `remainder` => the remainder of the division (always 0 when `computeRemainder: false`)
* `divZero` => divide by zero error indication
* `validOut` => the result of the current division operation is ready
* `readyIn` => the divider is ready to accept a new operation

The numerical inputs (`dividend`, `divisor`, `quotient`, `remainder`) are parametrized by a constructor parameter called `dataWidth`. All other signals have a width of 1.

## Constructor Parameters

Both `MultiCycleDivider` and `OnesComplementDivider` accept:

* `dataWidth` (via the interface) — bit width of all data operands and results (default: 32).
* `computeRemainder` — when `true` (default), the remainder output is computed using the full O(n²) greedy algorithm. When `false`, the remainder output is always 0 and the divider uses an O(n) binary long-division algorithm with significantly lower worst-case latency.

Both modules also provide an `ofLogics` factory constructor to instantiate directly from individual `Logic` signals instead of a pre-built interface.

## Protocol Description

To initiate a new request, drive `validIn` high along with `dividend`, `divisor`, and `isSigned`. The first cycle in which `readyIn` is high and these conditions hold is the cycle in which the operation is accepted.

When division completes, the module asserts `validOut` along with `quotient`, `remainder`, and `divZero`. These values are held until the integrating environment drives `readyOut` high. If `divZero` is asserted, `quotient` and `remainder` are meaningless.

## Mathematical Properties

Implicit rounding towards 0 is always performed (truncated division). A negative quotient is always rounded towards zero if the dividend is not evenly divisible by the divisor. Note that this differs from Python, which rounds towards negative infinity.

The remainder always satisfies: `dividend = divisor * quotient + remainder`. This differs from the Euclidean modulo operator, where the remainder is always non-negative.

### Two's Complement Overflow

Overflow can only occur in `MultiCycleDivider` when `dividend = MIN_INT`, `divisor = -1`, and `isSigned = 1`. In this case the hardware returns `quotient = MIN_INT` and `remainder = 0`, since the mathematically correct result cannot be represented in the available bit width.

### One's Complement Notes

`OnesComplementDivider` uses one's complement signed representation, where both `+0` (`000…0`) and `-0` (`111…1`) exist. The value range is symmetric: `[-(2^(n-1)-1), +(2^(n-1)-1)]`, so the MIN_INT overflow case does not arise.

A divisor of all-ones (`111…1`, i.e., negative zero) with `isSigned = 1` triggers the `divZero` output, in addition to the normal all-zeros check.

The hardware benefit of one's complement is that sign correction in the convert stage requires only a bitwise invert (`~x`) rather than a full carry-propagate add (`~x + 1`), reducing the critical path in synthesized logic.

## Code Example

```dart
// Two's complement, with remainder (default)
final width = 32;
final divIntf = MultiCycleDividerInterface(dataWidth: width);
final divider = MultiCycleDivider(divIntf);

// Two's complement, quotient only (O(n) algorithm, no remainder)
final dividerQOnly = MultiCycleDivider(divIntf, computeRemainder: false);

// One's complement, with remainder
final onesIntf = MultiCycleDividerInterface(dataWidth: width);
final onesDiv = OnesComplementDivider(onesIntf);

// Factory constructor from individual Logic signals
final dividerFromLogics = MultiCycleDivider.ofLogics(
    clk: clk,
    reset: reset,
    validIn: validIn,
    dividend: dividend,
    divisor: divisor,
    isSigned: isSigned,
    readyOut: readyOut,
    computeRemainder: false); // quotient only

// ... assume some clock generator and reset flow occur ... //

if (divIntf.readyIn.value.toBool()) {
    divIntf.validIn.put(1);
    divIntf.dividend.put(2);
    divIntf.divisor.put(1);
    divIntf.isSigned.put(1);
}

// ... wait some time for result ... //

if (divIntf.validOut.value.toBool()) {
    expect(divIntf.quotient.value.toInt(), 2);
    expect(divIntf.remainder.value.toInt(), 0);
    expect(divIntf.divZero.value.toBool(), false);
    divIntf.readyOut.put(1);
}
```
