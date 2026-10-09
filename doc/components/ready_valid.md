# Ready/Valid Hardware

ROHD-HCL provides typed ready/valid interfaces and a FIFO that buffers
`LogicStructure` payloads.

## Interfaces and handshaking

`ReadyValidInterface<T>` pairs a `data` payload with `valid` and `ready`
signals. A transfer is accepted on a clock edge when both `valid` and `ready`
are high; `accepted` exposes their conjunction. A producer holds `valid` and
the payload stable until the receiver accepts the transfer.

`ReadyAndValidInterface<T>` and `ReadyThenValidInterface<T>` are interface
variants for protocols with different ready/valid ordering assumptions. A
`ReadyThenValidInterface` can be adapted with
`toDownstreamReadyAndValid(clk, reset)`, which inserts a two-entry FIFO and
returns an independently asserted ready/valid interface.

## ReadyValidFifo

`ReadyValidFifo<T>` buffers a typed `LogicStructure` payload between upstream
and downstream ready/valid interfaces. Its default depth is 8. The upstream
side deasserts `ready` when full, and the downstream side deasserts `valid`
when empty.

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
