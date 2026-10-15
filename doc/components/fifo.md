# FIFO

ROHD-HCL comes with a simple FIFO (First In, First Out).  The detailed API docs are available [here](https://intel.github.io/rohd-hcl/rohd_hcl/Fifo-class.html).

The underlying implementation uses a flop-based memory (see [`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html)) to store data until it is ready to be popped, with independent read and write pointers.

When `writeEnable` is high, `writeData` is added to the FIFO.  When `readEnable` is high, `readData` is popped off the FIFO.

The FIFO has a configurable `depth`.

## Peeking

When `readEnable` is low, the `readData` continually provides access to "peek" the next data.

## Empty and Full

The `empty` signal indicates when nothing is in the FIFO.  The `full` signal indicates when the FIFO can store no additional data.

## Action and Status Outputs

The FIFO exposes three protocol-neutral combinational outputs for composition:

- `canEnqueue` is high whenever an enqueue is legal. A dequeue of a retained
  entry makes a same-cycle replacement legal even while the FIFO is full.
- `outputValid` is high whenever `readData` is a legal dequeue payload. With
  bypass enabled, a write presented while empty is also a valid bypass payload.
- `slotReleased` pulses when `readEnable` removes an entry that was retained in
  storage. An empty bypass transfer does not release a stored slot.

These outputs do not change FIFO storage, latency, occupancy width, or its
existing automatic definition name. They add ports to generated `Fifo`
definitions.

## Bypass

The FIFO optionally supports a bypass if `generateBypass` is set.  When generated, if the FIFO is empty and both `readEnable` and `writeEnable` are high at the same time, then the FIFO will do a bypass of the internal storage, allowing for a combinational passthrough.

## Errors

Error information can optionally be generated and provided if `generateError` is set.  If data is popped when the FIFO is empty, or pushed when the FIFO is full, then the `error` signal will assert.

There is no guarantee that the `error` signal will hold high once asserted.  Behavior after an error condition is undefined.

## Occupancy

Occupancy information can optionally be generated and provided if `generateOccupancy` is set.  The `occupancy` signal will indicate the number of items currently stored in the FIFO.

## Initial Values

If desired, the `initialValues` argument can be used to pre-load the FIFO with
data upon reset. The length of `initialValues` must be less than or equal to the
`depth` of the FIFO. A fully initialized FIFO starts with its write pointer
wrapped to the first slot, so a simultaneous full dequeue and replacement
writes the newly released slot at every supported depth.

## Protocol-Neutral Construction

`HardwareCoreFunctor<Request, Binding>` is the generic non-`Module`
construction seam for protocol-neutral cores. `FifoCoreFunctor<T>` implements
that seam over `Fifo<T>`:

- `FifoCoreRequest<T>` carries caller-owned clock, reset, enqueue, dequeue, and
  typed payload signals.
- `FifoCoreRequirements` explicitly requests full replacement, empty bypass,
  and stored-entry-only slot release semantics.
- `FifoCoreCapabilities` describes the configured depth, action semantics, and
  optional occupancy/error outputs.
- `FifoCoreBinding<T>` returns the constructed FIFO and output-only status and
  payload views.

The implementation identity is `fifo_core`, and its generated definition
identity includes the configured capabilities, payload width, and a
deterministic recursive payload-shape signature. The signature includes
structure field names and widths or array dimensions, but not the payload
instance name. Identical shapes therefore share a definition while distinct
equal-width shapes do not collide.

## Directional Protocol Attachments

Protocol wrappers compose a core through independently typed ingress and
egress attachments. The core owns only clocked storage, payload retention, and
the explicit `enqueue`/`dequeue` actions. An attachment owns one protocol
boundary and maps it onto those actions and a wrapper-owned payload signal.

`DirectionalAttachmentCapabilities` describes the storage, latency,
retention, same-cycle replacement, credit-reuse, contract, and combinational
dependency properties of one attachment. P00 provides:

- `SynchronousActionAttachmentPolicy` for a caller-owned one-bit action; and
- `ReadyValidIngressAttachmentPolicy` and
  `ReadyValidEgressAttachmentPolicy` for typed ready/valid boundaries.

`ReadyValidFifo` is the reference composition: it uses `FifoCoreFunctor` with
one Ready/Valid ingress attachment and one Ready/Valid egress attachment.
It intentionally retains its existing no-full-replacement behavior by giving
the ingress attachment `~full` rather than the core's more permissive
`canEnqueue` action.

Later protocol families add their own typed attachments to the same core
action boundary. For example, a credited ingress may own admission accounting
and map legal credit traffic to `enqueue`, while a ready/valid egress maps
`dequeue` to its transfer handshake. Do not add a universal protocol
interface, and do not have protocol wrappers instantiate `Fifo` directly:
extend the typed attachment layer while preserving the core request/binding
API.

## Example Schematic

An example schematic for one configuration is viewable here: [FIFO Schematic](https://intel.github.io/rohd-hcl/Fifo.html)

## Testbench Utilities

The FIFO comes with both a checker and a tracker that you can leverage in your testbench.

### Checker

The `FifoChecker` is a ROHD-VF component which will watch for proper usage of a FIFO in your simulation. It is intended to check usage, not the internal workings of the FIFO, which are already pre-validated in the unit tests.  This means it covers things like underflow, overflow, and that the FIFO is empty at the end of the test.

### Tracker

The `FifoTracker` will generate log files using the `Tracker` from ROHD-VF in either table or JSON format.  It tracks reads and writes per timestamp, including data pushed/popped and the current occupancy.  An example table is shown below (from one of the unit tests):

```text
----------------------------------------
 | T        | C  | D              | O | 
 | I        | O  | A              | C | 
 | M        | M  | T              | C | 
 | E        | M  | A              | U | 
 |          | A  |                | P | 
 |          | N  |                | A | 
 |          | D  |                | N | 
 |          |    |                | C | 
 |          |    |                | Y | 
----------------------------------------
 |       55 | WR |        32'h111 | 1 | {Time: 55, Command: WR, Data: 32'h111, Occupancy: 1}
 |       75 | WR |        32'h222 | 2 | {Time: 75, Command: WR, Data: 32'h222, Occupancy: 2}
 |       75 | RD |        32'h111 | 1 | {Time: 75, Command: RD, Data: 32'h111, Occupancy: 1}
 |       85 | RD |        32'h222 | 0 | {Time: 85, Command: RD, Data: 32'h222, Occupancy: 0}

```
