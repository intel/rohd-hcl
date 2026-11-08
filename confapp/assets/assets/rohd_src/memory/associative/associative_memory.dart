// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_memory.dart
// Common role-specific interfaces for associative memories.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';

/// Common shape shared by associative update and lookup ports.
/// {@category Memory}
abstract class AssociativePortInterface extends Interface<DataPortGroup> {
  /// Width of each associative key.
  final int keyWidth;

  /// Width of an entry index.
  final int indexWidth;

  /// The key payload carried by this port.
  Logic get key;

  DataPortGroup get _keyGroup;
  bool _suppressKey = false;

  /// Creates a shaped associative-memory port.
  AssociativePortInterface({required this.keyWidth, required this.indexWidth}) {
    if (keyWidth < 1 || indexWidth < 1) {
      throw ArgumentError('Key and index widths must be positive.');
    }
  }

  @override
  Map<String, Logic> getPorts([Iterable<DataPortGroup>? tags]) {
    final ports = super.getPorts(tags);
    return _suppressKey ? (Map<String, Logic>.of(ports)..remove('key')) : ports;
  }

  @override
  void connectIO(Module module, Interface<dynamic> srcInterface,
      {Iterable<DataPortGroup>? inputTags,
      Iterable<DataPortGroup>? outputTags,
      Iterable<DataPortGroup>? inOutTags,
      String Function(String original)? uniquify}) {
    final source = srcInterface.port('key');
    if (source.width != keyWidth || !_compatibleKeys(key, source)) {
      throw PortTypeException.forIntendedName(
          'key',
          'Associative key layout does not match '
              '${payloadShapeIdentity(key)}.');
    }
    final keyName = uniquify?.call('key') ?? 'key';
    if (inputTags?.contains(_keyGroup) ?? false) {
      final bridge = key.cloneTyped(name: 'key_input_bridge')..gets(source);
      key <= module.addTypedInput(keyName, bridge);
    }
    if (outputTags?.contains(_keyGroup) ?? false) {
      final output = module.addTypedOutput(keyName, key.cloneTyped);
      output <= key;
      source <= output;
    }
    if (inOutTags?.contains(_keyGroup) ?? false) {
      final bridge = key.cloneTyped(name: 'key_inout_bridge')..gets(source);
      key <= module.addTypedInOut(keyName, bridge);
    }
    _suppressKey = true;
    try {
      super.connectIO(module, srcInterface,
          inputTags: inputTags,
          outputTags: outputTags,
          inOutTags: inOutTags,
          uniquify: uniquify);
    } finally {
      _suppressKey = false;
    }
  }
}

bool _compatibleKeys(Logic left, Logic right) =>
    !((left is LogicStructure && right is LogicStructure) ||
        (left is LogicEnum && right is LogicEnum)) ||
    sameDeclaredPayloadShape(left, right);

/// A port that updates one indexed associative-memory entry.
///
/// When [en] is high, [key] and [entryValid] update the entry selected by
/// [index]. Driving [entryValid] low invalidates that entry.
/// {@category Memory}
class AssociativeUpdatePortInterface extends AssociativePortInterface {
  @override
  DataPortGroup get _keyGroup => DataPortGroup.data;

  /// Enables the update request.
  Logic get en => port('en');

  /// Selects the entry to update.
  Logic get index => port('index');

  /// Key written into the selected entry.
  @override
  Logic get key => port('key');

  /// Valid state written into the selected entry.
  Logic get entryValid => port('entryValid');

  /// Creates an associative-memory update port.
  AssociativeUpdatePortInterface(
      {required super.keyWidth, required super.indexWidth}) {
    _setPorts(Logic.port('key', keyWidth));
  }

  AssociativeUpdatePortInterface._typed(Logic key, {required super.indexWidth})
      : super(keyWidth: key.width) {
    _setPorts(key.cloneTyped(name: 'key'));
  }

  void _setPorts(Logic key) {
    setPorts([
      Logic.port('en'),
      Logic.port('index', indexWidth),
    ], [
      DataPortGroup.control
    ]);
    setPorts([
      key,
      Logic.port('entryValid'),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this interface with matching configuration.
  @override
  AssociativeUpdatePortInterface clone() => AssociativeUpdatePortInterface(
      keyWidth: keyWidth, indexWidth: indexWidth);
}

/// An associative update port preserving a typed key schema.
class TypedAssociativeUpdatePortInterface<T extends Logic>
    extends AssociativeUpdatePortInterface {
  /// Creates an update port whose key has the shape and type of [key].
  TypedAssociativeUpdatePortInterface(T super.key, {required super.indexWidth})
      : super._typed();

  @override
  T get key => super.key as T;

  @override
  TypedAssociativeUpdatePortInterface<T> clone() =>
      TypedAssociativeUpdatePortInterface<T>(key, indexWidth: indexWidth);
}

/// A combinational associative-memory lookup port.
///
/// [en] and [key] form the lookup request. [hit] and [index] return the lookup
/// result. Implementations must drive [index] to zero when [hit] is low.
/// {@category Memory}
class AssociativeLookupPortInterface extends AssociativePortInterface {
  @override
  DataPortGroup get _keyGroup => DataPortGroup.control;

  /// Number of match bits carried by [matchVector], when requested.
  final int? matchEntryCount;

  /// Enables the lookup request.
  Logic get en => port('en');

  /// Key to search for.
  @override
  Logic get key => port('key');

  /// Index selected from the matching entries.
  Logic get index => port('index');

  /// Indicates that a valid matching entry was found.
  Logic get hit => port('hit');

  /// Complete match vector, or `null` when only one index is returned.
  Logic? get matchVector =>
      matchEntryCount == null ? null : port('matchVector');

  /// Creates an associative-memory lookup port.
  AssociativeLookupPortInterface(
      {required super.keyWidth,
      required super.indexWidth,
      this.matchEntryCount}) {
    _setPorts(Logic.port('key', keyWidth));
  }

  AssociativeLookupPortInterface._typed(Logic key,
      {required super.indexWidth, this.matchEntryCount})
      : super(keyWidth: key.width) {
    _setPorts(key.cloneTyped(name: 'key'));
  }

  void _setPorts(Logic key) {
    if (matchEntryCount != null && matchEntryCount! < 1) {
      throw ArgumentError.value(
          matchEntryCount, 'matchEntryCount', 'Must be positive when present.');
    }
    setPorts([
      Logic.port('en'),
      key,
    ], [
      DataPortGroup.control
    ]);
    setPorts([
      Logic.port('index', indexWidth),
      Logic.port('hit'),
      if (matchEntryCount != null) Logic.port('matchVector', matchEntryCount!),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this interface with matching configuration.
  @override
  AssociativeLookupPortInterface clone() => AssociativeLookupPortInterface(
      keyWidth: keyWidth,
      indexWidth: indexWidth,
      matchEntryCount: matchEntryCount);
}

/// An associative lookup port preserving a typed key schema.
class TypedAssociativeLookupPortInterface<T extends Logic>
    extends AssociativeLookupPortInterface {
  /// Creates a lookup port whose key has the shape and type of [key].
  TypedAssociativeLookupPortInterface(T super.key,
      {required super.indexWidth, super.matchEntryCount})
      : super._typed();

  @override
  T get key => super.key as T;

  @override
  TypedAssociativeLookupPortInterface<T> clone() =>
      TypedAssociativeLookupPortInterface<T>(key,
          indexWidth: indexWidth, matchEntryCount: matchEntryCount);
}

/// A fixed-latency associative-memory lookup port.
///
/// [valid] identifies the cycle in which [hit] and [index] respond to an
/// enabled lookup request.
/// {@category Memory}
class SynchronousAssociativeLookupPortInterface
    extends AssociativeLookupPortInterface {
  /// Indicates that [hit] and [index] carry a lookup response.
  Logic get valid => port('valid');

  /// Creates a synchronous associative-memory lookup port.
  SynchronousAssociativeLookupPortInterface(
      {required super.keyWidth,
      required super.indexWidth,
      super.matchEntryCount}) {
    setPorts([
      Logic.port('valid'),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this interface with matching configuration.
  @override
  SynchronousAssociativeLookupPortInterface clone() =>
      SynchronousAssociativeLookupPortInterface(
          keyWidth: keyWidth,
          indexWidth: indexWidth,
          matchEntryCount: matchEntryCount);
}

/// A raw associative memory with fixed lookup timing and initiation interval.
///
/// Every enabled lookup port accepts a request every cycle. Implementations
/// unable to sustain that rate belong behind a scheduled ready/valid API.
/// {@category Memory}
abstract class AssociativeMemory extends Module {
  /// Number of searchable entries.
  final int entryCount;

  /// Width of each associative key.
  final int keyWidth;

  /// Width of an entry index.
  final int indexWidth;

  /// Number of independent update ports.
  int get numUpdates => localUpdates.length;

  /// Number of independent lookup ports.
  int get numLookups => localLookups.length;

  /// Enabled lookup to result latency.
  int get lookupLatency => contract.lookupLatency;

  /// Update sampling-edge to commit latency.
  int get updateLatency => contract.updateLatency;

  /// Resolved timing and semantic contract.
  final AssociativeMemoryContract contract;

  /// Internal update ports connected to the caller-owned update ports.
  @protected
  final List<AssociativeUpdatePortInterface> localUpdates = [];

  /// Internal lookup ports connected to the caller-owned lookup ports.
  @protected
  final List<AssociativeLookupPortInterface> localLookups = [];

  /// Internal clock.
  @protected
  Logic get clk => input('clk');

  /// Internal reset.
  @protected
  Logic get reset => input('reset');

  /// Creates the common associative-memory port boundary.
  AssociativeMemory({
    required Logic clk,
    required Logic reset,
    required List<AssociativeUpdatePortInterface> updates,
    required List<AssociativeLookupPortInterface> lookups,
    required this.entryCount,
    required this.contract,
    super.name = 'associative_memory',
    super.reserveName,
    super.reserveDefinitionName,
    super.definitionName,
  })  : keyWidth = _keyWidth(updates, lookups),
        indexWidth = _indexWidth(updates, lookups) {
    if (lookups.isEmpty) {
      throw ArgumentError('At least one associative lookup port is required.');
    }
    if (entryCount < 1 ||
        (BigInt.one << indexWidth) < BigInt.from(entryCount)) {
      throw ArgumentError('Entry count must be positive and representable.');
    }
    for (final port in <AssociativePortInterface>[...updates, ...lookups]) {
      if (port.keyWidth != keyWidth || port.indexWidth != indexWidth) {
        throw ArgumentError('All associative ports must have matching shapes.');
      }
    }
    final ports = <AssociativePortInterface>[...updates, ...lookups];
    for (var i = 0; i < ports.length; i++) {
      for (var j = i + 1; j < ports.length; j++) {
        if (!_compatibleKeys(ports[i].key, ports[j].key)) {
          throw ArgumentError('All associative keys must have compatible '
              'declared layouts.');
        }
      }
    }
    if (contract.resultShape ==
            AssociativeResultShape.matchVectorAndSelectedIndex &&
        lookups.any((lookup) => lookup.matchEntryCount != entryCount)) {
      throw ArgumentError('Every lookup port must carry one match bit per '
          'entry when the contract requests match vectors.');
    }

    addInput('clk', clk);
    addInput('reset', reset);
    for (var index = 0; index < updates.length; index++) {
      localUpdates.add(addInterfacePorts(
        updates[index],
        inputTags: {DataPortGroup.control, DataPortGroup.data},
        outputTags: <DataPortGroup>{},
        uniquify: (original) => 'update_${original}_$index',
      ));
    }
    for (var index = 0; index < lookups.length; index++) {
      localLookups.add(addInterfacePorts(
        lookups[index],
        inputTags: {DataPortGroup.control},
        outputTags: {DataPortGroup.data},
        uniquify: (original) => 'lookup_${original}_$index',
      ));
    }
  }

  static int _keyWidth(List<AssociativeUpdatePortInterface> updates,
      List<AssociativeLookupPortInterface> lookups) {
    final ports = <AssociativePortInterface>[...updates, ...lookups];
    if (ports.isEmpty) {
      throw ArgumentError('At least one associative port is required.');
    }
    return ports.first.keyWidth;
  }

  static int _indexWidth(List<AssociativeUpdatePortInterface> updates,
          List<AssociativeLookupPortInterface> lookups) =>
      <AssociativePortInterface>[...updates, ...lookups].first.indexWidth;
}

/// A raw associative memory with positive fixed lookup latency.
/// {@category Memory}
abstract class SynchronousAssociativeMemory extends AssociativeMemory {
  /// Creates a synchronous associative-memory port boundary.
  SynchronousAssociativeMemory({
    required super.clk,
    required super.reset,
    required super.updates,
    required List<SynchronousAssociativeLookupPortInterface> lookups,
    required super.entryCount,
    required super.contract,
    super.name = 'synchronous_associative_memory',
    super.reserveName,
    super.reserveDefinitionName,
    super.definitionName,
  }) : super(lookups: lookups) {
    if (lookupLatency < 1) {
      throw ArgumentError(
          'Synchronous associative lookup latency must be positive.');
    }
  }
}
