# AXI

ROHD-HCL contains a bunch of collateral in the AXI family (including AXI-Lite,
ACE, ACE-Lite and AXI-S) across many generations (v4 and v5). The collateral
includes interface definitions, monitors, drivers, trackers, compliance
checkers, BFMs, and HW implementations.

For cross-referencing against the official AXI specifications:

- Any collateral associated with the `v4` generation should be aligned with [AXI
  specification
  `H.c`](https://developer.arm.com/documentation/ihi0022/hc/?lang=en). The `v4`
  generation is now frozen hence this will not change.
- Any collateral associated with the `v5` generation should currently be aligned
  with [AXI specification
  `L`](https://developer.arm.com/documentation/ihi0022/latest). The `v5`
  generation is still alive and hence the associated specification version is
  subject to change in the future.
- Any AXI-S collateral across all generations should be aligned with [AXI-S
  specification `B`](https://developer.arm.com/documentation/ihi0051/latest/).

## Interfaces

All interface definitions can be found in `lib/src/interfaces/amba<x>` where
`<x>` is the desired generation (4, 5, etc). As the various "flavors" of AXI
are, for the most part (AXI-S excluded), subsets of each other, there is a base
interface implementation from which subsets inherit. Each channel (as defined in
the AXI spec) is implemented as a `PairInterface` and is constructed with a
configuration object that is meant to encapsulate the many parameters that are
associated with AXI signals. As a convenience, there are "super" interfaces in
which individual channels are grouped together. These "super" interfaces are
called `Cluster`s. For example, an `Axi5Cluster` consist of the `AR`, `AW`, `R`,
`W`, `B` and 2 other optional channels.

The AXI-S interface definition is mostly independent but does share some base
definitions for link layer signals like ready/valid. For AXI5, there is also an
`MSI` interface definition which is a constrained implementation of AXI-S.

For code examples of how to work with both individual channel interfaces and
clusters, see `test/amba/amba<x>/axi<x>_test.dart`.

### ACE4 signal layout

`Ace4Cluster` and its ACE4 channel and cluster interfaces retain their
historical port layout by default. Set `legacyMode: false` to select the ACE4
signal layout: this adds the ACE snoop and acknowledgement signals, uses the
specified response and control widths, and removes non-ACE snoop and WID ports.
The cluster accepts separate read and write ID widths, per-channel USER widths,
and a snoop data width; omitted overrides retain the shared width settings.
For example:

```dart
final ace = Ace4Cluster(
  legacyMode: false,
  arUserWidth: 4,
  rUserWidth: 8,
  snoopDataWidth: 64,
);
```

The signal layout follows the ACE and AXI4 signal descriptions in Arm IHI
0022E sections A8.3, C2.1, C2.2, and C2.3.

Both layouts support request and snoop-data drivers and monitors, as well as
`Ace4SnoopResponseChannelDriver` and `Ace4SnoopResponseChannelMonitor`.
`Axi4RequestPacket` carries SNOOP and AWUNIQUE where present; omitted values
drive zero, as do omitted DOMAIN and BAR values. Specifying SNOOP or AWUNIQUE
on a channel without that signal is an error. For the signal layout,
`Ace4AcknowledgementDriver` can acknowledge
accepted responses on the next cycle when the manager can complete them
immediately. The historical layout has no RACK or WACK signals.

`Ace4ComplianceChecker` checks stalled payload stability on all channels,
snoop address alignment, and responses without an accepted snoop in both
layouts. It additionally checks ACSNOOP encodings, CRRESP PassDirty, and
acknowledgements without a prior completed response when those signals exist.
It does not cover the full ACE protocol, including missing acknowledgements,
all data, transaction ordering, and coherency rules.

### Typed protocol field views

AXI4 and AXI5 address channels expose optional `sizeEnum` and `burstEnum` views,
and their read and write response channels expose `respEnum`. LTI read-response
channels provide an `LtiRespField`-typed `respEnum`. Each view is created only
when requested and is `null` if its raw field is absent. For example:

```dart
final ar = Axi4ArChannelInterface();
final isIncrementing = ar.burstEnum!.eq(Axi4BurstField.incr);
```

These are derived views for reading, not additional ports or drivers. Continue
to connect and drive the raw `size`, `burst`, and `resp` signals; those retain
all bits, including reserved values, X, and Z. The mappings include only enum
encodings that fit the configured field width. In ROHD functional simulation, an
unmapped or unknown value becomes X in the view, and `valueEnum` throws for such
a value. AXI5/ACE response extensions not represented by `Axi5RespField` are
consequently unmapped, but remain available on the raw response signal.
Generated HDL does not necessarily enforce the same normalization for invalid
encodings; use the raw signals when inspecting reserved or unknown values.

## HW

There are no current HW implementations for AXI-based controllers. This will be
done in future work.

Note that part of the difficulty is in defining what the "other side" of the
controller's interface looks like.

## Validation

AXI validation collateral consists of packets, monitors, drivers, trackers,
compliance checkers and agents. This collateral can be found in
`lib/src/models/amba/amba<x>_bfm/axi[_s]/*.dart`.

Packets (`_packet.dart`) are SW structures that are generally aligned with the
data going out on the interfaces as part of a single transaction. Note that a
single transaction might occur over multiple beats (cycles). These are passed as
input to drivers and returned as output of monitors. They are also the
structures that are used in trackers for printing transaction data to log files.

Drivers (`_driver.dart`) facilitate driving signals on the interface with
particular values over time. The values to drive are defined by the packets
provided as inputs over time to the driver. Drivers also facilitate link layer
flow control. For example, holding a transaction until the receiver is "ready"
or until the sender has credits. Lastly, the driver has some data collection for
link acceptance rate.

Monitors (`_monitor.dart`) listen on interfaces and translate signals into
packets. This might mean listening across multiple beats/cycles and aggregating
signal data into a single logical transaction. Monitors have a stream of packets
that can be listened to (i.e., for callbacks in higher level logic).

Trackers (`_tracker.dart`) listen to monitor streams and write the associated
packet (transaction) data to log files. They are often useful for debugging.

Compliance checkers (`_checker.dart`) listen to monitor streams and ensure that
the traffic (sequence of transactions) is compliant with the AXI specification.
For example, if an `AR` with `ARLEN=0` does indeed only return 1 beat of read
data. Checkers issue warnings/errors as they detect compliance failures.

Agents (`_agent.dart`) are higher level collections of drivers and monitors into
coherent "profiles". For example, the `Main` agent would be driving channels
such as `AR`, `AW`, `W` and monitor channels such as `R`, `B` (vice versa for
the `Subordinate` agent).

Since for AXI most "flavors" are subsets of the specification, there is only one
set of validation collateral for all of the AXI interfaces (AXI-S excluded).
Drivers and monitors are smart enough to know not to worry about signals that
don't apply to the given flavor.

Note that this validation collateral is meant to be used as a building block for
higher level bus functional models (BFMs). For example, one can model an
AXI-compliant coherent memory by using a `SubordinateAgent` along with a
`Memory`.

For code examples of how to apply validation collateral, including in basic
higher level BFMs, see `test/amba/amba<x>/axi<x>_bfm_test.dart`.
