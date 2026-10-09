# Parity

ROHD-HCL implements a `Parity` component for error checking. For satisfying the functionality of Parity error checking in `Logic` data, ROHD-HCL provides 2 `Module`, namely `ParityTransmitter` and `ParityReceiver`.

## Parity Transmitter

The `ParityTransmitter` accepts the original data, produces its parity bit on
`code`, and exposes the combined code-and-data bus on `transmission`.

## Parity Receiver

The `ParityReceiver` accepts that `transmission` bus and exposes the payload as
`originalData` and the received parity bit as `code`. A parity mismatch raises
`error` and `uncorrectableError`; `correctableError` is low because parity
detects errors but does not correct them.

Please visit [API docs](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html) for more details about parity.
