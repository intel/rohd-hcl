# AXI4 BFM

The AXI4 BFM is a collection of [ROHD-VF](https://github.com/intel/rohd-vf) components and objects that are helpful for validating hardware that contains AXI4 interfaces.  It includes all the basic AXI4 interface features for sending and responding to reads and writes, including with strobes and errors.

The main two components are the `Axi4MainAgent` and the `Axi4SubordinateAgent`, which behave like a "main" and "subordinate" as described in the AXI4 spec, respectively. The `Axi4MainAgent` has standard `Sequencer`s that accept `Axi4ReadRequestPacket`s and `Axi4WriteRequestPacket`s to be driven out to the subordinate.  The `Axi4SubordinateAgent` has default behavior and accepts a `MemoryStorage` instance as a memory model. See the API docs for more details on how to use each of these components, which both have substantial configurability to control behavior.

An `Axi4ReadMonitor` and an `Axi4WriteMonitor` is also included, which implements the standard `Monitor` and provides a stream of `Axi4ReadRequestPacket`s and `Axi4WriteRequestPacket`s monitored on positive edges of the clock.  The `Axi4Tracker` can be used to log all items detected by the monitor by implementing the standard `Tracker` API (log file or JSON both supported).

Finally, the `Axi4ReadComplianceChecker` and `Axi4WriteComplianceChecker` monitor the `Axi4ReadInterface` and `Axi4WriteInterface` for a subset of the rules described in the AXI4 specification. Errors are flagged using the `severe` log messages, as is standard for errors in ROHD-VF.

Note that the `Axi4MainAgent` and the `Axi4SubordinateAgent` are comprised of logical "channels", each of which may or may not have an `Axi4ReadInterface` or an `Axi4WriteInterface`. Each channel instantiates the appropriate validation collateral (sequencer, monitor, compliance checker, etc.) based on its interfaces. Channels can send requests in parallel testing AXI4 functionality such as atomicity.

The unit tests in `axi4_bfm_test.dart`, which have a main and subordinate communicating with each other, are a good example for setting up the AXI4 BFM.

## Unsupported features

The following features are not supported by or have no utilities within the BFM:

- **AxCACHE**: There is no modeling of cache related features.
- **AxQOS**: There is no modeling of QoS related features.
- **AxREGION**: There is no modeling of region related features.
- **xxUSER**: There is no handling of user-defined fields.
- **AxPROT.instruction/data**: There is no handling of the protection metadata signaling that an access is for instruction versus data memory.
- **xRESP.decErr**: There is no scenario in which the BFM responds with a decErr (all errors are slvErr).
