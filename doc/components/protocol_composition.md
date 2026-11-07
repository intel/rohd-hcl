# Protocol Composition

ROHD-HCL separates an action-driven hardware core from the protocol at its
boundary. This lets a core describe its storage and legal actions without
embedding a particular handshake, while directional attachments translate
between a boundary and those actions.

This is a construction pattern for component authors. For an application
that needs a ready/valid queue, prefer
[`ReadyValidQueue`](ready_valid.md#readyvalidqueue). The APIs described here
are available from `package:rohd_hcl/rohd_hcl.dart`.

## Core, Request, and Binding

`HardwareCoreFunctor<Request, Binding>` is a typed construction seam:

- The **functor** names a construction recipe and advertises immutable
  `capabilities`, including a configuration identity.
- The caller creates a **request** containing its own action and payload
  signals and any required core behavior.
- `construct` builds the child module and returns a **binding** with the
  child module and its output ports. Action inputs remain owned by the caller.

The functor's identity must be a SystemVerilog-safe identifier fragment.
Capabilities describe the specific core; they are not a universal protocol
or a promise that an attachment can implement every transport policy.

## FIFO Core

`FifoCoreFunctor<T>` constructs a synchronous `Fifo<T>`. Its
`FifoCoreRequest<T>` supplies `clk`, synchronous `reset`, `enqueue`,
`dequeue`, and typed `payload`. `FifoCoreRequirements` can require full
replacement, empty bypass, and release of stored slots. Construction rejects
unsupported requirements.

The binding exposes `canEnqueue`, `outputValid`, `output`, `slotReleased`,
`full`, and `empty`. `occupancy` and `error` are nullable unless requested
with `generateOccupancy` and `generateError`. `slotReleased` indicates a
dequeue that releases a retained entry; an empty bypass does not release a
stored slot.

`generateBypass` enables an empty enqueue/dequeue bypass. Full replacement
means a dequeue can make room for an enqueue on the same edge even when the
FIFO is already full. Whether a *shell* offers that opportunity is a separate
policy decision. FIFO definition identities include the configured
capabilities and recursive payload shape, so different typed layouts do not
share a definition merely because their packed widths match.

## Directional Attachments

`ReadyValidIngressAttachmentPolicy<T>` maps an upstream boundary to an
admission action and payload:

```text
upstream.ready = canAccept
accept         = upstream.valid & canAccept
payload        = upstream.data
```

`ReadyValidEgressAttachmentPolicy<T>` maps a core offer to the downstream
boundary:

```text
downstream.valid = offerValid
downstream.data  = payload
transfer         = offerValid & downstream.ready
```

The caller supplies the action signals and connects the binding outputs.
Attachments validate payload widths and declared structured or enum shapes.
Their `DirectionalAttachmentCapabilities` describe properties such as
external storage depth, added latency, retention, replacement, and backward
combinational dependencies. This metadata describes the composition; it
does not create storage or prove that a surrounding design is free of
combinational loops.

`SynchronousActionAttachmentPolicy` is available for direct synchronous
actions and validates that an action is one bit.

## Example: Ready/Valid FIFO Shell

This example shows the seam, not a replacement for the higher-level queue.
It registers the caller-owned interfaces at the module boundary, constructs
the FIFO from module-local signals, and attaches each direction.

```dart
class FifoShell extends Module {
  FifoShell({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<Logic> upstream,
    required ReadyValidInterface<Logic> downstream,
    int depth = 4,
    bool allowReplacement = false,
  }) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final input = addPairInterfacePorts(
        upstream, PairRole.consumer, uniquify: (name) => 'input_$name');
    final output = addPairInterfacePorts(
        downstream, PairRole.provider, uniquify: (name) => 'output_$name');

    final enqueue = Logic(name: 'enqueue');
    final dequeue = Logic(name: 'dequeue');
    final payload = input.data.cloneTyped();
    final binding = FifoCoreFunctor<Logic>(depth: depth).construct(
      FifoCoreRequest<Logic>(
        clk: localClk,
        reset: localReset,
        enqueue: enqueue,
        dequeue: dequeue,
        payload: payload,
        requirements: FifoCoreRequirements(fullReplacement: allowReplacement),
      ),
      name: 'fifo_core',
    );

    ReadyValidIngressAttachmentPolicy<Logic>(
      supportsSameCycleReplacement: allowReplacement,
      storageDepth: depth,
    ).attach(
      upstream: input,
      canAccept: allowReplacement ? binding.canEnqueue : ~binding.full,
      accept: enqueue,
      payload: payload,
    );
    ReadyValidEgressAttachmentPolicy<Logic>().attach(
      downstream: output,
      offerValid: binding.outputValid,
      payload: binding.output,
      transfer: dequeue,
    );
  }
}
```

Keep using the caller-owned interfaces to connect adjacent modules; the
registered interfaces inside the shell are local clones. With replacement
enabled, downstream readiness can affect upstream readiness in the same
cycle. Check the surrounding handshake contracts for combinational cycles.
The example does not enable empty bypass.

The deprecated `ReadyValidFifo` uses this core-and-attachment pattern for
compatibility. `ReadyValidQueue` is the preferred public queue; do not assume
that every queue implementation uses this particular construction seam.
