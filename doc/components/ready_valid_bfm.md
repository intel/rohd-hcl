# Ready/Valid BFM

The Ready/Valid BFM is a collection of [ROHD-VF](https://github.com/intel/rohd-vf) components and objects that are helpful for validating hardware that contains interfaces that use a ready/valid protocol.  To summarize:

- When a transmitter has something to send, it raises `valid`.
- When a receiver is able to accept something, it raises `ready`.
- When both `valid` and `ready` are high, the transaction is accepted by both sides.

The main two components are the `ReadyValidTransmitterAgent` and `ReadyValidReceiverAgent`, which transmit and receive `data`, respectively. Any bundle of information can be mapped onto the `data` bus.  Both agents provide a `blockRate` argument which controls a random weighted chance of preventing a transaction from occuring (either delaying a `valid` or dropping a `ready`).

Additionally, the `ReadyValidMonitor` can be placed on any ready/valid protocol to observe transactions that are accepted.  The resulting `ReadyValidPacket`s can also be logged via the `ReadyValidTracker`.

The unit tests in `ready_valid_bfm_test.dart`, which have a transmitter and receiver agent talking to each other, can serve as a good example of how to use these components.
