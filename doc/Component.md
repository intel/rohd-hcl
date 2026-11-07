# How to Build a Great Component in ROHD

Since ROHD is an extension of the Dart programming language, please follow all
Dart programming and documentation conventions.

The `Module` class is the base class used in ROHD to build components. Its
constructor connects the component to the signals passed by its caller.

Since ROHD is written in Dart, you should use the Dart best practices, such as
camel-case variable naming, commenting patterns for all public APIs, and take
advantage of dart format and dart analyze tools.

## Port Construction and Connection

A `Module` constructor takes `Logic` arguments and parameters to generate a
hardware component. The `Logic` arguments are actually the external signals
being connected to by the `Module`, and so internal copies must be constructed
and connected to these arguments by the constructor and only then can other
logic signals be connected to these copies. If you do not do this, a trace error
will occur, but that only happens when this module is instantiated in another --
it will not show up while testing which just instantiates the module in a test
environment.  See [Modules](https://intel.github.io/rohd-website/docs/modules/)
for more detail.

A key pattern used in ROHD-HCL is to have the constructor take only input
signals as arguments and generate the output signal widths based on these
signals and other parameters.

## Port Types

Choose port types according to the component's contract. A `Logic` carries its
width, so derive input widths from the signals; a separate parameter may still
be appropriate for output geometry or storage capacity. Use `addInput` and
`addOutput` for scalar ports.

`LogicStructure` groups named fields, as in `FloatingPoint` and `FixedPoint`.
Use generic `LogicType extends Logic` ports and `addTypedInput` or
`addTypedOutput` with the appropriate clone factory when the component should
preserve the caller's payload type. `TypedLogicArray<T, V>` additionally
preserves array dimensions, leaf types, and its value codec. See the typed
examples in [FIFO](./components/fifo.md), [serialization](./components/serialization.md),
and [memory](./components/memory.md).

Do not assume equal bit width means compatible typed payloads. Validate the
declared structure, array shape and codec, enum mapping, and any domain-specific
format metadata as appropriate for the component. Use the existing payload
shape helpers where they apply, and document additional constraints. For scalar
constants passed into generic constructors, explicitly select `Logic` when a
mutable port is required, for example `Fifo<Logic>`.

An `Interface` describes related signals and their directions; a `PairInterface`
describes producer and consumer roles. Register cloned interfaces with ROHD's
`addInterfacePorts` or `addPairInterfacePorts`, and use the registered internal
interface in the module. Pass `uniquify` at connection or registration time
when names need to be adjusted; the deprecated `PairInterface.modify` callback
is not preserved. See [standard interfaces](./components/standard_interfaces.md)
and [ready/valid interfaces](./components/ready_valid.md).

## Static and Runtime Parameters

Use ordinary Dart values for elaboration-time choices such as a depth or
implementation strategy. When an option supports either a fixed value or a
runtime signal, use `StaticOrRuntimeParameter` for a boolean or
`StaticOrRuntimeControl<T>` for another static value type. Resolve the control
inside the module so a runtime signal becomes an internal port, while a static
value becomes a constant. Validate widths and unsupported values explicitly.
See [static or runtime controls](./static_or_runtime_parameters.md) for
construction and child-module patterns.

## Typed Operations

Transporting a typed payload does not imply that every arithmetic or comparison
operation should treat it as packed bits. Preserve the domain's operations when
that is the component contract, and explicitly use `.packed` when bit-vector
semantics are required. Document signedness, rounding, overflow, unknown-value
behavior, and output format where relevant. Examples include
[typed extrema](./components/extrema.md#typed-comparisons),
[typed sorting](./components/sort.md#typed-payloads), and
[typed prefix networks](./components/parallel_prefix_operations.md#typed-prefix-networks).

## Logic Internals

Signal logic is constructed in a ROHD component by assignment and simple logic
operations like and (`&`) and or (`|`) as well as multiplexing (`mux`) and
flopping (`flop`).  See
[operations](https://intel.github.io/rohd-website/docs/logic-math-compare/) for
more detail.

 More complex logic can be constructed using
 [`Sequential`](https://intel.github.io/rohd-website/docs/sequentials/) and
 [`Combinational`](https://intel.github.io/rohd-website/docs/conditionals/)
 blocks similar to SystemVerilog `always` blocks.  There is also a
 [`FiniteStateMachine`](https://intel.github.io/rohd-website/docs/fsm/)
 construct for state machines and a
 [`Pipeline`](https://intel.github.io/rohd-website/docs/pipelines/) construct
 for assisting with pipelined logic.

 Try to minimize the addition of new internal signals, by just reusing the
 signals created by the ports or by subcomponents.  Use `.named` to create clean
 SystemVerilog names.

### Debug

 If you want to expose internal signals onto the interface of a `Module` for
 debug, a simple method is to declare them as a field in the class (Use
`@protected` in case this is exposed, so it doesn't become part of the API). This
 signal will be available in tests as module.field.

## Unit Testing

Unit tests validate a component and provide usage examples. Place Dart tests
under `test/` in the matching component family, with names ending in
`_test.dart`. For example:

```dart
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('ripple adder adds two values', () async {
    final a = Logic(width: 8);
    final b = Logic(width: 8);
    final adder = RippleCarryAdder(a, b);
    await adder.build();
    a.put(5);
    b.put(6);
    expect(adder.sum.value.toInt(), 11);
  });
}
```

Sequential tests additionally need a clock, a running simulator, and an
explicit end to the simulation. Prefer `waitCycles` and `inject` when driving
clocked stimulus. Test both functional behavior and generated RTL when timing
or four-state behavior matters.

For a parameterized test matrix, construct one DUT for each unique elaboration
configuration, then drive all of that configuration's value vectors through the
same DUT. Do not instantiate every configuration while registering tests in a
loop: use a lazy factory inside each test callback so unexecuted configurations
do not consume simulator memory. Construct separate DUTs only when a parameter
changes the generated hardware.

When testing a combinational path, and you `inject` inputs after a positive
clock edge, if you sample at the next clock edge, you will miss the
combinational value.  Instead, use the output `previousValue` at the next clock
edge, or sample the output at `nextNegEdge` to look at the value midway through
the clock cycle.

While creating unit tests, you can just run the tests for your component instead
of running the entire suite of ROHD-HCL tests.  The entire regression suite
takes quite a long time and is only necessary if you make changes to some core
functionality.

## ROHD-HCL Component Integration

After implementing a component, place it in the matching
`lib/src/<category>/<subcategory>/` directory (see the source layout in
[README.md](./README.md)) and export it from that subcategory's barrel. The
category barrels are already exported by `lib/rohd_hcl.dart`. Add focused tests
under `test/<category>/`, including a nested-parent build test for every
composable module. When a category has more than about six direct test files,
split tests into subdirectories matching the source subcategories under
`lib/src/`.

For a component that must accept and emit different transport protocols, keep
the hardware core protocol-neutral. Define typed action/payload requests and
bindings with `HardwareCoreFunctor`, then add one typed directional attachment
per boundary. Each attachment owns its protocol handshake or accounting and
maps it to the core actions; it also publishes
`DirectionalAttachmentCapabilities` so composition behavior is explicit.
Do not introduce a universal protocol interface or duplicate a core for each
protocol pair. P00 establishes synchronous and ready/valid attachments over
the FIFO core; later branches add credit or other protocol attachments using
the same core-and-attachment seam.

Every documented, synthesizable public `Module` should have a `Configurator`
under `lib/src/component_config/components/` and an entry in
`lib/src/component_config/components/component_registry.dart`. Update an
existing configurator whenever its component gains a user-selectable
elaboration parameter. Expose compile-time choices as `ConfigKnob`s and
runtime-selectable controls as generated named `Logic` inputs. Pure
`LogicStructure`/`Interface` APIs, callback-only implementation primitives,
and simulation-only models do not require configurators. The registry drives
both the configuration app and documentation netlist generation.
Override each configurator's `category` and `subcategory` to match the source
directory.

Complete the Confapp source-asset, generated-view, and regression-test work
described in [the Confapp README](../confapp/README.md). Application setup and
dependency-source selection are documented in
[confapp/DEVELOPER.md](../confapp/DEVELOPER.md).

## Component Validation

Run focused validation while iterating:

```bash
dart format lib test
dart analyze --fatal-infos
dart test test/path/to/component_test.dart
```

Before submitting a component change, run the applicable broader test suite and
verify that the component builds when instantiated beneath a parent module.
