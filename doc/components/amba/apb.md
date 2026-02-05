# APB

All collateral herein is meant to be aligned with [APB specification `E`](https://developer.arm.com/documentation/ihi0024/latest/).

## APB Completer HW

The `ApbCompleter` is an abstract implementation of an arbitrary completer module. The main reason it is abstract is that the "other" side of the module (i.e., not the APB interface) can be arbitrary. But there is certain functionality and timing that is universal across all implementations of a completer and hence lives in the base class.

In addition, there is one concrete implementation called `ApbCsrCompleter`. This serves as a good example of how to implement the abstract `ApbCompleter`. It is meant to interface with a `CsrTop` or `CsrBlock` on the other side for reading/writing CSRs over APB.

## APB BFM

The APB BFM is a collection of [ROHD-VF](https://github.com/intel/rohd-vf) components and objects that are helpful for validating hardware that contains an APB interface.  It includes all the basic APB interface features for sending and responding to reads and writes, including with strobes and errors.

The main two components are the `ApbRequesterAgent` and the `ApbCompleterAgent`, which behave like a "requester" and "completer" as described in the APB spec, respectively. The `ApbRequesterAgent` has a standard `Sequencer` that accepts `ApbPacket`s to be driven out to the completer.  The `ApbCompleterAgent` has default behavior and accepts a `MemoryStorage` instance as a memory model. See the API docs for more details on how to use each of these components, which both have substantial configurability to control behavior.

An `ApbMonitor` is also included, which implements the standard `Monitor` and provides a stream of `ApbPacket`s monitored on positive edges of the clock.  The `ApbTracker` can be used to log all items detected by the monitor by implementing the standard `Tracker` API (log file or JSON both supported).

Finally, a `ApbComplianceChecker` monitors an `ApbInterface` for a subset of the rules described in the APB specification. Errors are flagged using the `severe` log messages, as is standard for errors in ROHD-VF.

The unit tests in `apb_bfm_test.dart`, which have a completer and requester communicating with each other, are a good example for setting up the APB BFM.

### Unsupported features

The following features are not supported by or have no utilities within the BFM:

- **Wake-up signalling**: wake-up features are not considered.
- **Protection**: protection features are not considered.
- **User requests and responses**: these signals are un-driven and not monitored by the BFM.
- **Retry on error**: it is up to the user of the BFM to write any error handling logic.
