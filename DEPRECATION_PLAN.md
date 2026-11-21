# Deprecation and Breaking-Release Plan

This is the tracking list for the typed-payload and compatibility migrations
currently planned for a future breaking ROHD-HCL release. It is not a promise
to remove every deprecated API in the next release. Keep existing APIs and
behavior until their replacements and migration instructions are ready.

## Release sequence

| Milestone | Ship | Keep |
| --- | --- | --- |
| ROHD-HCL 0.3.3 (compatible) | The five direct generic imports and the synchronous lookup import, plus warnings for the legacy component and associative APIs below | Legacy barrel exports, constructors, callback aliases, and all HCL payload helpers |
| ROHD 0.7.6 (target) | The reusable payload checks, cloning, and port registration changes prepared on `interface_cloning` off ROHD `main` | Existing strict defaults and untyped interface behavior |
| First compatible HCL release after upstream parity | Adopt the hosted ROHD APIs, make the old helpers delegate where equivalent, and deprecate those helpers with migration guidance | The old helper entry points and behavior through this release |
| Following HCL release | Remove the superseded helpers after their deprecation window; do not remove a published API in a compatible release | Helpers without a proven replacement, and operations that remain HCL-owned |

The flat API migration has its own window: after 0.3.3 ships the warnings,
the next **breaking** HCL release can remove the legacy flat APIs and promote
the generic implementations to the simple names. This does not depend on ROHD
0.7.6, and it must not shorten the separate payload-helper deprecation window.

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

Keep the [HCL payload helpers](lib/src/interfaces/payload_shape.dart) in
ROHD-HCL 0.3.3. ROHD 0.7.5 already offers `sameRohdPayloadShape` and
`rohdPayloadsCompatible` for strict shape and pairwise packed-bridge checks,
but it does not replace the full HCL contract.

### ROHD 0.7.6 target: `interface_cloning`

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
