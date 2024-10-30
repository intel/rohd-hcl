# Divider

ROHD HCL provides an integer divider module to get the dividend of numerator and denominator operands. The divider implementation is not pipelined and has a maximum latency of the bit width of the operands.

## Interface

The inputs to the divider module are:

* `clock` => clock for synchronous logic
* `reset` => reset for synchronous logic (active high)
* `dividend` => the numerator operand
* `divisor` => the denominator operand
* `isSigned` => should the operands of the division be treated as signed integers
* `validIn` => indication that a new division operation is being requested
* `readyOut` => indication that the result of the current division can be consumed

The outputs of the divider module are:

* `quotient` => the result of the division
* `remainder` => the remainder of the division
* `divZero` => divide by zero error indication
* `validOut` => the result of the current division operation is ready
* `readyIn` => the divider is ready to accept a new operation

The numerical inputs (`dividend`, `divisor`, `quotient`, `remainder`) are parametrized by a constructor parameter called `dataWidth`. All other signals have a width of 1.

## Protocol Description

To initiate a new request, it is expected that the requestor drive `validIn` to high along with the numerical values for `dividend`, `divisor` and the `isSigned` indicator. The first cycle in which `readyIn` is high where the above occurs is the cycle in which the operation is accepted by the divider.

When the division is complete, the module will assert the `validOut` signal along with the numerical values of `quotient` and `remainder` representing the division result and the signal `divZero` to indicate whether or not a division by zero occurred. The module will hold these signal values until `readyOut` is driven high by the integrating environment. The integrating environment must assume that `quotient` and `remainder` are meaningless if `divZero` is asserted.

### Mathematical Properties

For the division, implicit rounding towards 0 is always performed. I.e., a negative quotient will always be rounded up if the dividend is not evenly divisible by the divisor. Note that this behavior is not uniform across all programming languages (for example, Python rounds towards negative infinity).

For the remainder, the following equation will always precisely hold true: `dividend = divisor * quotient + remainder`. Note that this differs from the Euclidean modulo operator where the sign of the remainder is always positive.

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
