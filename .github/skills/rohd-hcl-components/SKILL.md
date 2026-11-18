---
name: rohd-hcl-components
description: Use when designing, implementing, reviewing, or debugging reusable ROHD-HCL components and their interfaces, tests, or documentation.
argument-hint: Describe the component or composition and its behavioral requirements
---

# ROHD-HCL component development

Use the ROHD `rohd-hardware` skill for framework fundamentals when available.
This skill covers HCL-specific design; the repository's contributor and
component documentation are authoritative.

## Find and compose existing components

- Start with the [component index](../../../doc/README.md) and
  [component design and ownership](../../../CONTRIBUTING.md#component-design-and-ownership).
  Search existing code and public APIs before adding a new mechanism.
- Prefer reusing, extending, or composing a suitable component. Generalize a
  broadly useful missing mechanism with a domain-neutral typed API and
  appropriate policy points rather than duplicating application-specific logic.
  Preserve existing behavior and compatibility; keep architectural policy and
  payload definitions in the application.
- Keep protocol-neutral functionality separate from ready/valid or credit
  transport, buffering, and accounting when the core is independently useful.
  Follow [protocol composition](../../../doc/components/protocol_composition.md).
- ROHD owns fundamental signals, simulation, and backend generation; HCL owns
  reusable hardware and component-specific models; ROHD-VF owns verification
  infrastructure. Do not introduce an upstream dependency on HCL or VF.

## Model typed payloads first

- Use `LogicStructure` for a semantic payload and `TypedLogicArray` for
  repeated structured lanes, entries, or slots. Avoid parallel lists of
  correlated fields when one typed payload expresses the contract.
- If available in the checkout, consider `MaskedLanes`, `CompactedLanes`,
  `Frame`, and `CountedFrame` payloads and matching lane components when
  their semantics fit. Keep payload semantics separate from transport
  interfaces.
- Preserve declared payload shape and semantic metadata through ports and
  storage. Equal width alone is insufficient for two declared schemas; a packed
  `Logic` bridge is intentional and does not convert formats. When multiple
  declared sources share storage or selection, check them pairwise.
  In HCL implementation code, use `compatiblePayloadConnection` for a single
  connection and `compatiblePayloadSet` for shared or selected payloads;
  permit renamed clones only where the contract allows them.
- Use `addTypedPayloadOutput` when an output must retain an existing payload's
  width and declared shape. Use ROHD's `addTypedOutput` with an appropriate
  generator for an independently defined output, not as a substitute for
  checking against an existing schema. Use `cloneTypedPayload` for checked
  retained or detached clones and `cloneInterfacePayload` for interface
  schemas that may be widened scalar constants.
- Reuse HCL's internal payload helpers only inside HCL, and follow the
  [payload schema guide](../../../doc/components/payload_schemas.md) for
  strict comparisons, constants, port directions, and upstream migration.
  Validate at construction time without adding checking hardware.
- Register inputs and interfaces with the module and use the registered
  internal copies. Compose children through parent-owned signals and
  interfaces; expose child state through actual output ports.

## Specify and verify behavior

- Document interfaces, supported configurations, timing, ordering, reset,
  backpressure and collision behavior as applicable. Include widths,
  signedness, overflow and X/Z behavior where relevant.
- Distinguish an index ranging through `N - 1` from a count that must represent
  `N`; extend an index before adding one to form a full-capacity count. Test
  capacity boundaries including one and powers of two.
- Add focused behavioral and nested parent-hierarchy tests for new behavior.
  Exercise motivating configurations and edge cases, and validate generated
  hardware or additional simulation backends where relevant and available.
  For typed boundaries, cover incompatible same-width schemas, intentional
  packed bridges, malformed clones or output generators, and relevant
  constants and renamed clones.
  Follow the [component authoring guide](../../../doc/Component.md) and
  [contribution checklist](../../../CONTRIBUTING.md#adding-a-new-component).
- Keep user-facing usage in the linked component documentation and update the
  changelog for user-visible changes. Run the repository's formatting, analysis
  and relevant tests unless the task explicitly limits validation.
