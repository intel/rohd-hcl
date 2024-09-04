# Divider

ROHD HCL provides an integer divider module to get the dividend of numerator and denominator operands. The divider implementation is not pipelined and has a maximum latency of the bit width of the operands.

## Interface

The inputs to the divider module are:

* `clock` => clock for synchronous logic
* `reset` => reset for synchronous logic (active high)
* `dividend` => the numerator operand
* `divisor` => the denominator operand
* `validIn` => indication that a new division operation is being requested
* `readyOut` => indication that the result of the current division can be consumed

The outputs of the divider module are:

* `quotient` => the result of the division
* `divZero` => divide by zero error indication
* `validOut` => the result of the current division operation is ready
* `readyIn` => the divider is ready to accept a new operation

The numerical inputs (`dividend`, `divisor`, `quotient`) are parametrized by a constructor parameter called `dataWidth`. All other signals have a width of 1.

## Protocol Description

To initiate a new request, it is expected that the requestor drive `validIn` to high along with the numerical values for `dividend` and `divisor`. The first cycle in which `readyIn` is high where the above occurs is the cycle in which the operation is accepted by the divider.

When the division is complete, the module will assert the `validOut` signal along with the numerical value of `quotient` representing the division result and the signal `divZero` to indicate whether or not a division by zero occurred. The module will hold these signal values until `readyOut` is driven high by the integrating environment. The integrating environment must assume that `quotient` is meaningless if `divZero` is asserted.

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
}

// ... wait some time for result ... //

if (divIntf.validOut.value.toBool()) {
    expect(divIntf.quotient.value.toInt(), 2);
    expect(divIntf.divZero.value.toBool(), false);
    divIntf.readyOut.put(1);
}

```
