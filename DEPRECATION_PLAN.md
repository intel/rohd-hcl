# Deprecation and Breaking-Release Plan

This is the tracking list for the typed-payload and compatibility migrations
currently planned for a future breaking ROHD-HCL release. It is not a promise
to remove every deprecated API in the next release. Keep existing APIs and
behavior until their replacements and migration instructions are ready.

## Release sequence

| Milestone | Ship | Keep |
| --- | --- | --- |
| ROHD-HCL 0.3.3 (compatible) | The five direct generic imports and the synchronous lookup import, plus warnings for the legacy component and associative APIs below | Legacy barrel exports, constructors, callback aliases, and all HCL payload helpers |
| Inference extension release (compatible) | Delegate strict payload shape and packed-bridge checks to hosted ROHD 0.7.5; remove the internal ROHD compatibility-alias import and duplicate strict connection logic | Existing helper entry points and behavior, renamed-clone checks, checked cloning, typed-port registration, and previously deprecated public APIs |
| Next hosted ROHD release with payload parity (version not yet assigned here) | The reusable payload checks, cloning, and port registration changes prepared on `interface_cloning` off ROHD `main` | Existing strict defaults and untyped interface behavior |
| First compatible HCL release after upstream parity | Adopt the hosted ROHD APIs, make the old helpers delegate where equivalent, and deprecate those helpers with migration guidance | The old helper entry points and behavior through this release |
| Following HCL release | Remove the superseded helpers after their deprecation window; do not remove a published API in a compatible release | Helpers without a proven replacement, and operations that remain HCL-owned |

The flat API migration has its own window: after 0.3.3 ships the warnings,
the next **breaking** HCL release can remove the legacy flat APIs and promote
the generic implementations to the simple names. This does not depend on the
next ROHD release, and it must not shorten the separate payload-helper deprecation window.

## Inference extension release status

No previously published public API is removed or newly deprecated in this release. The completed cleanup replaces implementation details, not helper entry points, and keeps the minimum ROHD version at 0.7.5.

The new tensor layout and movement components use typed-only APIs. Their unpublished packed prototypes are replaced directly: `SystolicMatrixTranspose<T, V>` accepts a typed row, and `TensorScratchpad<T>` and `TensorDmaEngine<T>` retain a word schema through their ports and storage. These new APIs do not need a deprecation window or flat compatibility wrappers; the published APIs listed below still do.

The unpublished `TensorTileTiler` and `TensorTileUntiler` interfaces are replaced directly with synchronous-action cores. Ready/valid callers use `ReadyValidTensorTileTiler` and `ReadyValidTensorTileUntiler`, which attach ingress and egress protocols to those same cores. No published API requires deprecation for this separation.

Attention, sequential addressing, and scratchpads expose new synchronous-action `Core` classes; their existing new component names denote ready/valid attachment shells. The unpublished accumulating-bank action names are replaced directly with `write`, `read`, and `consumeResponse`; protocol callers use `ReadyValidTensorAccumulatingMemoryBank` with typed requests and responses. These shells are transport adapters, not legacy compatibility wrappers. No published interface is removed.

| Area | Completed in this release | Still retained |
| --- | --- | --- |
| Strict shape comparison | `samePayloadShape` delegates to ROHD's public `sameRohdPayloadShape`; the internal `sameDeclaredPayloadShape` alias import is removed | The HCL helper signature and constant-name option |
| Packed-bridge compatibility | `compatiblePayloadConnection` and the strict path of `compatiblePayloadSet` delegate to `rohdPayloadsCompatible` instead of duplicating its checks | The HCL entry points and the `allowRenamedClones` path |
| Clone and port registration | No removal; the full replacement contract is not yet available in the selected hosted ROHD release | Renamed-clone checks, `cloneTypedPayload`, `cloneInterfacePayload`, `addTypedPayloadOutput`, and `connectTypedPayloadPorts` |
| Existing public deprecations | No removal or promotion of generic APIs to legacy barrel names | The legacy component, associative, finite-field, CAM, and FIFO APIs described below |
| Tensor layout and movement | Replace unpublished flat prototypes with typed rows and word-schema constructors; retain types in internal storage and selection | No flat wrappers for these new components; existing published APIs remain supported |
| Inference scheduling | Separate reusable action cores from protocol shells; replace unpublished accumulating-bank handshake names with synchronous actions | Ready/valid attachment shells and intentionally transport-specific memory orchestrators |

The removed family development plan is documentation cleanup, not an API deprecation. Planning and partition inventories remain on the communication development branch; public usage remains in the README-linked component guides.

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
  their constructors, clones, and dependent interfaces. In 0.3.3, deprecate
  only the packed constructors; the base classes remain valid interface
  types. Use the typed constructors with `Logic(width: keyWidth)` for
  packed keys or a declared key schema for structured keys.
- `TypedAssociativeKeyComparator<T>` and `TypedAssociativeMatchPreference<T>`
  replace the flat typedefs deprecated in 0.3.3. Use `<Logic>` for packed
  keys or selection values. Migrate the generic typedefs and their callers to
  the unprefixed names in the breaking release.

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

The [HCL payload helpers](lib/src/interfaces/payload_shape.dart) delegate
strict shape and pairwise packed-bridge checks to ROHD 0.7.5. This delegation
is complete for the strict paths, but does not deprecate or remove the HCL
helpers. Keep wrappers for renamed clones, checked cloning, and schema-aware
port registration until the remaining contracts are available in a hosted
ROHD release.

### Next ROHD release candidate: `interface_cloning`

- Support parent-renamed clones in shape and connection checks, including
  pairwise checks across packed bridges and generated constant names. Target:
  opt in with `allowRenamedClones` on `sameRohdPayloadShape` and
  `rohdPayloadsCompatible`.
- Validate clone width even for undeclared payloads, and make widened scalar
  constants driveable when cloning interface payloads without losing
  structured constant semantics. Target: use `cloneTyped` for detached
  clones and `cloneInterfacePort` for interface schemas.
- Validate typed outputs against a supplied schema, including when a custom
  generator is used, via `Module.addTypedOutput(..., schema: ...)`. Extend
  `Interface.typedPayloadPorts` to cover selected flat and grouped ports,
  including input, output, and inout, with opt-in
  `allowRenamedPayloadClones`. Keep protocol-specific policies in HCL.
- Use the strict ROHD shape comparison for corresponding snapshot schemas;
  list length and ordering remain the caller's contract. Keep packed-value
  writes and generated module layout identities in HCL unless an independent
  ROHD use establishes a shared contract. They are not interface-cloning
  prerequisites.

### Following two ROHD-HCL releases

1. After the replacement APIs are published, release a compatible HCL
   version that delegates to them and deprecates the superseded helpers.
   Keep the old entry points and behavior, and document each replacement.
2. Remove the deprecated helpers in the following HCL release, after the
   migration window. Schedule removals that break a published API for a
   breaking release.

Before deprecating a helper, verify parity against the hosted ROHD release
with the HCL contract tests: recursive layouts, metadata, array codecs,
constants, malformed clones, packed bridges, port directions, and generated
RTL. Re-run the supported hosted ROHD version matrix. Local upstream
proposals are not released contracts.

## Other existing deprecations

The existing deprecated `Cam`/`TagInterface` and `ReadyValidFifo` APIs have
their own replacements and behavioral considerations. Review their migration
guidance and remaining consumers before scheduling removal; do not assume the
replacement FIFO has identical full-queue timing. Other pre-existing
deprecations should likewise be reviewed separately.
