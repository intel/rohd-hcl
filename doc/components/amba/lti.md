# LTI

ROHD-HCL contains a bunch of collateral for LTI. The collateral includes interface definitions, monitors, drivers, trackers, compliance checkers, BFMs, and HW implementations.

For cross-referencing against the official LTI specification:

- Any LTI collateral should be aligned with [LTI specification `D`](https://developer.arm.com/documentation/ihi0089/latest).

## Interfaces

All interface definitions can be found in `lib/src/interfaces/amba5`. Each channel (as defined in the LTI spec) is implemented as a `PairInterface` and is constructed with a configuration object that is meant to encapsulate the many parameters that are associated with LTI signals. As a convenience, there are "super" interfaces in which individual channels are grouped together. These "super" interfaces are called `Cluster`s. For example, an `LtiCluster` consists of the `LA`, `LR`, `LC`, `LT`, and `Management` channels.

The LTI interface definition is mostly independent but does share some base definitions for link layer signals like ready/valid with AXI.

For code examples of how to work with both individual channel interfaces and clusters, see `test/amba/amba5/lti_test.dart`.

## HW

There are no current HW implementations for LTI controllers. This will be done in future work.

Note that part of the difficulty is in defining what the "other side" of the controller's interface looks like.

## Validation

LTI validation collateral consists of packets, monitors, drivers, trackers, compliance checkers and agents. This collateral can be found in `lib/src/models/amba/amba<x>_bfm/lti/*.dart`.

Packets (`_packet.dart`) are SW structures that are generally aligned with the data going out on the interfaces as part of a single transaction. Note that a single transaction might occur over multiple beats (cycles). These are passed as input to drivers and returned as output of monitors. They are also the structures that are used in trackers for printing transaction data to log files.

Drivers (`_driver.dart`) facilitate driving signals on the interface with particular values over time. The values to drive are defined by the packets provided as inputs over time to the driver. Drivers also facilitate link layer flow control. For example, holding a transaction until the receiver is "ready" or until the sender has credits. Lastly, the driver has some data collection for link acceptance rate.

Monitors (`_monitor.dart`) listen on interfaces and translate signals into packets. This might mean listening across multiple beats/cycles and aggregating signal data into a single logical transaction. Monitors have a stream of packets that can be listened to (i.e., for callbacks in higher level logic).

Trackers (`_tracker.dart`) listen to monitor streams and write the associated packet (transaction) data to log files. They are often useful for debugging.

Compliance checkers (`_checker.dart`) listen to monitor streams and ensure that the traffic (sequence of transactions) is compliant with the LTI specification. For example, if an `LA` with `LAOGV=1` does indeed get responded to in the proper order. Checkers issue warnings/errors as they detect compliance failures.

Agents (`_agent.dart`) are higher level collections of drivers and monitors into coherent "profiles". For example, the `Main` agent would be driving channels such as `LA`, `LC` and monitor channels such as `LR`, `LT` (vice versa for the `Subordinate` agent).

Note that this validation collateral is meant to be used as a building block for higher level bus functional models (BFMs). For example, one can model an LTI-compliant PCIe Root Port by using a `MainAgent` along with some logic for traffic generation.

For code examples of how to apply validation collateral, including in basic higher level BFMs, see `test/amba/amba5/lti_bfm_test.dart`.
