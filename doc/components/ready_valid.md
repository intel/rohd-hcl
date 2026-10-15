# Ready/Valid Hardware

ROHD-HCL provides typed ready/valid interfaces and a FIFO that buffers
`LogicStructure` payloads.

## Interfaces and handshaking

`ReadyValidInterface<T>` pairs a `data` payload with `valid` and `ready`
signals. A transfer is accepted on a clock edge when both `valid` and `ready`
are high; `accepted` exposes their conjunction, while `stalled` indicates a
valid offer waiting for ready.

Every interface carries a `ReadyValidContract` value that records whether
`valid` may depend on `ready`, whether `ready` may depend on `valid`, and
whether `valid` and the payload must remain stable while stalled. The default
`ReadyValidInterface<T>` contract is unconstrained to preserve existing
constructor behavior.

The specialized interfaces provide stronger presets:

- `ReadyAndValidInterface<T>` computes ready and valid independently.
- `ReadyThenValidInterface<T>` permits valid to wait for ready.
- `ValidThenReadyInterface<T>` permits ready to wait for valid.
- `IrrevocableReadyValidInterface<T>` is valid-first and guarantees that valid
  and payload remain stable until acceptance.

Contracts compare by value, survive interface cloning, support requirement
checks with `satisfies`, and can reject a direct provider/consumer dependency
cycle with `requireComposable` or the corresponding interface convenience
methods.

A `ReadyThenValidInterface` can be adapted with
`toDownstreamReadyAndValid(clk, reset)`, which inserts a two-entry FIFO and
returns an independently asserted ready/valid interface.

Ready/valid `connectIO` registration preserves the concrete payload type,
including `LogicStructure` payloads, by using ROHD typed module ports for data
and scalar ports for ready and valid. Subclass provider sidebands and nested
pair subinterfaces continue through normal ROHD traversal. When an
intentionally retyped connection uses a plain packed `Logic` on one side,
registration creates a typed bridge from the target payload template after
validating width; two declared structures must also have matching recursive
field or array shape. For legacy pair interfaces, the inherited
`PairInterface.modify` callback is applied before `uniquify` to data, valid,
ready, sidebands, and nested interface ports. Every built-in ready/valid
`clone` retains that callback on the new interface without modifying the
source.

## ReadyValidFifo

`ReadyValidFifo<T>` buffers a typed `LogicStructure` payload between upstream
and downstream ready/valid interfaces. Its default depth is 8. The upstream
side deasserts `ready` when full, and the downstream side deasserts `valid`
when empty. It is the P00 reference protocol shell: its storage is constructed
through `FifoCoreFunctor`, while `ReadyValidIngressAttachmentPolicy` and
`ReadyValidEgressAttachmentPolicy` map the two ready/valid boundaries to the
core's enqueue and dequeue actions. Future protocol combinations reuse that
core-and-directional-attachment pattern rather than introducing another FIFO
wrapper architecture.

Create and retain the interface instances at the composition boundary, then
pass them into the FIFO. Continue to use those caller-owned interfaces to
connect neighboring modules; the FIFO's connected internal interface clones
are implementation details.

```dart
class Packet extends LogicStructure {
  late final Logic payload;

  Packet({String? name})
      : super([Logic(name: 'payload', width: 8)], name: name ?? 'packet') {
    payload = elements.single;
  }

  @override
  Packet clone({String? name}) => Packet(name: name ?? this.name);
}

final upstream = ReadyValidInterface<Packet>(Packet(name: 'upstream_packet'));
final downstream =
    ReadyValidInterface<Packet>(Packet(name: 'downstream_packet'));

final fifo = ReadyValidFifo<Packet>(
  clk: clk,
  reset: reset,
  upstream: upstream,
  downstream: downstream,
  depth: 4,
);
```

The upstream interface is the caller's producer-to-FIFO connection; the
downstream interface is the caller's FIFO-to-consumer connection.

---

Copyright (C) 2026 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
