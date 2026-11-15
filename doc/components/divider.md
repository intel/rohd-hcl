# Divider

ROHD-HCL provides an integer divider that produces quotient and remainder. The
implementation is not pipelined; its latency depends on operand values and
widths. The documented upper bound is `O(WIDTH**2)`, with a worst case including
the largest dividend divided by one.

## Choosing a Control Interface

| Parent's timing contract | Component | Result behavior |
| --- | --- | --- |
| Existing divider request/result handshake | `MultiCycleDivider` with `MultiCycleDividerInterface` | Holds `validOut` and result until `readyOut` |
| Direct start/busy/done scheduling | `IterativeDividerEngine` | Pulses `done`; the caller must consume or retain the result |
| Ready/valid commands with a backpressured consumer | `ReadyValidIterativeDivider` | Retains the result until the downstream transfer |

The direct engine wraps `MultiCycleDivider`. The ready/valid shell composes
that engine with a fall-through result buffer; it accepts no new command while
the engine is busy or a buffered result is outstanding. Its `DivisionRequest`
contains `dividend`, `divisor`, and `isSigned`; `DivisionResult` contains
`quotient`, `remainder`, and `divZero`.

Choose the boundary that matches the parent rather than duplicating the divide
algorithm for each protocol. Neither wrapper adds a pipelined or faster divide
algorithm; the arithmetic and operand-dependent latency remain those of the
underlying divider. The following sections describe that common divider
interface and its mathematical behavior.

## Interface

The inputs to the divider module are:

* `clock` => clock for synchronous logic
* `reset` => reset for synchronous logic (active high, synchronous to `clock`)
* `dividend` => the numerator operand
* `divisor` => the denominator operand
* `isSigned` => should the operands of the division be treated as signed
  integers
* `validIn` => indication that a new division operation is being requested
* `readyOut` => indication that the result of the current division can be
  consumed

The outputs of the divider module are:

* `quotient` => the result of the division
* `remainder` => the remainder of the division
* `divZero` => divide by zero error indication
* `validOut` => the result of the current division operation is ready
* `readyIn` => the divider is ready to accept a new operation

The numerical inputs (`dividend`, `divisor`, `quotient`, `remainder`) are
parametrized by a constructor parameter called `dataWidth`. All other signals
have a width of 1.

Internally, the existing state machine uses a three-bit `LogicEnum`, preserving
the encodings 0 through 4 for ready, processing, accumulate, convert, and done.
In ROHD functional simulation, invalid state encodings or partially unknown
state values are normalized to X; generated HDL need not enforce this
normalization. The state machine's behavior with invalid or unknown state or
control values is not guaranteed to match the previous untyped implementation.

## Protocol Description

To initiate a new request, it is expected that the requestor drive `validIn` to
high along with the numerical values for `dividend`, `divisor` and the
`isSigned` indicator. The first cycle in which `readyIn` is high where the above
occurs is the cycle in which the operation is accepted by the divider.

When the division is complete, the module will assert the `validOut` signal
along with the numerical values of `quotient` and `remainder` representing the
division result and the signal `divZero` to indicate whether or not a division
by zero occurred. The module will hold these signal values until `readyOut` is
driven high by the integrating environment. The integrating environment must
assume that `quotient` and `remainder` are meaningless if `divZero` is asserted.

## Mathematical Properties

For the division, implicit rounding towards 0 is always performed. I.e., a
negative quotient will always be rounded up if the dividend is not evenly
divisible by the divisor. Note that this behavior is not uniform across all
programming languages (for example, Python rounds towards negative infinity).

For the remainder, the following equation will always precisely hold true:
`dividend = divisor * quotient + remainder`. Note that this differs from the
Euclidean modulo operator where the sign of the remainder is always positive.

Overflow can only occur when `dividend=<max negative number>`, `divisor=-1` and
`isSigned=1`. In this case, the hardware will return `quotient=<max negative
number>` and `remainder=0`. This is by design as the mathematically correct
quotient cannot be represented in the fixed number of bits available.

## Code Example

```dart

final width = 32; // width of operands and result
final divIntf = MultiCycleDividerInterface(dataWidth: width);
final MultiCycleDivider divider = MultiCycleDivider(divIntf);

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

## Future Considerations

In the future, an optimization might be added in which the `remainder` output is
optional and controlled by a build time constructor parameter. If the remainder
does not need to be computed, the implementation's upper bound latency can be
significantly improved (`O(WIDTH**2)` => `O(WIDTH)`).
