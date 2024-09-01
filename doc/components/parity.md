# Parity

ROHD-HCL implements a `Parity` component for error checking. For satisfying the functionality of Parity error checking in `Logic` data, ROHD-HCL provides 2 `Module`, namely `ParityTransmitter` and `ParityReceiver`.

## Parity Transmitter

The `ParityTransmitter` is a module that accepts a Logic `bus` for data and makes the data `bus` suitable for transmission with parity. A parity check is handled by appending parity bit to `bus` data.

## Parity Receiver

The `ParityReceiver` is a module that accepts a Logic `bus` for transmitted data with a parity bit appended. The receiver functionality splits the provided `bus` into original `data` and `parity`. Also, the process of parity error check is handled within this module at result output `checkError`.

Please visit [API docs](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html) for more details about parity.
