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

## Typed payloads

`ParityTransmitter<T>` preserves the input payload schema. Since the packed
transmission does not describe that schema, pass `dataSchema` to
`ParityReceiver<T>` to obtain a typed `originalData`:

```dart
final tx = ParityTransmitter<Packet>(packet);
final rx = ParityReceiver<Packet>(tx.transmission, dataSchema: packet);
final Packet received = rx.originalData;
```

The schema is cloned, never driven, and must match the payload width. Without
a schema, receivers retain ordinary `Logic` outputs. Specialized receiver type
arguments require a schema. `correctedData` remains null for parity.
The code and transmission stay packed bits, with unchanged bit ordering.
Detection uses raw received bits even when an enum schema normalizes an
invalid received encoding to X.
