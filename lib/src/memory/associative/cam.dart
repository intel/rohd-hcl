// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cam.dart
// CAM (Contents-Addressable Memory) modules.
//
// 2025 September 18
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// An interface to a Content-Addressable Memory (CAM) that allows querying
/// for tags and returns the index of the matching tag if found.
///
/// For lookups, `tag` is the query and `idx`/`hit` are the results.
/// Only entries with their valid bit set will match during lookups.
///
/// For writes, `en` enables the write, `idx` is the destination address,
/// `tag` is the data to write, and `hit` sets/clears the valid bit
/// (hit=1 marks the entry valid, hit=0 marks it invalid).
class TagInterface<T extends Logic> extends Interface<DataPortGroup> {
  /// The width of data in the memory.
  final int tagWidth;

  /// The width of addresses in the memory.
  final int idWidth;

  /// Enable signal for write operations.
  Logic get en => port('en');

  /// The "tag" to match (for lookup) or write (for write operations).
  T get tag => port('tag') as T;

  /// The entry number (index) where the tag was found (lookup) or
  /// the destination address (write).
  Logic get idx => port('idx');

  /// For lookups: indicates whether a valid match was found.
  /// For writes: sets/clears the valid bit (1=valid, 0=invalid).
  Logic get hit => port('hit');

  /// Constructs a new interface of specified [idWidth] and [tagWidth] for
  /// querying a CAM.
  TagInterface(this.idWidth, this.tagWidth) {
    if (T != Logic) {
      throw ArgumentError('Use TagInterface.typed for a specialized tag type.');
    }
    setPorts([
      Logic.port('en'),
      Logic.port('tag', tagWidth),
    ], [
      DataPortGroup.control
    ]);

    setPorts([
      Logic.port('idx', idWidth),
      Logic.port('hit'),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Constructs an interface preserving the schema of [tag].
  ///
  /// [tag] supplies a schema, not a driver. Drive the interface's
  /// [TagInterface.tag] for writes and queries. The argument order matches
  /// the width-based constructor.
  TagInterface.typed(this.idWidth, T tag) : tagWidth = tag.width {
    setPorts([Logic.port('en'), tag.cloneTyped(name: 'tag')],
        [DataPortGroup.control]);
    setPorts(
        [Logic.port('idx', idWidth), Logic.port('hit')], [DataPortGroup.data]);
  }

  /// Makes a copy of this [TagInterface] with matching configuration.
  @override
  TagInterface<T> clone() => TagInterface<T>.typed(idWidth, tag);

  bool _suppressTag = false;

  @override
  Map<String, Logic> getPorts([Iterable<DataPortGroup>? tags]) {
    final ports = super.getPorts(tags);
    return _suppressTag ? (Map<String, Logic>.of(ports)..remove('tag')) : ports;
  }

  @override
  void connectIO(Module module, Interface<dynamic> srcInterface,
      {Iterable<DataPortGroup>? inputTags,
      Iterable<DataPortGroup>? outputTags,
      Iterable<DataPortGroup>? inOutTags,
      String Function(String original)? uniquify}) {
    final source = srcInterface.port('tag');
    if (source.width != tagWidth ||
        (((source is LogicStructure && tag is LogicStructure) ||
                (source is LogicEnum && tag is LogicEnum)) &&
            !sameDeclaredPayloadShape(tag, source))) {
      throw PortTypeException.forIntendedName(
          'tag', 'CAM tag layout does not match ${payloadShapeIdentity(tag)}.');
    }
    final tagName = uniquify?.call('tag') ?? 'tag';
    if (inputTags?.contains(DataPortGroup.control) ?? false) {
      final bridge = tag.cloneTyped(name: 'tag_input_bridge')..gets(source);
      tag <= module.addTypedInput(tagName, bridge);
    }
    if (outputTags?.contains(DataPortGroup.control) ?? false) {
      final output = module.addTypedOutput(tagName, tag.cloneTyped);
      output <= tag;
      source <= output;
    }
    if (inOutTags?.contains(DataPortGroup.control) ?? false) {
      final bridge = tag.cloneTyped(name: 'tag_inout_bridge')..gets(source);
      tag <= module.addTypedInOut(tagName, bridge);
    }
    _suppressTag = true;
    try {
      super.connectIO(module, srcInterface,
          inputTags: inputTags,
          outputTags: outputTags,
          inOutTags: inOutTags,
          uniquify: uniquify);
    } finally {
      _suppressTag = false;
    }
  }
}

/// A content-addressable memory (CAM) preserving tag type [T].
///
/// Lookup compares exact tag bit patterns, not domain-specific numeric
/// equality. Packing is confined to the existing case-comparison boundary.
class Cam<T extends Logic> extends Module {
  /// The number of entries in the Cam.
  final int numEntries;

  /// The number of write ports.
  final int numWrites;

  /// The number of lookup (tag access) ports.
  final int numLookups;

  /// Whether to track the number of valid entries and emit full/empty signals.
  final bool enableValidTracking;

  /// Internal clock.
  @protected
  Logic get clk => input('clk');

  /// Internal reset.
  @protected
  Logic get reset => input('reset');

  /// Internal write ports using TagInterface.
  @protected
  final List<TagInterface<T>> wrPorts = [];

  /// The lookup (tag access) ports.
  @protected
  final List<TagInterface<T>> lookupPorts = [];

  /// Signal indicating the CAM is full (all entries valid).
  /// Only available when [enableValidTracking] is true.
  Logic? get full => enableValidTracking ? output('full') : null;

  /// Signal indicating the CAM is empty (no entries valid).
  /// Only available when [enableValidTracking] is true.
  Logic? get empty => enableValidTracking ? output('empty') : null;

  /// The count of valid entries.
  /// Only available when [enableValidTracking] is true.
  Logic? get validCount => enableValidTracking ? output('valid_count') : null;

  /// Constructs a new [Cam] with write ports and lookup ports using
  /// [TagInterface].
  ///
  /// For write ports, `en` enables the write, `idx` specifies the address,
  /// and `tag` provides the data to write. The `hit` signal sets or clears
  /// the entry's valid bit.
  ///
  /// For lookup ports, `tag` is the query, `idx` returns the matching index,
  /// and `hit` indicates whether a match was found.
  ///
  /// If [enableValidTracking] is true, the CAM will maintain a count of
  /// valid entries and provide [full], [empty], and [validCount] signals.
  ///
  /// Example with valid tracking enabled:
  /// ```dart
  /// final cam = Cam(
  ///   clk, reset,
  ///   [writePort], [lookupPort],
  ///   numEntries: 16,
  ///   enableValidTracking: true,
  /// );
  /// // Use cam.full, cam.empty, and cam.validCount signals
  /// ```
  Cam(Logic clk, Logic reset, List<TagInterface<T>> writePorts,
      List<TagInterface<T>> lookupPorts,
      {this.numEntries = 8,
      this.enableValidTracking = false,
      super.name = 'cam',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : numWrites = writePorts.length,
        numLookups = lookupPorts.length,
        super(
            definitionName: definitionName ??
                'CAM_WP${writePorts.length}'
                    '_LP${lookupPorts.length}_E$numEntries') {
    if (writePorts.isEmpty && lookupPorts.isEmpty) {
      throw ArgumentError('Must provide at least one write or lookup port.');
    }
    if (lookupPorts.isEmpty) {
      throw ArgumentError('Must provide at least one lookup port.');
    }
    if (numEntries < 1) {
      throw ArgumentError.value(numEntries, 'numEntries', 'Must be positive.');
    }
    final schema = lookupPorts.first.tag;
    for (final port in [...writePorts, ...lookupPorts]) {
      if (!sameDeclaredPayloadShape(schema, port.tag)) {
        throw RohdHclException('CAM ports must have matching tag layouts.');
      }
      if (port.idWidth < log2Ceil(numEntries)) {
        throw RohdHclException('CAM index width ${port.idWidth} cannot address '
            '$numEntries entries.');
      }
    }

    addInput('clk', clk);
    addInput('reset', reset);

    // Connect write ports - all signals are inputs for writes
    for (var i = 0; i < numWrites; i++) {
      wrPorts.add(addInterfacePorts(writePorts[i],
          inputTags: {DataPortGroup.control, DataPortGroup.data},
          uniquify: (original) => 'wr_${original}_$i'));
    }

    // Connect lookup ports - control signals are inputs, data signals are
    // outputs
    for (var i = 0; i < numLookups; i++) {
      this.lookupPorts.add(addInterfacePorts(lookupPorts[i],
          inputTags: {DataPortGroup.control},
          outputTags: {DataPortGroup.data},
          uniquify: (original) => 'lookup_${original}_$i'));
    }
    _buildLogic();
  }

  /// Flop-based storage of all memory.
  late final TypedLogicArray<T, LogicValue> _storageBank;

  /// Valid bits for each entry.
  late final List<Logic> _validBits;

  void _buildLogic() {
    final tagWidth = lookupPorts.first.tagWidth;

    // create local storage bank
    _storageBank = TypedLogicArray<T, LogicValue>(
        [numEntries], lookupPorts.first.tag.cloneTyped,
        name: 'tags');

    // Create valid bits for each entry
    _validBits =
        List<Logic>.generate(numEntries, (i) => Logic(name: 'valid_$i'));

    // Create valid tracking outputs if enabled
    if (enableValidTracking) {
      final countWidth = log2Ceil(numEntries + 1);
      addOutput('valid_count', width: countWidth);
      addOutput('full');
      addOutput('empty');
    }

    // A Cam lookup returns the index, but only matches valid entries.
    for (final lookupPort in lookupPorts) {
      // This boundary intentionally compares bit identity, including enum and
      // floating-point encodings, rather than invoking numeric equality.
      final validTag = [Const(1), lookupPort.tag].swizzle();

      Combinational([
        Case(validTag, [
          for (var i = 0; i < numEntries; i++)
            CaseItem(
              [
                _validBits[i],
                _storageBank.at([i])
              ].swizzle(),
              [
                lookupPort.idx < Const(i, width: lookupPort.idWidth),
                lookupPort.hit < Const(1),
              ],
            )
        ], defaultItem: [
          lookupPort.idx < Const(0, width: lookupPort.idWidth),
          lookupPort.hit < Const(0)
        ]),
      ]);
    }

    if (enableValidTracking) {
      // Count valid entries
      final countSum = _validBits
          .map((v) => v.zeroExtend(validCount!.width))
          .reduce((a, b) => a + b);
      validCount! <= countSum;
      full! <= validCount!.eq(numEntries);
      empty! <= validCount!.eq(0);
    }

    Sequential(clk, [
      If(reset, then: [
        ..._storageBank.arrayElements.map((e) => e < Const(0, width: tagWidth)),
        ..._validBits.map((v) => v < Const(0)),
      ], orElse: [
        for (var entry = 0; entry < numEntries; entry++)
          ...wrPorts.map((wrPort) =>
              // set storage bank if write enable and pointer matches
              // use wrPort.hit to set/clear the valid bit
              If(wrPort.en & wrPort.idx.eq(entry), then: [
                _storageBank.at([entry]) < wrPort.tag,
                _validBits[entry] < wrPort.hit,
              ])),
      ]),
    ]);
  }

  /// Read latency is 0 (combinational lookup).
  int get readLatency => 0;
}
