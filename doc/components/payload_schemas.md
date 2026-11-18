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

HCL's internal `payload_shape.dart` provides `compatiblePayloadConnection`
for a connection and `compatiblePayloadSet` for pairwise checks across
multiple sources. Both run during construction and add no checking hardware.
For clone-aware pairwise checks, use `compatiblePayloadSet` with
`allowRenamedClones: true`.
`connectTypedPayloadPorts` shares port registration after the caller validates
the payload and determines its direction. `addTypedPayloadOutput` also checks
the registered output's width and declared shape against its source schema,
including when a custom generator is needed.
When comparing an operation result with a typed source,
`samePayloadShapeAllowingRenamedClone` also recognizes a valid clone whose
field names change with its parent name; unrelated field or format changes
remain incompatible.
`compatiblePayloadConnectionAllowingRenamedClone` also permits packed bridges.
`cloneTypedPayload` checks that a typed schema clone preserves its packed
width as well as its declared shape, including for scalar `Logic` subclasses.
Use the registered local payload and `cloneTypedPayload`
when creating retained typed state; `cloneInterfacePayload` additionally
handles a widened scalar constant. `addTypedInput` and typed outputs preserve
the port's declared shape, while ready/valid interface registration handles
typed ports and packed bridges. Reject incompatible declared shapes rather
than silently reinterpreting them.

These HCL helpers work with hosted ROHD 0.7.4. They remain in HCL until an
appropriate additive ROHD API is released and a later HCL release can migrate
and deprecate the redundant helpers. The proposed ROHD pairwise compatibility
and schema-aware interface registration APIs cover part of this work, but the
HCL helpers also handle parent-renamed clones and explicit clone-width checks.
Do not remove those checks until equivalent upstream behavior is available.
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
import 'package:rohd_hcl/priority_mux.dart';
```

In a future breaking release, the generic versions can replace the legacy
barrel exports.

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
