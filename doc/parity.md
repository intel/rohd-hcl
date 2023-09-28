# Parity

ROHD HCL implements `Parity` functionality class that other modules can extend for error checking. For satisfying the functionality of Parity error checking in `Logic` data, ROHD HCL provides 2 `Module`, namely `ParityTransmitter` and `ParityReceiver`.

## Parity Transmitter

The [`ParityTransmitter`](https://intel.github.io/rohd-hcl/rohd_hcl/PriorityTransmitter-class.html) is a module that accepts a Logic `bus` for data and makes the data `bus` suitable for transmission with parity. A parity check is handled by appending parity bit to `bus` data.

## Parity Receiver

The [`ParityReceiver`](https://intel.github.io/rohd-hcl/rohd_hcl/PriorityReceiver-class.html) is a module that accepts a Logic `bus` for transmitted data with a parity bit appended. The receiver functionality splits the provided `bus` into original `data` and `parityBit`. Also, the process of parity error check is handled within this module at result output `checkError`.
