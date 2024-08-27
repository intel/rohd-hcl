# Divider

ROHD HCL provides an integer divider module to get the dividend of numerator and denominator operands. The divider implementation is not pipelined and has a maximum latency of the bit width of the operands.

## Interface

The inputs to the divider module are:

* ```clock``` => clock for synchronous logic
* ```reset``` => reset for synchronous logic (active high)
* ```a``` => the numerator operand
* ```b``` => the denominator operand
* ```newInputs``` => indication that a new division operation is being requested

The outputs of the divider module are:

* ```c``` => the result of the division
* ```divZero``` => divide by zero error indication
* ```isReady``` => the result of the current division operation is ready
* ```isBusy``` => the divider is currently busy working on a division operation

The numerical inputs (```a```, ```b```, ```c```) are parametrized by a constructor parameter called ```dataWidth```. All other signals have a width of 1.

## Protocol Description

To initiate a new request, it is expected that the requestor drive ```newInputs``` to high along with the numerical values for ```a``` and ```b```. The first cycle in which ```isBusy``` is low where the above occurs is the cycle in which the operation is accepted by the divider.

When the division is complete, the module will assert the ```isReady``` signal for exactly 1 cycle along with the numerical value of ```c``` representing the division result and the signal ```divZero``` to indicate whether or not a division by zero occurred. The integrating environment must assume that ```c``` is meaningless if ```divZero``` is asserted.

## Code Example

```dart

final width = 32; // width of operands and result
final divIntf = DivInterface(dataWidth: width);
final Divider divider = Divider(interface: divIntf);

// ... assume some clock generator and reset flow occur ... //

if (~divIntf.isBusy.value.toBool()) {
    divIntf.newInputs.put(1);
    divIntf.a.put(2);
    divIntf.a.put(1);
}

// ... wait some time for result ... //

if (divIntf.isReady.value.toBool()) {
    expect(divIntf.c.value.toInt(), 2);
    expect(divIntf.divZero.value.toBool(), false);
}

```
