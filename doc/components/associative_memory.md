# Associative Memory

An associative memory searches keys by content and returns the index of a
matching entry. ROHD-HCL separates the lookup/update contract, storage, and
matching/selection building blocks. Import the APIs from
`package:rohd_hcl/rohd_hcl.dart`.

## Choosing an Implementation

`ParallelAssociativeMemory` is synthesizable flop-based storage with parallel
comparison of all valid entries. It is intended for small, highly ported
structures. Its indexed updates commit on the clock edge; enabled lookups
are combinational and observe the updated state after that edge.

The abstract `AssociativeMemory` boundary describes fixed-timing raw ports:
each enabled lookup port accepts a request every cycle. A positive-latency
implementation uses `SynchronousAssociativeLookupPortInterface`, whose
`valid` marks the response cycle. That interface is a contract for other
implementations, not a pipelined mode of `ParallelAssociativeMemory`.

## Ports and Typed Keys

- An `AssociativeUpdatePortInterface` supplies `en`, `index`, `key`, and
  `entryValid`. An enabled update writes the key and validity at the chosen
  index; setting `entryValid` low invalidates that entry.
- An `AssociativeLookupPortInterface` supplies `en` and `key`, and receives
  `hit` and `index`. The index is zero on a miss. An optional `matchVector`
  has one bit per entry.
- `TypedAssociativeUpdatePortInterface<T>` and
  `TypedAssociativeLookupPortInterface<T>` retain a key schema through clones
  and module ports. Drive the port's cloned key, not the schema object.

All ports must have matching key and index widths; the index must represent
every entry, and at least one lookup port is required. Declared structured
layouts and enum mappings must be compatible, including typed-array
dimensions and codecs. The parallel implementation compares packed key bits,
not domain-specific numeric values.

## Parallel Memory Example

This example permits duplicate keys, chooses the lowest matching index,
returns all matches, and makes the highest-numbered update port win if
multiple ports update the same entry.

```dart
final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
final lookup = AssociativeLookupPortInterface(
    keyWidth: 8, indexWidth: 2, matchEntryCount: 4);

final memory = ParallelAssociativeMemory(
  clk: clk,
  reset: reset,
  updates: [update],
  lookups: [lookup],
  entryCount: 4,
  enableValidTracking: true,
  contract: const AssociativeMemoryContract(
    lookupLatency: 0,
    updateLatency: 0,
    duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
    matchSelection: AssociativeMatchSelection.lowestIndex,
    resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
    lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
    updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
    resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    implementationKind: AssociativeMemoryImplementationKind.synthesizable,
  ),
);
```

Drive the update and lookup inputs on these caller-owned ports. For example,
to store a key, assert `update.en` and `update.entryValid` with `update.index`
and `update.key` before the sampling edge. Assert `lookup.en` and drive
`lookup.key` to search. When lookup is disabled, `hit`, `index`, and the
match vector are zero. `memory.validCount`, `memory.full`, and `memory.empty`
are available only when `enableValidTracking` is true.

For typed keys, replace the scalar ports with
`TypedAssociativeUpdatePortInterface<YourKey>(schema, indexWidth: 2)` and
`TypedAssociativeLookupPortInterface<YourKey>(schema, indexWidth: 2,
matchEntryCount: 4)`. Both ports clone the schema; wire or drive their `key`
fields. If requesting a match vector, every lookup port must have
`matchEntryCount` equal to `entryCount`.

### Supported Contract

The parallel implementation requires zero lookup and update latency,
duplicate keys allowed, lookup-after-update, synchronous reset that clears
validity, and a synthesizable implementation kind. It supports lowest- or
highest-index match selection, either result shape, and lowest- or
highest-port-wins collision resolution. It does not enforce key uniqueness,
reject colliding updates dynamically, or provide an asynchronous reset.
Incompatible contracts are rejected during construction.

Its default matcher uses four-state logical equality. Unknown key bits can
therefore make a match result unknown; this is not case equality.

## Selecting an Implementation

`AssociativeMemoryRequest` describes the desired shape and semantics.
`AssociativeMemoryCapabilities` declares what an implementation supports,
including timing, selection, update precedence, reset, and optional state
operations. `AssociativeMemoryFunctor.resolve(request)` validates a request
against those capabilities and returns an `AssociativeMemoryBinding` with the
effective contract. Inspect that contract before composing any timing or
adaptation logic, then call `binding.instantiate(...)` once with matching
ports.

`parallelAssociativeMemoryFunctor` is the supplied parallel-flop functor.
Its callable form resolves and instantiates an exact request; it rejects a
resolved timing or semantic difference rather than silently adapting it.
The functor builder does not enable the optional valid-count outputs; use
the direct constructor when those outputs are needed.

## Matching and Selection Without Storage

`AssociativeMatcher` compares a query with a list of keys under a valid mask,
returning `matchVector`, `hit`, and `multipleMatches`. Its default comparator
uses logical equality; a custom comparator must return one bit per entry.
`AssociativeMatchSelector` selects a match, exposing `valid`, `selectedIndex`,
and `selectedOneHot`. By default it selects the lowest matching index;
optional selection values and a preference callback support other policies.

```dart
final matcher = AssociativeMatcher(
    query: query, storedKeys: keys, validMask: validMask);
final selector = AssociativeMatchSelector(matchVector: matcher.matchVector);
final selected = selector.selectedIndex;
```

These are combinational building blocks: neither owns key storage nor
performs clocked updates. Give custom comparison and selection functions
distinct `comparisonName` and `selectionName` values when their generated
logic differs, so module definition identities remain distinct.

## Migrating From Legacy CAM

`Cam` and `TagInterface` remain available but are deprecated. The replacement
is not behavior-identical: legacy lookup ignores `en` and uses case matching
for unknown bits, whereas parallel associative lookup is enable-gated and
uses logical equality. Check duplicate selection, update precedence, reset,
and timing against the new contract before migrating. See the
[legacy CAM documentation](memory.md#legacy-cam) for its ports and behavior.
