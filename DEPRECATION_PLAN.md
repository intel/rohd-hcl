# Deprecation and Breaking-Release Plan

This is the tracking list for the typed-payload and compatibility migrations
currently planned for a future breaking ROHD-HCL release. It is not a promise
to remove every deprecated API in the next release. Keep existing APIs and
behavior until their replacements and migration instructions are ready.

## Same-named generic components

The following published flat-port APIs are deprecated. Their generic
replacements currently have the same names in separate public entry points:

| Legacy barrel name | Generic entry point |
| --- | --- |
| `PriorityMux` | `package:rohd_hcl/bit_operations/selection/priority_mux.dart` |
| `AssociativeMatcher` | `package:rohd_hcl/memory/associative/associative_matcher.dart` |
| `AssociativeMatchSelector` | `package:rohd_hcl/memory/associative/associative_match_selector.dart` |
| `SpiMain` | `package:rohd_hcl/interfaces/spi/endpoints/spi_main.dart` |
| `SpiSub` | `package:rohd_hcl/interfaces/spi/endpoints/spi_sub.dart` |
| `SynchronousAssociativeLookupPortInterface` | `package:rohd_hcl/memory/associative/synchronous_associative_lookup_port_interface.dart` |

Today, consumers hide the legacy name from `rohd_hcl.dart` and import the
corresponding entry point. The synchronous interface's packed constructor is
deprecated; its class remains a base of the generic implementation.

At the breaking release:

- Remove the flat implementations or wrappers and export the same-named
  generic implementations from the main barrel.
- Update internal callers, documentation, examples, and tests, including any
  necessary explicit `Logic` type arguments and constructor migrations.
- Keep the individual import paths working where practical, and test that
  the barrel and direct imports resolve to the same generic declarations.

See the [payload schema guide](doc/components/payload_schemas.md) for the
current import pattern.

## Other typed associative APIs

- `AssociativeIndexedSideReadResponse` and its packed constructor are
  deprecated in favor of `TypedAssociativeIndexedSideReadResponse<T>`. At the
  breaking release, use the unprefixed name for the generic response, and
  migrate the side-read provider contracts and their implementations together.
- `TypedAssociativeUpdatePortInterface<T>` and
  `TypedAssociativeLookupPortInterface<T>` coexist with packed
  `AssociativeUpdatePortInterface` and `AssociativeLookupPortInterface`.
  Plan the same unprefixed generic names at the breaking release, including
  their constructors, clones, and dependent interfaces. Their packed
  constructors are not currently deprecated; a migration path and warnings
  must be provided before removal.
- `TypedAssociativeKeyComparator<T>` and `TypedAssociativeMatchPreference<T>`
  coexist with flat typedefs bearing the unprefixed names. Migrate the generic
  typedefs and their callers to the unprefixed names in the breaking release.

Do not deprecate the currently recommended `Typed` APIs until usable
replacements are available. See [Associative Memory](doc/components/associative_memory.md)
for current usage and compatibility details.

## Finite-field compatibility

The packed constructors and `result` views of `GfConstantMultiplier`,
`GfInverse`, and `GfPolynomialEvaluator` are deprecated in favor of their
field-typed constructors and `gfResult`. Before removing them, migrate callers
and document the final constructor and result names, while preserving field
validation and typed port behavior.

## ROHD payload compatibility helpers

The [payload helpers](lib/src/interfaces/payload_shape.dart) are still needed
and are not deprecated: consumers must not be directed to an upstream API
that is unavailable or lacks equivalent behavior.

- `samePayloadShape` bridges the ROHD 0.7.3
  `sameDeclaredPayloadShape` name through an internal compatibility alias in
  ROHD 0.7.4. When the minimum supported ROHD is at least 0.7.4, replace this
  bridge with the public `sameRohdPayloadShape` and remove the internal import.
- Replace `compatiblePayloadConnection` and `compatiblePayloadSet` only when
  a released ROHD API preserves equal-width packed bridges, pairwise checks,
  constant-name handling, and, for the set helper, renamed-clone behavior.
- Remove `samePayloadShapeAllowingRenamedClone` and
  `compatiblePayloadConnectionAllowingRenamedClone` only when ROHD provides
  equivalent renamed-clone, width, and packed-bridge checks.
- Replace `cloneTypedPayload`, `cloneInterfacePayload`,
  `addTypedPayloadOutput`, and `connectTypedPayloadPorts` only when released
  ROHD APIs preserve clone width and schema validation, scalar and structured
  constants, custom output generators, selected port groups, and port
  directions as applicable.
- Review the remaining HCL-specific helpers, including schema-list checks,
  packed-value writes and generated layout identities, individually; do not
  assume an upstream shape comparison replaces them.

For each migration, update all call sites and retain tests for recursive
layouts, metadata, array codecs, constants, malformed clones, packed bridges,
and generated RTL. Re-run the supported hosted ROHD version matrix. Local
upstream proposals are not released contracts.

## Other existing deprecations

The existing deprecated `Cam`/`TagInterface` and `ReadyValidFifo` APIs have
their own replacements and behavioral considerations. Review their migration
guidance and remaining consumers before scheduling removal; do not assume the
replacement FIFO has identical full-queue timing. Other pre-existing
deprecations should likewise be reviewed separately.
