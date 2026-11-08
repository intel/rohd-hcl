# Associative Memory

An associative memory searches keys by content and returns the index of a
matching entry. ROHD-HCL separates the lookup/update contract, storage, and
matching/selection building blocks. Import the APIs from
`package:rohd_hcl/rohd_hcl.dart`.

## RTL and Behavioral Implementations

The associative-memory and replacement interfaces are the composition boundary.
A designer can build a hierarchy with synthesizable RTL components or, where
available, select port-compatible behavioral components in their place. The
surrounding ROHD logic drives and observes the same ports in functional
simulation. Behavioral components are simulation models, not hardware to
synthesize: construct the RTL variants when generating SystemVerilog.

For SystemC, `generateBehavioralSystemCHierarchy` uses ROHD's SystemC
synthesizer for the surrounding hierarchy and emits a behavioral SystemC
implementation for each explicitly selected, supported component. The generated
model is connected at that component's port boundary. The exporter checks names
and widths; it does not prove behavioral or cycle equivalence. Selection is not
automatic: the instance must expose a compatible behavioral model, and
unsupported modules cause an error rather than a silent substitute. See
[Behavioral Models](behavioral_models.md#the-behavioral-model-capability) for
the hierarchy export rules.

Today, the port-compatible parallel associative memory and replacement-policy
models can be used as cache components. This does **not** yet provide a
port-compatible behavioral replacement for every complete cache controller or
for the legacy `Cam`; their limitations are described below.

## Cache Organization Examples

The cache-specific APIs in these examples, including their ports and replacement
factories, are `@experimental`: they may change or be removed without a version
bump as controller behavior evolves. The separate associative,
replacement-policy and memory-storage building blocks are not marked
experimental as part of this cache boundary. See [API
Maturity](behavioral_models.md#api-maturity).

### Which building block?

| Small use case | RTL component | What the surrounding design still does |
| --- | --- | --- |
| Recognize a small set of outstanding IDs | `ParallelAssociativeMemory` | Allocate indices and keep any payload separately |
| Keep a few blocks with one lookup and one fill | `Cache` | Fetch misses and handle eviction handshakes |
| Share a cache between two requesters | `MultiPortCache` | Retry unaccepted fills and consume buffered evictions |
| Access a one-cycle SRAM with transactions | `SerializedCache` | Service misses and consume responses and evictions |
| Arbitrate tag and data resources | `FixedPriorityCacheScheduler` | Supply resource availability and track multi-cycle reservations |
| Track request tokens across a transport boundary | `CacheTransactionAdapter` | Connect an actual core and handle backing-store traffic |
| Choose a victim for a custom structure | `RoundRobinReplacement` or `TreePseudoLruReplacement` | Own validity, eligibility, and victim data |

The configurator's **Memory** catalog exposes these RTL components, plus the CSR
example, register file and inferred SRAM. Cache entries are labeled
experimental; simulation-only implementations are not configurator options. Each
example below assumes `clk` and `reset` are one-bit signals in an enclosing
design.

Each example has four entries and starts empty. For simplicity, the numbers
below are block addresses, not byte addresses. Each alternative uses its own
caller-owned ports:

```dart
final clk = Logic();
final reset = Logic();
final lookup = CacheLookupPort<Logic>(
  addressWidth: 8, dataSchema: Logic(width: 32));
final fill = CacheFillPort<Logic>(
  addressWidth: 8, dataSchema: Logic(width: 32));
```

### Direct-mapped: four sets, one entry per set

The set is `block % 4`. Each block has exactly one possible entry:

- Fill block 5: it goes into set 1.
- Fill block 9: it also maps to set 1, so it replaces block 5.

No replacement policy is needed to choose a way: there is only one.

```dart
final cache = Cache<Logic>.directMapped(
  clk: clk, reset: reset,
  lookup: lookup, fill: fill,
  entryCount: 4,
);
```

### Set-associative: two sets, two entries per set

The set is `block % 2`. Each block can use either entry (way) in its set:

- Fill blocks 5 and 9: both map to set 1 and can coexist in its two ways.
- Fill block 13: it also maps to set 1, so a replacement policy chooses either
  block 5 or block 9 for eviction.

```dart
final cache = Cache<Logic>.setAssociative(
  clk: clk, reset: reset,
  lookup: lookup, fill: fill,
  setCount: 2, waysPerSet: 2,
  replacement: CacheReplacement.treePseudoLru,
);
```

### Fully associative: one set, four entries

Every block can use any entry:

- Fill blocks 5, 9, 13, and 17: all four can coexist.
- Fill block 21: all entries are occupied, so a replacement policy chooses one
  of the four blocks for eviction.

```dart
final cache = Cache<Logic>.fullyAssociative(
  clk: clk, reset: reset,
  lookup: lookup, fill: fill,
  entryCount: 4,
);
```

### Using the cache

These are alternatives, not three caches sharing one set of ports.
`lookup.valid` requests a combinational lookup; when `lookup.ready` is high,
`lookup.hit` and `lookup.data` give the result. A miss or unaccepted lookup
returns zero data. One lookup and one fill may proceed together if the fill does
not require eviction. A fill requiring eviction blocks lookups, including when
eviction is immediately accepted.

On a simultaneous lookup and fill of the same block, the default
`readDuringFill: CacheReadDuringFill.oldData` returns the old state before the
edge. Use `CacheReadDuringFill.forward` to return the accepted fill data
instead. The new state is visible after the edge in either mode.

A fill transfers on a rising edge when `fill.valid` and `fill.ready` are high.
Keep `fill.valid`, `fill.address`, and `fill.data` stable until that edge. When
an existing valid entry must be replaced, `fill.evictionValid` asserts with its
old `fill.evictionAddress` and `fill.evictionData`. The fill waits until
`fill.evictionReady` is high; during the stall the eviction remains stable.
External logic is responsible for handling any backing-store write. Filling an
already present block updates its data without an eviction. The cache does not
track dirty bits, fetch misses, or write backing storage. Synchronous reset
suppresses transfers and clears validity and replacement state; it cancels a
pending eviction, so the fill producer must also discard its pending request on
reset.

The set count must be a power of two and fit in the block address. Round robin
supports any positive way count; tree pseudo-LRU requires a power of two.
Invalid ways are preferred. Hits and fill hits update tree pseudo-LRU; round
robin advances on new allocations. The default data storage is a synthesizable
`RegisterFile`. Set `dataStorage: CacheDataStorage.behavioral` to use a
simulation-only, zero-latency `MemoryModel` instead. A typed `fill.data` retains
its type on the lookup and eviction outputs. The lookup and fill ports must have
matching address widths and payload shapes. Both ports are `PairInterface`s: the
caller is the provider and the cache is the consumer. They support cloning and
role-based module registration, including typed payloads. Cache modules register
individual interface fields using `addInterfacePorts` and their direction tags.
The fill port's eviction signals describe the cache's existing fill/eviction
handshake; grouping them in a pair interface does not make the eviction an
independently buffered ready/valid channel.

For a tiny block buffer, reset a two-way, one-set `Cache`, then offer a fill for
address 5 and data `0x12`. After `fill.valid && fill.ready` transfers on an
edge, an enabled lookup of address 5 reports a hit and `0x12`. Filling a third
distinct block into the full set offers a victim: keep the fill stable until
`evictionReady` allows the eviction and fill to transfer. A lookup miss does not
automatically fetch the block.

To supply a different replacement policy, pass a `CacheReplacement` with a
stable, distinct `identity` and a `build` callback matching
`CacheReplacementBuilder`. The cache calls it once per set with that set's
validity, eligibility, access, and allocation ports. The factory must return a
`ReplacementPolicy` for the supplied entry count and connect the given ports.

`BehavioralReplacementPolicy` implements the same access, allocation, and
deferred-commit ports in software, with round-robin and tree pseudo-LRU
algorithms. `CacheReplacement.behavioral(...)` supplies it to caches using the
normal replacement factory. It is simulation-only and rejects RTL export. It
follows the RTL policy's cycle and port ordering, including four-state selection
and state updates. State starts unknown and synchronous reset clears it. An
unknown reset merges the reset and next-state bits, preserving bits that agree.
Policy snapshots preserve unknown state through `snapshot` and `restore`.

The same behavioral policy can be selected as a leaf during SystemC hierarchy
generation. Its SystemC ports match the replacement module's ports. Direct
`generateSystemC` export is also available for an independently constructed
SystemC testbench, with four-state or two-state ports. The hierarchy exporter
uses two-state ports: these report unknown outputs unless `zeroUntilReset` is
selected, in which case they drive zero until the first asserted reset edge and
report unknown outputs thereafter. SystemC snapshots include the boundary's
reset status as well as policy state; they do not include external signals or
pending events. Restore between settled simulation steps and coordinate the
inputs and clock with the caller. The three-way policy tests compare Dart,
generated Verilog, and behavioral SystemC before and after clock edges for both
algorithms, including multiple ports, unknown values, invalid indices, and
snapshot replay.

For a pipelined controller, `ReplacementReservations` provides a persistent,
caller-owned reservation mask. A controller reserves a selected way, excludes
the mask from later eligibility, and releases it after commit or cancellation.
Releases precede reserves on the same edge; invalid operations are reported. The
bank tracks occupied ways, not transaction ownership, so the controller must
prevent one transaction from releasing another's reservation. The built-in
policies also accept `ReplacementCommitInterface` ports to update policy state
using a previously reserved index. Accesses are processed first, then deferred
commits, then current allocations, each in port order. Custom `CacheReplacement`
factories can provide `buildWithCommits` when they support this interface. The
existing blocking cache presets still commit using their current allocation
ports.

An optional `dataMemory` `MemoryArrayFunctor<T>` selects data storage
independently of tag storage. Its capabilities describe fixed read latency, port
limits, separate read/write and combined simultaneous access limits, collision
semantics, masked writes, and whether it is synthesizable, external, or
simulation-only. Construction checks the requested geometry, payload shape,
concurrency, and latency, and verifies the returned module's ports and latency.
The builder is responsible for implementing the advertised capacity and
semantics. These raw memory ports do not provide arbitration or backpressure;
the caller must enforce the declared limits. The present cache presets
conservatively require their connected reads and write to be simultaneously
available and require zero-latency reads. They reject a factory that cannot meet
those requirements; the factory does not by itself make a latency-bearing SRAM
usable by them. When `dataMemory` is supplied it takes precedence over
`dataStorage`.

The default tag storage is `parallelAssociativeMemoryFunctor`. A custom
`tagMemory` functor must support two zero-latency lookups, a zero-latency
indexed update, synchronous validity reset, a validity mask, and a combinational
indexed side read. Incompatible implementations are rejected when the cache is
constructed. See the associative contract below for the remaining selection and
collision requirements.

For example, select the tag and replacement implementations independently when
constructing a cache; the cache controller and caller-owned ports do not change:

```dart
final cache = Cache<Logic>.fullyAssociative(
  clk: clk, reset: reset, lookup: lookup, fill: fill, entryCount: 4,
  tagMemory: useBehavioral
      ? behavioralParallelAssociativeMemoryFunctor
      : parallelAssociativeMemoryFunctor,
  replacement: useBehavioral
      ? CacheReplacement.behavioral(BehavioralReplacementKind.roundRobin)
      : CacheReplacement.roundRobin,
);
```

In ROHD, the behavioral choices execute as port-compatible Dart modules. For
SystemC, build the enclosing `parent` module containing this cache, then
explicitly select those behavioral instances:

```dart
final hierarchy = generateBehavioralSystemCHierarchy(
  parent,
  select: (module) =>
      module is BehavioralParallelAssociativeMemory ||
      module is BehavioralReplacementPolicy,
  unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
);
// Include hierarchy.source and instantiate hierarchy.topClassName in SystemC.
```

The hierarchy exporter uses two-state SystemC ports. Other behavioral leaves
need their own supported model and selection; unselected modules must be
supported by ROHD's SystemC synthesizer. In particular, selecting the default
RTL tag memory does not automatically create a behavioral replacement. The
serialized-cache regression also demonstrates selecting `InferredSram` alongside
behavioral tags and replacement policy while the controller remains structural.

Unknown address or control bits can produce unknown responses and state;
uncertain set selection only affects sets compatible with known address bits. Z
bits written to cached data or keys are stored as X.

### Multiple lookup and fill ports

`MultiPortCache` composes multiple lookup and fill ports. For example, a
two-set, two-way cache with two ports of each kind can be constructed as:

```dart
final lookups = List.generate(2, (_) =>
    CacheLookupPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 32)));
final fills = List.generate(2, (_) =>
    CacheFillPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 32)));
final cache = MultiPortCache<Logic>(
  clk: clk, reset: reset, lookups: lookups, fills: fills,
  setCount: 2, waysPerSet: 2,
  readDuringFill: CacheReadDuringFill.forward,
  evictionConcurrency: CacheEvictionConcurrency.parallel,
);
```

Drive each lookup's `valid` and `address`, and consume `ready`, `hit`, and
`data`. Drive each fill's `valid`, `address`, `data`, and `evictionReady`, and
consume `ready`, `evictionValid`, `evictionAddress`, and `evictionData`. Every
port must have the same address width and declared payload layout. Keep a
request stable until its valid/ready handshake on a rising edge.

All lookups can proceed concurrently. By default, each set accepts at most one
fill per cycle, including updates to existing entries; lower-numbered fill ports
win same-set conflicts and the others must wait. Fills to different sets can
transfer together. Set `maxFillsPerSet: 2` in the example to permit two same-set
fills to distinct ways in one cycle. The limit must be positive and no greater
than the number of fill ports. Same-block requests still give priority to the
lowest-numbered valid port; the others must retry. Selection is in port order
and counts selected requests, even if a selected request cannot obtain a way.
Ways hit by selected fills are excluded from allocations in that cycle, so
available grants can be fewer than the configured maximum.

The default `oldData` lookup mode reports the pre-edge state; `forward` supplies
an accepted same-block fill on that cycle, including a fill that will need
eviction.

Unlike `Cache`, `MultiPortCache` accepts a fill requiring eviction into an
internal buffer before its eviction is accepted. At that fill handshake, the
victim is reserved; the entry is overwritten only when its eviction response
transfers. With the default one-fill-per-set scheduler, replacement state
advances at acceptance. With `maxFillsPerSet > 1`, eviction-requiring fills
defer their replacement update until their eviction handshake; other accepted
fills update replacement state at acceptance. During any pending eviction, all
new lookups and fills are blocked. `parallel` presents all buffered evictions on
their respective fill ports, each held until accepted. `oneAtATime` instead
presents the lowest-numbered pending eviction and waits for its handshake before
presenting another. Reset suppresses transfers and cancels all buffered fills
and responses. External logic handles backing-store writes.

The default scheduler requires one tag lookup per lookup port plus one fill
probe per set, one indexed update, a validity mask, and one indexed side read.
The multi-fill scheduler instead instantiates one fill probe, indexed update,
and indexed side read per fill port in each set. It also requires a replacement
factory with `buildWithCommits` and enough zero-latency data-array ports for
every lookup and victim read and every fill write. Custom functors must
advertise these capabilities even when `maxFillsPerSet` is smaller than the
total fill-port count. Current data backends are only the zero-latency
flop-based `RegisterFile` and simulation-only behavioral model. The latter is
not a physical SRAM model; latency-bearing or physically port-limited SRAM
requires a separate storage contract and scheduling and is not supported by this
cache yet.

## Transactional Cache Composition Contracts

The following contracts and reference implementations are separate from `Cache`
and `MultiPortCache`: those existing blocking presets retain their same-cycle
lookup and fill/eviction behavior.

### Resource scheduling

`CacheSchedulerPorts` describes candidates competing for a vector of resources.
A resource can represent a tag port, a bank read or write port, an MSHR slot, a
response-buffer slot, or another controller-defined unit. The controller drives
the available units and each candidate's `valid` and demand vector. It also
supplies a conflict bit vector for every candidate. A pair conflicts if either
corresponding bit is set; self-conflict bits are ignored. The scheduler drives
each candidate's `grant` and the `invalidInputs` output.

On the sampling edge, `valid && grant` transfers the whole decision: every
resource in the demand vector is allocated together, never partially. Granted
demand sums must not exceed the corresponding available units, and conflicting
candidates must not both be granted. A grant implies valid. Each availability
and enabled demand must be at most that resource's declared capacity. If a
definitely invalid value occurs, `invalidInputs` asserts and all grants are
suppressed; reset also suppresses grants. Unknown controls or resource values
may propagate X and must not be interpreted as a known transfer. A caller is
responsible for connecting all port signals.

`CacheSchedulerBuilder` is the construction boundary for an implementation. It
does not promise fairness, work conservation, a priority rule, or a specific
combinational path. The implementation must document these properties and any
additional restrictions. A controller can encode bank conflicts and same-block
hazards as resources or conflicts; a custom scheduler can enforce additional
constraints. Each grant accounts for **that cycle** only. The controller
separately owns in-flight transactions, future-stage credits, victim
reservations, and release/cancellation. In particular, a grant does not by
itself reserve an entry over multiple cycles.

`FixedPriorityCacheScheduler` is a stateless, greedy implementation: it visits
candidates in ascending port order and grants each feasible request. It can
starve lower-priority candidates. For example:

```dart
final scheduling = CacheSchedulerPorts(requestCount: 2, capacities: [1, 2]);
final scheduler = FixedPriorityCacheScheduler(
  clk: clk, reset: reset, ports: scheduling,
);
// Connect available, request valid/demand, and conflict inputs, then consume
// the grant and invalidInputs outputs.
```

For example, with availability `[1, 2]`, no conflicts, and two valid requests
each demanding `[1, 1]`, request 0 is granted and request 1 waits because the
first resource is exhausted. If request 1 instead needs `[0, 1]`, both can be
granted on the same edge. These grants do not reserve next-cycle resources.

`BehavioralFixedPriorityCacheScheduler` is a stateless Dart implementation of
the same interface and priority rule. It has no internal state to snapshot and
cannot be synthesized as RTL. It also provides a SystemC behavioral definition
with either four-state or two-state ports for integration at its port boundary.
A three-way test compares its Dart and SystemC behavior with generated Verilog,
including invalid inputs, asymmetric conflicts, reset, and X/Z inputs. This
equivalence test covers the scheduler itself, not an entire cache controller.

`CacheSchedulerPorts` is a `PairInterface` containing one request subinterface
per candidate; the controller is the provider and the scheduler is the consumer.
Its resource geometry is retained by `clone()`.

### Transaction ports and operations

`CacheTransactionPort<T, M, C, R>` groups three irrevocable ready/valid
channels: requests into the core, responses out, and eviction events out. `T` is
block data, `M` is metadata stored with each block, `C` is request context, and
`R` is implementation-specific result or error detail. All retain their declared
typed payload shapes. Request, response, and eviction schemas use the same
token; context is returned unchanged. Block addresses are block addresses, not
byte addresses. The port is a `PairInterface` with request, response, and
eviction subinterfaces and a `tokenConflict` sideband. The caller is the
provider; the response and eviction subinterfaces have reversed roles.

```dart
final port = CacheTransactionPort<Logic, Logic, Logic, Logic>(
  addressWidth: 32, tokenWidth: 4,
  dataSchema: Logic(width: 128), writeMaskWidth: 16,
  lineMetadataSchema: Logic(width: 2), // e.g. dirty and valid protocol state
  contextSchema: Logic(width: 8),
  resultSchema: Logic(width: 4),
);
```

The producer holds valid and payload stable until the rising edge with both
valid and ready. Every accepted request owns its token on that port until its
response transfers, unless reset cancels it. The caller must not reuse a token
while it is owned; token namespaces are separate across ports. The core asserts
`tokenConflict` and does not accept an offered request whose token is still
owned. Ownership lasts through the response-transfer edge, so that token can be
accepted again no earlier than the following cycle. Every accepted request
produces exactly one response unless reset cancels it. An implementation may
accept other requests before completing earlier ones. It must not accept a
request unless it can eventually retain its response and all non-backpressurable
intermediate results. Evictions and responses are independently backpressured;
an offered event remains stable while stalled.

Built-in operation encodings are the `.code` values:

| Operation | Effect | Completion status |
| --- | --- | --- |
| `lookup` | Read a block and its stored metadata without changing them. | `hit` or `miss` |
| `fill` | Install the complete supplied block and metadata. Updating the same block is not an eviction. | `completed` |
| `update` | If present, update selected data units and replace its metadata; do not allocate on miss. | `hit` or `miss` |
| `invalidate` | Remove the matching entry, if present. | `hit` or `miss` |

An unsuccessful operation returns `error`, with detail interpreted according to
the implementation's `R` contract. A failed built-in operation does not change
the cache state, though an already accepted external event cannot be undone.
Unsupported operations and unsupported masks must not be silently treated as
success. For `lookup`, `update`, and `invalidate`, a `hit` response contains the
pre-operation block data and metadata; otherwise these fields are zero and must
not be used as a block. The `result` payload is implementation-specific. A fill
supplies a complete block; its write mask is ignored. For an update, mask bit
zero controls the least-significant data unit; all units have `data.width /
writeMask.width` bits. A set bit replaces its unit and a clear bit preserves it.
An all-zero mask may still update metadata. Cores advertise whether non-all-ones
masks are supported.

Before removing a valid victim for a fill, the core emits an eviction event with
its old address, data, and metadata. The event transfers before that entry is
overwritten or the request's response is offered. A successful invalidation
similarly emits an event when `reportsInvalidations` is advertised; otherwise
the caller must not depend on receiving one. Event acceptance transfers
responsibility to the consumer, not necessarily durable backing-store
completion. An adapter requiring durable completion must delay its
acknowledgement or track the external write separately. Reset cannot undo a side
effect already accepted by another component.

`CacheTransactionCore` exposes its ports and `CacheTransactionCapabilities`.
Capabilities specify supported operations, total outstanding capacity, per-port
response ordering, same-block ordering across acceptance edges, and the
tie-break for same-block requests accepted on one edge. Different ports have no
implied cross-port response order. An `implementationDefined` ordering requires
the core to document its actual rule; it is not permission to silently change
the rule per transaction. An adapter must reject a core whose guarantees cannot
implement its protocol.

The built-in operations are intentionally small. Implementations and adapters
can agree on additional numeric operation codes, using a wider `operationWidth`,
the typed context for extension-specific inputs, and the typed result for
outputs. They can likewise use a wider `evictionCauseWidth` for agreed event
causes. `extensionOperations` advertises additional codes; `validatePort`
rejects a port unable to encode them. Extension semantics, including atomicity
and event behavior, must be specified by the implementation and adapter; merely
declaring a code does not implement coherence, atomics, miss coalescing, bulk
invalidation, or cancellation. The base interface offers no per-request
cancellation operation. Reset cancels in-flight requests and suppresses
transfers while asserted; external components must also discard or distinguish
stale responses from before reset.

### SRAM and transaction ownership

A pipelined core can compose the existing `AssociativeMemoryFunctor`,
`MemoryArrayFunctor`, replacement policy, reservation bank, scheduler ports, and
transaction channels. `CacheTransactionCoreBuilder` supplies a construction
boundary with caller-owned ports and a typed, implementation-specific options
object. A particular SRAM core must define and validate its own options for
geometry, tag/data/metadata factories, scheduler, pipeline capacity, and buffer
depths; these contracts do not silently pick an SRAM or promise a universal
preset. The returned binding contains both its RTL module and its core
interface.

The core—not the raw memory array—tracks request tokens, associates
fixed-latency read results with their requests, handles bank/port restrictions,
and reserves enough response/event storage before issuing a read whose result
cannot stall. It must keep a victim reserved until the corresponding data and
metadata are captured and the eviction transfers. It must publish a new valid
tag only when its data and metadata are available, and prevent a concurrent
lookup from observing a torn entry. Read/write collision and forwarding behavior
must satisfy the advertised same-block ordering, or the operation must be
stalled. Reset must also invalidate or drain stale pipeline results before they
can be associated with new tokens.

`SerializedCache` is a simple reference implementation with one outstanding
operation globally and lowest-port-first request arbitration. It supports fixed
positive-latency data arrays, all four built-in operations, masked updates, and
invalidation events. The default tags are parallel flops; custom tags must meet
its zero-latency lookup, validity-mask and indexed-side-read requirements.
Metadata uses registers, and replacement must support deferred commits. A fill
or invalidation that removes a valid entry waits for its eviction event to
transfer before changing that entry. It does not pipeline multiple operations or
implement miss servicing. For example, with the transaction `port` declared
above:

```dart
final core = SerializedCache<Logic, Logic, Logic, Logic>(
  clk: clk, reset: reset, ports: [port],
  setCount: 16, waysPerSet: 4, dataMemory: inferredSramArray<Logic>(),
);
```

For a small SRAM-backed block buffer, send a `fill` for address 5 with a fresh
token, wait for its `completed` response to transfer, then issue a `lookup` with
another available token. A hit returns the installed data and metadata. If a
later fill displaces a valid line, accept its eviction event before the fill can
finish. The controller handles one operation at a time; it does not fetch a
missing block from external memory.

The factory supplies one data array per set with a fixed positive read latency
and one read and one write port. The core guarantees at most one enabled data
access per set per cycle. More generally, callers can pass
`maxConcurrentAccesses` to `MemoryArrayFunctor.call` when their scheduler
enforces a tighter combined read/write limit than the sum of the separate
maxima; without it the sum is required. The functor validates capabilities, but
does not enforce runtime scheduling. Existing blocking cache presets still
reject latency-bearing or insufficiently ported arrays. The contracts do not
assume that tags and data have the same backing, latency, or banking.
`inferredSramArray` is a shared one-cycle, single-port array factory rather than
a cache-specific SRAM. The serialized controller never enables a read and write
to the same set on one cycle. Tags remain in the independently supplied
associative memory, which defaults to parallel flops. `metadataMemory` can
select a separate shared array factory, but it must have combinational reads;
its default is a flop-backed register file. A synchronous SRAM cannot be used
for this metadata path without changing the controller pipeline.

The serialized RTL controller can be exercised with both a behavioral data array
and `CacheReplacement.behavioral(...)`; the controller itself remains RTL. Its
outputs are compared each cycle against the flop-array and RTL-policy
configuration for data latencies one through three. This is not yet a standalone
software or SystemC implementation of the serialized cache.

### Concurrent behavioral cache

`BehavioralCache<T, M, C, R>` implements `CacheTransactionCore` for ROHD
functional simulation. It is not synthesizable and is not an RTL or SystemC
model. It accepts caller-owned typed transaction ports and has configurable set
and way counts, total outstanding capacity, operation latency, and maximum
operations begun per cycle. Several ports can transfer on the same edge. When
capacity is limited, lower-numbered ports win; tokens remain owned until their
response transfers. Responses are ordered on each port. Operations in the same
set take effect in acceptance order, while independent sets can proceed even
when an eviction is stalled. Each port can present one eviction at a time;
responses and evictions remain stable under backpressure.

The default replacement policy is round robin with invalid-way preference.
Supply a `BehavioralCacheReplacement` to model another policy. Its `select`
method must not change policy state; `access` and `allocate` are called when the
corresponding operation takes effect. Use independent replacement state for each
cache. This concurrent model still uses its callback-based replacement
interface; it has not yet been migrated to the shared replacement-port protocol.

The core preserves the four built-in operations' existing meanings. It also
advertises two extension encodings, requiring `operationWidth` of at least three
bits:

* `BehavioralCacheOperation.readThrough` (4) returns a cached block on a hit; on
  a miss it fetches and installs the backing block. The response is `hit` or
  `miss` according to the original lookup, and **both** carry the block data and
  metadata.
* `BehavioralCacheOperation.writeAllocate` (5) performs a masked update,
  fetching and installing the backing block on a miss. Its `hit` or `miss`
  response carries the pre-update block and metadata. The request's metadata
  replaces the line metadata, including when its mask is zero.

`BehavioralCacheBackingStore` holds block data and opaque metadata; unwritten
addresses read as unknown. Initialize it explicitly where known values are
needed. Each replacement or invalidation still emits an eviction event, and the
model writes the complete evicted block and metadata to the backing store when
that event transfers, before changing the cache entry. It does this for every
eviction, without interpreting a dirty bit. Fetches and writebacks are immediate
behavioral operations, not a model of backing-store latency, errors, coherence
or an external bus.

The backing store implements `MemoryStateAccess`: `peek` distinguishes an absent
block from stored X, and `poke` replaces its data while preserving existing
metadata (or initializing metadata to X for a new block). Its detached
`snapshot` includes data and metadata. `load` validates the complete image
before overlaying or replacing the sparse state.

The cache provides raw `peek` and `poke` for resident blocks; `poke` requires no
outstanding transactions and rejects inserting into a full set. Its full
`snapshot` and `restore` include resident lines, backing storage, replacement
state, outstanding requests, their timing and responses, and eviction-offer
order. The same operations are exposed through `stateTransactions`. These images
do not capture external channel peers or reverse already transferred effects: a
caller restoring in-flight state must coordinate the rest of the simulation. The
default round-robin policy supports snapshots. A custom policy must implement
`SnapshotableBehavioralCacheReplacement`; custom backing-store subclasses are
not yet supported by full cache snapshots. Unsupported configurations report
that capability explicitly.

```dart
final backing = BehavioralCacheBackingStore(
  addressWidth: 32, dataWidth: 128, metadataWidth: 2,
);
final core = BehavioralCache<Logic, Logic, Logic, Logic>(
  clk: clk, reset: reset, ports: [port],
  setCount: 16, waysPerSet: 4, maxOutstanding: 8,
  operationsPerCycle: 2, operationLatency: 1, backingStore: backing,
);
```

Reset cancels pending transactions and invalidates cache entries and replacement
state, but retains the backing store. It does **not** flush modified lines, so
callers must arrange any required flush before reset. Data and metadata retain
four-state bits, with stored Z normalized to X; an unknown update-mask bit
preserves a bit when both alternatives agree. Unknown reset or sampled handshake
controls, and unknown operation, address, or token at request acceptance, raise
`StateError` rather than silently choosing a transaction. The model does not
itself enforce coherence between multiple caches sharing a backing store.

### Protocol adapters

`CacheProtocolAdapter<Q, S, T, M, C, R>` exposes external request and response
channels and one transactional cache port. `Q` and `S` are protocol-specific;
the adapter consumes `Q`, supplies `S`, and drives/consumes the cache port. It
owns token allocation, request-to-response association, miss handling,
backing-store traffic, and any required reordering or protocol state. Multiple
cache ports or extra protocol channels can be exposed by a concrete adapter;
they are not implied by this minimal boundary. `CacheProtocolAdapterBuilder`
provides a corresponding typed construction boundary with
implementation-specific options, and returns both the RTL module and adapter
interface.

An adapter must check its peer's capabilities, channel dependency contracts, and
payload schemas before composition. It must hold outgoing requests and responses
stable when required, update its tracking state only on the relevant handshake,
and avoid reusing a token before the corresponding completion. If the external
protocol can return stale work after reset, the adapter must drain it or use an
epoch/other disambiguation before reusing identifiers.

`CacheTransactionAdapter` provides protocol-neutral transport for one cache port
using the same typed payloads on its external channels. It stages one request
and tracks up to `maxOutstanding` distinct tokens, including the staged request.
It forwards matched responses and evictions and exposes `duplicateRequest`,
`invalidResponse`, and `invalidEviction` diagnostics. Unmatched responses and
events are held rather than forwarded. Matching is against accepted external
requests, so it assumes a compliant core never responds or emits an event before
accepting the corresponding staged request. For example, using the `port` and
`core` above:

```dart
final requests = IrrevocableReadyValidInterface(port.requests.data.clone());
final responses = IrrevocableReadyValidInterface(port.responses.data.clone());
final evictions = IrrevocableReadyValidInterface(port.evictions.data.clone());
final adapter = CacheTransactionAdapter(
  clk: clk, reset: reset, requests: requests, responses: responses,
  evictions: evictions, cache: port, maxOutstanding: 2,
);
```

Connect the external request, response, and eviction channels to their
producer/consumers. This adapter does not implement a bus protocol, service
misses, issue backing-store traffic, or enforce durability. Protocol-specific
adapters and nonblocking, multi-outstanding SRAM cores remain separate work. For
example, a frontend can submit token 1 and hold its request stable until
accepted. The adapter stages the request and prevents another request using
token 1 until the matching response transfers. Configure `maxOutstanding` for
the frontend's capacity, but respect the connected core's advertised capacity
too; the adapter does not increase the serialized core's capacity.

## Choosing an Implementation

`ParallelAssociativeMemory` is synthesizable flop-based storage with parallel
comparison of all valid entries. It is intended for small, highly ported
structures. Its indexed updates commit on the clock edge; enabled lookups are
combinational and observe the updated state after that edge.

The abstract `AssociativeMemory` boundary describes fixed-timing raw ports: each
enabled lookup port accepts a request every cycle. A positive-latency
implementation uses `SynchronousAssociativeLookupPortInterface`, whose `valid`
marks the response cycle. That interface is a contract for other
implementations, not a pipelined mode of `ParallelAssociativeMemory`.

## Port-Compatible Associative Behavioral Model

`BehavioralParallelAssociativeMemory` is a port-compatible simulation
implementation of `ParallelAssociativeMemory`, selected with
`behavioralParallelAssociativeMemoryFunctor`. It supports combinational lookup,
validity tracking, multiple indexed side reads and edge-sampled multiport
updates with either RTL priority. It uses shared sparse storage and starts
unknown until synchronous reset. An unknown reset on a rising edge sets all
entries unknown in both RTL and this model. Invalid clock transitions poison
state in ROHD RTL and the Dart and four-state SystemC models; Verilog edge
sensitivity differs (for example, `1` to `X` does not trigger a positive edge).
Use known clock transitions for cross-backend equivalence. Execution snapshots
and `stateTransactions` capture stored keys and validity; restore at a settled
simulation boundary and coordinate external signals separately.

For SystemC, the hierarchy exporter substitutes its port-compatible behavioral
definition for selected instances while generating the parent normally. Direct
`generateSystemC` export is also available when integrating the component into
an independently written SystemC testbench. Direct exports support four-state or
two-state boundaries and snapshots; hierarchy exports use two-state boundaries.
Two-state exports report unknown outputs unless `zeroUntilReset` was explicitly
selected and reset has not yet been sampled. Dart, Verilog, and SystemC
regressions cover unknown enables and indices, reset, invalid side reads,
collisions and both match priorities. This does not provide a behavioral model
of the entire cache controller: cache-level snapshot and controller equivalence
remain separate work.

Keys and port indices may be wider than 64 bits. Use a width-preserving
`LogicValue` (for example, `LogicValue.ofBigInt`) for wide keys. Entry indices
refer to the finite configured entry count; high index bits are checked before
an index is converted to a host integer. Directed regressions exercise wide keys
and indices, collisions, duplicate selection, invalid high-bit aliases, unknown
bits, and snapshot replay.

## Clock-Stepped Software Reference

`AssociativeSoftwareModel` is a standalone software reference model, not an
`AssociativeMemory` module or a drop-in ROHD port implementation. Construct it
with an `AssociativeMemoryRequest` and call `step` once per modeled clock edge,
passing one lookup and update per configured port. A null request represents a
disabled port. Zero-latency requests complete on that call; positive latencies
count subsequent calls. Lookup-before/after-update policy refers to updates
*committing* on the same step. Returned lists contain either the completion for
each lookup port or null.

The model supports exact and masked four-state key matching, multiple
lookup/update ports, index-priority selection, update collision policies,
duplicate-key policy, and configurable lookup and update latency. A
context-qualified request requires an explicit pure, stateless
`AssociativeSoftwareMatcher`. Undefined lookup/update behavior is rejected. Keys
and validity preserve X and normalize stored Z to X. The software API uses
integer update indices and null/enabled requests; it does not model uncertain
enable or index signals. Under the disallow-duplicates policy, any potentially
duplicate unknown keys are conservatively rejected. Exact and masked comparisons
return a definite mismatch if any compared bit is known to differ, even when
other bits are unknown. This matches Verilog logical equality and is shared by
the RTL matcher and Dart and SystemC models.

`entry`, `peek`, `poke`, `writeEntry`, `snapshot`, and `load` provide raw
indexed state access. Raw writes and loads require pending updates to drain.
`snapshotExecution`, `restoreExecution`, and `stateTransactions` also capture
pending lookups, pending updates, and the step counter. Reset clears entries and
cancels pending operations when clear-validity reset is configured. External
clients and their state are not part of an execution image.

`generateSystemC` exports a clock-stepped SystemC module, discoverable through
`generateBehavioralSystemC`. It samples all requests on rising clock edges,
including zero-latency lookups; it is **not** a combinational replacement for
`ParallelAssociativeMemory`. Its ports have the names in the model description:
scalar ports use `sc_logic`, and key, index, mask, and match-vector ports use
`sc_lv`, including one-bit vectors. An output `valid` qualifies each sampled
lookup result. The generated `snapshot()`/`restore()` methods include pending
work, outputs, and clock-edge bookkeeping; external signals and events must be
coordinated separately.

The SystemC exporter currently supports exact or masked matching, synchronous
reset, duplicate keys allowed, and four-state ports. It reports unknown enables
and invalid indices as SystemC errors. Two-state ports, asynchronous reset,
duplicate enforcement and context-qualified matching are explicitly rejected
rather than silently substituted. A standalone cache behavioral SystemC export
is not yet available.

## Ports and Typed Keys

- An `AssociativeUpdatePortInterface` supplies `en`, `index`, `key`, and
  `entryValid`. An enabled update writes the key and validity at the chosen
  index; setting `entryValid` low invalidates that entry.
- An `AssociativeLookupPortInterface` supplies `en` and `key`, and receives
  `hit` and `index`. The index is zero on a miss. An optional `matchVector` has
  one bit per entry.
- `TypedAssociativeUpdatePortInterface<T>` and
  `TypedAssociativeLookupPortInterface<T>` retain a key schema through clones
  and module ports. Drive the port's cloned key, not the schema object.

All ports must have matching key and index widths; the index must represent
every entry, and at least one lookup port is required. Declared structured
layouts and enum mappings must be compatible, including typed-array dimensions
and codecs. The parallel implementation compares packed key bits, not
domain-specific numeric values.

## Parallel Memory Example

This example permits duplicate keys, chooses the lowest matching index, returns
all matches, and makes the highest-numbered update port win if multiple ports
update the same entry.

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

Drive the update and lookup inputs on these caller-owned ports. For example, to
store a key, assert `update.en` and `update.entryValid` with `update.index` and
`update.key` before the sampling edge. Assert `lookup.en` and drive `lookup.key`
to search. When lookup is disabled, `hit`, `index`, and the match vector are
zero. `memory.validCount`, `memory.full`, and `memory.empty` are available only
when `enableValidTracking` is true.

For typed keys, replace the scalar ports with
`TypedAssociativeUpdatePortInterface<YourKey>(schema, indexWidth: 2)` and
`TypedAssociativeLookupPortInterface<YourKey>(schema, indexWidth: 2,
matchEntryCount: 4)`. Both ports clone the schema; wire or drive their `key`
fields. If requesting a match vector, every lookup port must have
`matchEntryCount` equal to `entryCount`.

### Supported Contract

The parallel implementation requires zero lookup and update latency, duplicate
keys allowed, lookup-after-update, synchronous reset that clears validity, and a
synthesizable implementation kind. It supports lowest- or highest-index match
selection, either result shape, and lowest- or highest-port-wins collision
resolution. It does not enforce key uniqueness, reject colliding updates
dynamically, or provide an asynchronous reset. Incompatible contracts are
rejected during construction.

Its default matcher uses four-state logical equality. Unknown key bits can
therefore make a match result unknown; this is not case equality. Z bits
entering stored keys or validity are converted to X. An uncertain update affects
only entries compatible with the known index bits.

## Selecting an Implementation

`AssociativeMemoryRequest` describes the desired shape and semantics.
`AssociativeMemoryCapabilities` declares what an implementation supports,
including timing, selection, update precedence, reset, and optional state
operations. `AssociativeMemoryFunctor.resolve(request)` validates a request
against those capabilities and returns an `AssociativeMemoryBinding` with the
effective contract. Inspect that contract before composing any timing or
adaptation logic, then call `binding.instantiate(...)` once with matching ports.

`parallelAssociativeMemoryFunctor` is the supplied parallel-flop functor. Its
callable form resolves and instantiates an exact request; it rejects a resolved
timing or semantic difference rather than silently adapting it. Set
`requiresValidityMask: true` when invoking the functor to request the
`AssociativeValidityMaskProvider` output. The parallel implementation also
enables its valid-count, full, and empty outputs when this mask is requested.

For indexed inspection, supply an `AssociativeIndexedSideReadRequest` to either
the parallel constructor or the functor's callable form. When resolving a
binding separately, set `requiresIndexedSideRead` on the request and pass a
matching side-read request to `instantiate`. The resulting memory implements
`AssociativeIndexedSideReadProvider`; its `sideReadResponse` contains the packed
key and stored validity. The read is combinational and observes the old state
before an update edge and the new state after it. An out-of-range index returns
zero key and invalid; an index containing X or Z returns X for both fields.
Stored keys retain their packed representation even when invalid. For multiple
independently indexed reads, set `indexedSideReadCount` and pass matching
`sideReadRequests`. A custom functor binds one or more such requests through its
optional `buildMultipleSideReads` callback. Its original `build` callback
retains its existing signature. The older `requiresIndexedSideRead`
capability-only request can still be resolved and instantiated without passing a
side-read port; in that case the implementation and caller are responsible for
arranging the read themselves. A single bound side read requires an
`AssociativeIndexedSideReadProvider`; multiple bound side reads require an
`AssociativeMultiIndexedSideReadProvider`. The builder must connect each
supplied index to its corresponding response.

## Replacement Policies

Replacement is separate from associative storage. When `enableValidTracking` is
true, `ParallelAssociativeMemory.validMask` exposes one validity bit per entry.
Connect it to a `RoundRobinReplacement` or `TreePseudoLruReplacement`, together
with an eligibility mask. Both prefer invalid eligible entries before evicting
valid ones. Round robin supports any positive entry count; tree pseudo-LRU
supports one entry or a power of two and approximates, rather than exactly
tracks, least-recent use.

For a four-entry allocation table, keep validity and eligibility in the
controller and ask the policy for a candidate:

```dart
final allocation = ReplacementAllocationInterface(4);
final policy = RoundRobinReplacement(
  clk: clk, reset: reset,
  validMask: validMask, eligibleMask: eligibleMask,
  accesses: [], allocations: [allocation], entryCount: 4,
);
// Drive allocation.en and allocation.commit; consume allocation.valid,
// allocation.index and allocation.evict.
```

For example, if entry 0 is invalid and eligible, an enabled allocation can
select it without eviction. Commit on the accepting edge after reserving the
selected entry; if it is valid, first handle the old entry's data.

Each `ReplacementAccessInterface` reports an accessed index. Each
`ReplacementAllocationInterface` requests a candidate with `en` and receives
`valid`, `index`, and `evict`. The caller asserts `commit` only when the
allocation and any required eviction can actually be accepted. A valid selection
without a commit does not update replacement state. `invalidAccess` reports an
enabled out-of-range access, and `invalidCommit` reports a commit without a
valid selection.

Access ports are processed in order, followed by deferred commits and then
allocation ports in order. Earlier valid selections reserve their entries from
later allocation ports in the same cycle, even without a commit; only committed
allocations update policy state. The caller must commit the selected index on
the sampling edge. Selection is combinational and is not held stable across
cycles if accesses, validity, eligibility, or other commits change; a stalling
cache must reserve or revalidate its victim. Reset is synchronous. The RTL
policies do not expose policy-state snapshot and restore; the behavioral policy
supports them as described above.

The indexed side read exposes the stored key and validity, not associated
payload data. An eviction controller must also retrieve that data before
committing its replacement.

## Matching and Selection Without Storage

`AssociativeMatcher` compares a query with a list of keys under a valid mask,
returning `matchVector`, `hit`, and `multipleMatches`. Its default comparator
uses logical equality; a custom comparator must return one bit per entry.
`AssociativeMatchSelector` selects a match, exposing `valid`, `selectedIndex`,
and `selectedOneHot`. By default it selects the lowest matching index; optional
selection values and a preference callback support other policies.

```dart
final matcher = AssociativeMatcher(
    query: query, storedKeys: keys, validMask: validMask);
final selector = AssociativeMatchSelector(matchVector: matcher.matchVector);
final selected = selector.selectedIndex;
```

These are combinational building blocks: neither owns key storage nor performs
clocked updates. Give custom comparison and selection functions distinct
`comparisonName` and `selectionName` values when their generated logic differs,
so module definition identities remain distinct.

## Migrating From Legacy CAM

`Cam` and `TagInterface` remain available but are deprecated. The replacement is
not behavior-identical: legacy lookup ignores `en` and uses case matching for
unknown bits, whereas parallel associative lookup is enable-gated and uses
logical equality. Stored Z bits are normalized to X in both. Check duplicate
selection, update precedence, reset, and timing against the new contract before
migrating. See the [legacy CAM documentation](memory.md#legacy-cam) for its
ports and behavior.
