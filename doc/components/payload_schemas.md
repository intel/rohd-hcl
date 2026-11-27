# Payload Schemas and Typed Boundaries

A payload schema describes more than its bit width: it can include named
structure fields, enum mappings, array dimensions and packed/unpacked layout,
array value codecs, and semantic format metadata. Components that retain or
route typed payloads preserve this information across their ports and storage.

## Compatibility

For an unchanged payload connection, equal widths are required. If both
endpoints declare a schema, their recursive layouts and formats must match.
For example, equal-width fixed-point values with different signedness are not
interchangeable. A plain packed `Logic` endpoint is an intentional bit-level
bridge to an equal-width typed endpoint; it does not convert formats.

Compatibility through a packed bridge is not transitive. If a mux or storage
location can select among several declared payloads, compare those payloads
pairwise, even when the output is packed. Conversely, independently routed
outputs may each bridge from a packed input to different declared schemas when
the component does not mix their payloads.
Ready/valid buffers and directional attachments also accept compatible typed
payloads whose field names change with their parent names.

Semantic types can implement ROHD's `PayloadShapeMetadata` with a stable,
domain-specific identifier that is equal exactly for compatible formats. Typed
clones must preserve their recursive type, layout, and metadata. A concrete
`Const` is not a driveable port; use a `Logic` type parameter for a widened
constant when a component must create a driveable scalar port.

## Component implementation

HCL component implementations compare payloads with ROHD's
`sameRohdPayloadShape` and `rohdPayloadsCompatible`, and share the remaining
helpers in
[`payload_shape.dart`](../../lib/src/interfaces/payload_shape.dart). That is
an internal implementation library, not a public application import. The
checks run during construction and add no checking hardware. Reject
incompatible declared shapes rather than silently reinterpreting them.

### Choosing a compatibility check

| Requirement | Check |
| --- | --- |
| Connect two payloads, allowing an equal-width packed bridge | `rohdPayloadsCompatible([target, source])` |
| Check all payloads sharing storage or selection | `rohdPayloadsCompatible(payloads)` |
| Compare declared shapes without allowing a packed bridge | `sameRohdPayloadShape(first, second)` |
| Compare an operation result with a valid parent-renamed typed clone | `sameRohdPayloadShape(first, second, allowRenamedClones: true)` |
| Allow either a packed bridge or a valid parent-renamed typed clone | `rohdPayloadsCompatible([target, source], allowRenamedClones: true)` |
| Compare corresponding lists of declared schemas | `samePayloadSchemas` (HCL) |

`rohdPayloadsCompatible` checks every pair, including pairs of declared
schemas separated by a packed bridge. Set `allowRenamedClones: true` only
when the component permits parent-renamed typed clones; this mode also ignores
generated constant names. The strict comparison can independently ignore
constant names with `ignoreConstantNames: true`. Renamed-clone checks do not
permit unrelated field or semantic format changes.

The HCL helpers that these calls replace (`samePayloadShape`,
`compatiblePayloadConnection`, `compatiblePayloadSet`,
`samePayloadShapeAllowingRenamedClone`, and
`compatiblePayloadConnectionAllowingRenamedClone`) are deprecated and now
only forward to them.

### Registering outputs and cloning schemas

Register inputs with `addTypedInput` and use the registered local input as the
schema for any output that must retain its payload. Within an HCL module
constructor, for example:

```dart
_writeData = addTypedInput<LogicType>('writeData', writeData);
readData = addTypedPayloadOutput<LogicType>(this, 'readData', _writeData);
```

This is the pattern used by [`Fifo`](../../lib/src/flow_control/storage/fifo.dart).
`addTypedPayloadOutput` delegates to ROHD's `addTypedOutput`, then validates
the registered output's width and declared clone shape against the supplied
schema. By default it clones that schema. If a custom `generator` is needed
to produce a driveable representation, its registered output must still
match the schema. A malformed clone or generator fails during construction,
with a `RohdHclException` when the width or shape changed. ROHD's
`addTypedOutput(..., schema:)` makes the same check and reports a
`PortTypeException`; HCL keeps its helper so that its components report the
exception they always have.

Use ROHD's `addTypedOutput` with an appropriate generator when an output has
an independently defined schema rather than a requirement to match another
payload. For example, a floating-point adder registers its result against the
result schema and separately creates a status output; see
[`FloatingPointAdder`](../../lib/src/arithmetic/floating_point/floating_point_adder.dart).
`addTypedOutput` alone does not compare the generated output with a separate
source schema.

Use `cloneTypedPayload` with the registered local payload for retained state
or detached schema copies; it checks clone width, type and declared shape.
`cloneInterfacePayload` additionally converts a scalar `Const` widened to
`Logic` into a driveable scalar port. These are ROHD's `cloneTyped` and
`cloneInterfacePort`, kept as helpers for the same reason: a clone that
changes width is reported as a `RohdHclException`. A typed output or clone of
a constant-containing structure still needs a suitable driveable
representation.

For custom interface registration, `connectTypedPayloadPorts` shares typed
port registration and connection after the caller has checked compatibility
and determined the selected port group and direction. Existing ready/valid
interface registration already handles typed ports and packed bridges.

Test incompatible same-width formats and intentional packed bridges, as well
as malformed clones or custom output generators. Where applicable, cover
pairwise selection, nested schemas and array codecs, constants, parent-renamed
clones, and module hierarchy or generated RTL.

HCL requires ROHD 0.7.6 or later in the 0.7.x series, which supplies the
renamed-clone comparisons, clone-width checks, interface schema clones, and
schema-checked outputs that HCL previously implemented itself. The
[deprecation plan](../../DEPRECATION_PLAN.md) lists which helpers are
deprecated, which remain, and why.
Existing ROHD typed operators do not
uniformly check semantic metadata, so components must validate their own
declared payloads before invoking those operators.
For example, `condFlop` compares declared data, reset, and output formats
directly even when one of them is a packed bridge. Single-entry buffer
configuration likewise checks its input, output, and retained payload together.

The generic `PriorityMux`, `AssociativeMatcher`, `AssociativeMatchSelector`,
`SpiMain`, and `SpiSub` have separate public entry points while the main barrel
retains their deprecated flat-port predecessors. Hide each legacy name from the
barrel and import its corresponding entry point, for example:

```dart
import 'package:rohd_hcl/rohd_hcl.dart' hide PriorityMux;
import 'package:rohd_hcl/bit_operations/selection/priority_mux.dart';
```

In a future breaking release, the generic versions can replace the legacy
barrel exports.
The generic `SynchronousAssociativeLookupPortInterface` uses the same import
pattern; see [Associative Memory](associative_memory.md#choosing-an-implementation).

ROHD 0.7.4 can reject a valid parent-renamed clone if the original parent name
occurs more than once in a field name (for example, `b` and `b_bits`). Avoid
such names until the upstream clone comparison is fixed.
Its `TypedLogicArray` also requires exact field names across elements, so
structures whose fields are named from their individual parent names cannot be
used as array elements. Use consistent field names for those elements.

For generated module names, `payloadShapeIdentity` encodes layout and declared
semantic metadata; also include relevant widths, optional ports, and
configuration. These layout identities do not encode array value codecs and
are not a substitute for compatibility checks.
