# ROHD-HCL Copilot Instructions

## Project Overview

ROHD-HCL (ROHD Hardware Component Library) is a Dart-based hardware component library built on [ROHD](https://intel.github.io/rohd-website/). It provides reusable, configurable digital hardware modules that can be simulated in Dart and converted to SystemVerilog. Think of it as building hardware using Dart's type system and OOP instead of traditional HDLs.

**Key Concept**: All components are `Module` subclasses that instantiate hardware during construction - no "elaboration" phase exists. Signals are `Logic` objects connected via `<=` assignment operator (not `=`).

**Development Status**: This repository is actively developing new cache components and infrastructure. Recent additions include `DirectMappedCache` and `CachedRequestResponse` modules for request/response caching with ready/valid protocols.

## Architecture & Core Patterns

### Module Construction Pattern

**CRITICAL**: Always follow this port connection pattern to avoid trace errors:

```dart
class MyComponent extends Module {
  Logic get output => output('result');
  
  MyComponent(Logic input, {required int param}) : super(...) {
    // 1. FIRST: Create internal copies of inputs using addInput
    input = addInput('input', input, width: input.width);
    
    // 2. THEN: Add outputs (inferred from logic, not passed as args)
    addOutput('result', width: computedWidth);
    
    // 3. FINALLY: Connect internal logic
    output <= input.rotateLeft(param);
  }
}
```

**Why**: External `Logic` signals cannot be directly used internally. The `addInput` creates internal copies and handles port connection. Violating this causes trace errors only when the module is instantiated in another module.

### Assignment Operators

**CRITICAL**: ROHD has two distinct assignment operators:

- **`<=`** (gets): Hardware connection for `Logic` signals (synthesizable)
  ```dart
  output <= input;  // Connect output to input wire
  ```

- **`<`** (conditional): Assignment within `Combinational`/`Sequential` blocks
  ```dart
  Combinational([
    result < a + b,  // Use < inside always blocks
  ]);
  ```

**Never use `=`** for signal assignment in hardware - it's only for Dart variable assignment.

### Signal Types Hierarchy

1. **`Logic`**: Basic signal with width. Use `addInput()` helper.
2. **`LogicArray`**: Multi-dimensional uniform arrays. Use `addInputArray()`.
3. **`LogicStructure`**: Hierarchical named fields (e.g., `FloatingPoint`, `FixedPoint`). Use `addTypedInput()` for typed signals.
4. **`Interface`**: Directional protocol bundles (e.g., `ApbInterface`, `SumInterface`).
   - **`PairInterface`**: Bidirectional with `pairConnectIO()` for producer/consumer filtering.
   - **`DataPortInterface`**: Use `connectIO()` method for cloning.

### Interface Patterns

#### PairInterface for Bidirectional Protocols

`PairInterface` is designed for producer/consumer protocols where signals have directional roles. The `ReadyValidInterface` is a key example:

```dart
// Creating a generic ready/valid interface for any data type
class MyProducer extends Module {
  late final ReadyValidInterface<Logic> intf;
  
  MyProducer(Logic clk, Logic reset) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    
    // Create interface as output (producer role)
    intf = ReadyValidInterface<Logic>(dataWidth: 32);
    intf = ReadyValidInterface.clone(intf)
      ..pairConnectIO(this, intf, 
        PairRole.provider,  // This module provides data
        outputTags: {Interface.Port.clk, Interface.Port.reset});
    
    // Drive valid and data signals
    intf.valid <= /* logic */;
    intf.data <= /* logic */;
  }
}

class MyConsumer extends Module {
  MyConsumer(ReadyValidInterface<Logic> intf, Logic clk, Logic reset) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    
    // Connect as consumer (receives data)
    intf = ReadyValidInterface.clone(intf)
      ..pairConnectIO(this, intf,
        PairRole.consumer,  // This module consumes data
        inputTags: {Interface.Port.clk, Interface.Port.reset});
    
    // Drive ready signal
    intf.ready <= /* logic */;
    // Read from intf.data when intf.accepted is high
  }
}
```

**Key PairInterface Concepts**:
- `pairConnectIO(module, externalInterface, role)` filters port directions based on role
- `PairRole.provider`: Module drives `valid` and `data`, reads `ready`
- `PairRole.consumer`: Module drives `ready`, reads `valid` and `data`
- `accepted` signal: Convenient helper for `ready & valid` transaction completion

#### Ready/Valid Protocol Variants

Three protocol variants are available for different handshake requirements:

```dart
// 1. Basic ready/valid (either can come first)
final intf1 = ReadyValidInterface<Logic>(dataWidth: 32);

// 2. Ready AND valid (both must be asserted simultaneously)
final intf2 = ReadyAndValidInterface<Logic>(dataWidth: 32);

// 3. Ready THEN valid (ready must come first)
final intf3 = ReadyThenValidInterface<Logic>(dataWidth: 32);
```

#### Protocol Conversion with FIFO

Convert between protocol variants using FIFO buffering:

```dart
// Convert basic ready/valid to ready-and-valid protocol
final inputIntf = ReadyValidInterface<Logic>(dataWidth: 32);
final outputIntf = inputIntf.toDownstreamReadyAndValid(
  clk: clk,
  reset: reset,
  depth: 4,  // FIFO depth for buffering
);
// outputIntf is now a ReadyAndValidInterface
```

#### DataPortInterface Pattern

For simpler unidirectional interfaces, use `DataPortInterface.connectIO()`:

```dart
class MyMemory extends Module {
  MyMemory(DataPortInterface readPort, DataPortInterface writePort) {
    // Clone and connect ports
    readPort = DataPortInterface.clone(readPort)
      ..connectIO(this, readPort);
    writePort = DataPortInterface.clone(writePort)
      ..connectIO(this, writePort);
    
    // Access port signals
    final readAddr = readPort.addr;
    final writeData = writePort.data;
  }
}
```

#### Using LogicStructure with Interfaces

Interfaces can be generic over `LogicStructure` types for type-safe complex data:

```dart
// Custom data structure
class MyPacket extends LogicStructure {
  final Logic header = Logic(width: 8);
  final Logic payload = Logic(width: 64);
  final Logic checksum = Logic(width: 8);
  
  MyPacket() : super([/* fields */]);
}

// Type-safe interface
final intf = ReadyValidInterface<MyPacket>();
intf.data.header <= headerValue;  // Type-safe field access
```

### Configurator Pattern

Each major component has a `Configurator` subclass for web-based RTL generation:

```dart
class MyComponentConfigurator extends Configurator {
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
    'width': IntConfigKnob(value: 8),
    'enableFeature': ToggleConfigKnob(value: false),
  };
  
  @override
  Module createModule() => MyComponent(...);
}
```

Used by the Flutter web app (`confapp/`) to generate SystemVerilog via the browser.

## Development Workflows

### Running Tests

```bash
# All tests
dart test

# Specific test file
dart test test/rotate_test.dart

# Single test by name
dart test test/rotate_test.dart --name "rotate left"
```

**Test Structure Pattern**:
- Tests live in `test/` directory, named `*_test.dart`
- Use `group()` to share component setup across tests
- Always call `Simulator.reset()` in `tearDown()` for sequential tests
- Sequential logic requires: `SimpleClockGenerator`, `Simulator.run()`, `await Simulator.endSimulation()`

```dart
void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('my component', () {
    final input = Logic(width: 8);
    final component = MyComponent(input);
    
    test('basic behavior', () async {
      final clk = SimpleClockGenerator(10).clk;
      unawaited(Simulator.run());
      
      input.inject(0x42);
      await clk.waitCycles(3);
      expect(component.output.value.toInt(), equals(0x42));
      
      await Simulator.endSimulation();
    });
  });
}
```

### Building & SystemVerilog Generation

```dart
// In code or tests
final mod = MyModule(inputs...);
await mod.build();                    // Required before generateSynth()
final systemVerilog = mod.generateSynth();
```

### BFM Testing Pattern (Bus Functional Models)

For protocol-based components, use ROHD-VF agents for verification:

```dart
import 'package:rohd_vf/rohd_vf.dart';

class MyProtocolTest extends Test {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final ready = Logic();
  final valid = Logic();
  final data = Logic(width: 32);
  
  late final ReadyValidTransmitterAgent transmitter;
  late final ReadyValidReceiverAgent receiver;
  late final ReadyValidMonitor monitor;
  
  MyProtocolTest(super.name, {super.randomSeed = 1234}) {
    // Transmitter agent (drives valid and data)
    transmitter = ReadyValidTransmitterAgent(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      blockRate: 0.3,  // 30% chance to delay valid
      parent: this,
    );
    
    // Receiver agent (drives ready)
    receiver = ReadyValidReceiverAgent(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      blockRate: 0.2,  // 20% chance to drop ready
      parent: this,
    );
    
    // Monitor observes accepted transactions
    monitor = ReadyValidMonitor(
      clk: clk,
      ready: ready,
      valid: valid,
      data: data,
      name: 'monitor',
    );
  }
  
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    
    // Send transactions via transmitter
    for (var i = 0; i < 10; i++) {
      await transmitter.sequencer.add(
        ReadyValidPacket(data: i)
      );
    }
    
    // Wait for all transactions to complete
    await transmitter.sequencer.waitForAllSequencesComplete();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  
  test('protocol test', () async {
    final test = MyProtocolTest('my_test');
    await test.start();
  });
}
```

**BFM Key Concepts**:
- **Agents**: Drive and respond to protocol signals (`TransmitterAgent`, `ReceiverAgent`)
- **Monitors**: Observe transactions without driving signals
- **Trackers**: Log monitored transactions for analysis
- **Sequencers**: Queue and manage transaction flow
- **blockRate**: Simulate realistic protocol delays and backpressure
- Agents inherit from ROHD-VF's `Test` class for structured test phases

### Local Development Checks

```bash
# Run all checks (format, analyze, test, docs)
tool/run_checks.sh

# Individual steps
dart pub get                          # Install dependencies
dart format --set-exit-if-changed .   # Format check
dart analyze                          # Static analysis
dart test                             # Run tests
```

### Component Configurator Web App

```bash
cd confapp
flutter run --profile -d web-server --web-hostname=0.0.0.0 --web-port=3000
```

Access at `http://localhost:3000` to configure components and generate SystemVerilog.

## Component Implementation Guidelines

### Naming & Definitions

```dart
// Module instances are named, definitions can be shared
RotateLeft(
  original, 
  rotateAmount,
  name: 'my_rotate_inst',              // Instance name (unique)
  definitionName: 'RotateLeft_W16'     // Definition name (shared)
)
```

### Cache Components Architecture

ROHD-HCL includes a comprehensive cache subsystem with multiple implementations:

#### Cache Types Available

```dart
// 1. Direct-mapped cache (simplest, 1-way associative)
final cache1 = DirectMappedCache(clk, reset, fills, reads, lines: 16);

// 2. Multi-ported set-associative cache (configurable ways/lines)
final cache2 = MultiPortedReadCache(clk, reset, fills, reads, 
  ways: 4, lines: 16, replacement: PseudoLRUReplacement.new);
```

#### CachedRequestResponse Pattern

For protocol-level caching with ready/valid interfaces:

```dart
final cache = CachedRequestResponse(
  clk: clk, reset: reset,
  upstreamRequest: upstreamReq,     // Consumer role
  upstreamResponse: upstreamResp,   // Provider role  
  downstreamRequest: downstreamReq, // Provider role
  downstreamResponse: downstreamResp, // Consumer role
  idWidth: 4, addrWidth: 8, dataWidth: 32,
  // Configurable cache backend
  cacheBuilder: (clk, reset, fills, reads) => 
    DirectMappedCache(clk, reset, fills, reads, lines: 16),
);
```

**Key Cache Concepts**:
- **Fill ports**: Write data into cache with address and valid bit
- **Read ports**: Query cache by address, returns data + valid (hit/miss)
- **ValidDataPortInterface**: Extends DataPortInterface with valid signal
- **Replacement policies**: PseudoLRU, FIFO, etc. for way selection
- **CAM usage**: Fully associative caches use CAM for parallel tag lookup
- **Request tracking**: CachedRequestResponse uses CAM to track outstanding requests by ID

### Width Inference Pattern

Prefer inferring output widths from inputs rather than requiring width parameters:

```dart
// GOOD: Width inferred from input
Count(Logic input) {
  input = addInput('input', input, width: input.width);
  addOutput('count', width: log2Ceil(input.width + 1));
}

// AVOID: Requiring separate width parameter
Count(Logic input, int width)  // Redundant
```

### Logic Operations & Constructs

- **Basic ops**: `&`, `|`, `^`, `~`, `+`, `-`, `*`, `/`, `%`, `mux()`, `flop()`
- **Comparisons**: Use methods (`eq()`, `lt()`, `gt()`, `lte()`, `gte()`) NOT operators inside conditionals
  - `>` and `>=` operators work but need parentheses: `(a > b)`
- **Conditional logic**: Use `Combinational([...])` blocks (maps to `always_comb`)
  - Inside `Combinational`: use `<` operator for assignments
  - For write-after-read scenarios: use `Combinational.ssa((s) => [...])` 
- **Sequential logic**: Use `Sequential(clk, [...])` blocks (maps to `always_ff`)
  - Supports `reset`, `asyncReset`, and `resetValues` parameters
  - Inside `Sequential`: use `<` operator for assignments
- **State machines**: `FiniteStateMachine` class
- **Pipelining**: `Pipeline` class with stages

### Extension Methods Pattern

Components add extension methods to make usage ergonomic:

```dart
// In rotate.dart
extension LogicRotate on Logic {
  Logic rotateLeft(dynamic amount, {int? maxAmount}) =>
      RotateLeft(this, amount, maxAmount: maxAmount).rotated;
}

// Usage
final result = mySignal.rotateLeft(4);
```

## Documentation Requirements

### Component Documentation Checklist

1. **Markdown file**: `doc/components/my_component.md`
2. **Entry in**: `doc/README.md` component list
3. **API docs**: Dartdoc comments on classes/methods
4. **Code examples**: In both markdown docs and class docs
5. **Configurator**: For web app inclusion

### Component Markdown Template

````markdown
# Component Name

Brief description of hardware function.

## Module: `MyComponent`

Detailed explanation with usage example:

```dart
final input = Logic(width: 8);
final mod = MyComponent(input, param: 42);
final output = mod.result;
```

Parameters:
- `param`: Description and range

## Example

Working code snippet with expected behavior.
````

## Project-Specific Conventions

### Error Handling

Throw `RohdHclException` for configuration/usage errors:

```dart
if (width <= 0) {
  throw RohdHclException('Width must be positive.');
}
```

### Deprecation Pattern

```dart
@Deprecated('Use `newMethod` instead.')
OldType get oldGetter => _internal;
```

### Signal Naming

- Internal signals: Use `.named('descriptive_name')` for debug/waveform clarity
- Ports: Use lowercase with underscores: `'rotate_amount'`
- Outputs: Use descriptive getters: `Logic get rotated => output('rotated');`

## Common Pitfalls

1. **Using external Logic directly**: Always call `addInput()` first in module constructors
2. **Wrong assignment operator**: 
   - Use `<=` for direct signal connections
   - Use `<` inside `Combinational`/`Sequential` blocks
   - Never use `=` for signal assignments
3. **Missing build**: Call `await mod.build()` before `generateSynth()`
4. **Test cleanup**: Forgetting `Simulator.reset()` in `tearDown()` causes cross-test contamination
5. **Width mismatches**: Use `.zeroExtend()` or `.signExtend()` when combining signals
6. **Comparison operators**: Use `.eq()`, `.lt()`, `.gt()` methods inside conditionals, not `==`, `<`, `>`
7. **Interface connection errors**:
   - Forgetting to clone interfaces before connecting: `Interface.clone(intf)..connectIO(...)`
   - Wrong `PairRole` in `pairConnectIO()`: provider drives data/valid, consumer drives ready
   - Missing port tags when cloning clock/reset: Use `inputTags` or `outputTags` parameter
8. **Cache-specific pitfalls**:
   - Using wrong cache builder signature: `(clk, reset, fills, reads) => Cache`
   - Mismatching port counts: number of fill/read ports must match cache expectations
   - Forgetting to set `valid` bit on fill operations: cache won't store invalid data
   - Not handling cache miss flows: read valid=0 indicates miss, requires downstream fetch
   - CAM entry conflicts: in CachedRequestResponse, ensure ID space doesn't exceed cache depth

## Related Resources

- [ROHD Documentation](https://intel.github.io/rohd-website/)
- [Component List](../doc/README.md)
- [Module Best Practices](../doc/Module.md)
- [Generator Web App](https://intel.github.io/rohd-hcl/confapp/)
- [Discord Community](https://discord.gg/jubxF84yGw)
