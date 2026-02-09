# DTI

ROHD-HCL contains a bunch of collateral for DTI. The collateral includes message definitions as `LogicStructure`s and HW that enables protocol compliant sending and receiving of DTI messages over AXI-S.

For cross-referencing against the official DTI specification:

- Any DTI collateral should be aligned with [DTI specification `H`](https://developer.arm.com/documentation/ihi0088/latest/).

## Messages

DTI messages are implemented as ROHD `LogicStructure`s. The fields including widths, parametrization, etc. are in accordance with the DTI specification. These can be used to conveniently construct and pass around DTI messages in HW. In some cases, there are also SW hooks to populate DTI messages (ex: from an AXI write/read).

**NOTE**: Currently, only the `TBU` messages have been implemented. Future work will cover other message groups (ex: `ATS`).

For code examples of how to work with DTI messages, see `test/protocols/amba5/dti/dti_controller_test.dart`.

## Controllers

The abstract class `DtiController` implements a generic ROHD `Module` to send and receive DTI messages over an AXI-S interface pair. On the other side of the AXI-S pair is a configurable collection of `ReadyValidInterface`s on a per message class basis. There is a sub-collection for the messages that the controller should send and a sub-collection for the messages that the controller should receive. The handling of each supported message class is configurable through the `DtiMessageInterfaceConfig` object. Properties that can be configured include FIFO depths and crediting.

Implementations of the abstract `DtiController` add functionality specific to a given "flavor" of agent that talks DTI (TBU, ATS, etc.). These implementations also include "standard" constructors that support the typical TX and RX messages given directionality (main versus subordinate).

**NOTE**: Currently, only `TBU` flavors of the generic `DtiController` have been implemented. Future work will cover other message groups (ex: `ATS`).

For code examples of how to work with DTI controllers, see `test/protocols/amba5/dti/dti_controller_test.dart`.
