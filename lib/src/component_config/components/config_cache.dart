// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_cache.dart
// Configurator for cache components (DirectMapped, SetAssociative,
// FullyAssociative).
//
// 2025 November 05
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Typedef for the replacement policy constructor function signature.
typedef ReplacementCtor = ReplacementPolicy Function(Logic, Logic,
    List<AccessInterface>, List<AccessInterface>, List<AccessInterface>,
    {int ways, String name});

/// Available cache types for the configurator.
enum CacheType {
  /// A direct-mapped cache.
  directMapped,

  /// A set-associative cache.
  setAssociative,

  /// A fully associative cache.
  fullyAssociative
}

/// Replacement policy choices for the configurator UI.
enum ReplacementPolicyType {
  /// Pseudo Least Recently Used replacement policy.
  pseudoLRU
}

/// A [Configurator] for cache modules.
class CacheConfigurator extends Configurator {
  /// Cache type.
  final ChoiceConfigKnob<CacheType> cacheType =
      ChoiceConfigKnob(CacheType.values, value: CacheType.setAssociative);

  /// Data width in bits.
  final IntConfigKnob dataWidth = IntConfigKnob(value: 32);

  /// Address width in bits.
  final IntConfigKnob addrWidth = IntConfigKnob(value: 16);

  /// Number of ways (associativity) for set-associative and fully associative
  /// caches.
  final IntConfigKnob ways = IntConfigKnob(value: 4);

  /// Number of lines (depth) in the cache.
  final IntConfigKnob lines = IntConfigKnob(value: 64);

  /// Number of read ports to instantiate for the cache configurator module.
  // Note: number of read ports is derived from the number of fill/invalidates
  // (see `numFillPorts`) so there is no separate `numReadPorts` knob.

  /// Number of fill ports to instantiate for the cache configurator module.
  final IntConfigKnob numFillPorts = IntConfigKnob(value: 1);

  /// Per-read-port knobs indicating whether the read port supports
  /// Per-read-port knobs. Each read port is represented by a small group of
  /// knobs; currently that group contains the 'Read with invalidate' toggle.
  /// The list length will be synchronized to [numFillPorts] when creating the
  /// module.
  final ListOfKnobsKnob readWithInvalidateKnobs = ListOfKnobsKnob(
    count: 1,
    generateKnob: (i) => GroupOfKnobs({
      'Read with invalidate': ToggleConfigKnob(value: false),
    }, name: 'Read Port'),
    name: 'Read Ports',
  );

  /// For now only one replacement policy is available; keep as choice for
  /// future extension.
  final ChoiceConfigKnob<ReplacementCtor> replacementPolicy =
      ChoiceConfigKnob<ReplacementCtor>([PseudoLRUReplacement.new],
          value: PseudoLRUReplacement.new);

  /// Replacement policy choices presented to the user as an enum-like choice.
  /// This mirrors the style of `cacheType` knob and is easier for UI.
  final ChoiceConfigKnob<ReplacementPolicyType> replacementPolicyType =
      ChoiceConfigKnob<ReplacementPolicyType>(ReplacementPolicyType.values,
          value: ReplacementPolicyType.pseudoLRU);

  /// Whether to generate occupancy instrumentation (only for fully
  /// associative cache generation).
  final ToggleConfigKnob generateOccupancy = ToggleConfigKnob(value: false);

  /// Group containing associativity-related knobs. This is used so the UI
  /// can show/hide associativity options as a single grouped control. It
  /// reuses the existing `ways` and `replacementPolicy` knobs so values are
  /// consistent with the rest of the configurator.
  late final GroupOfKnobs associativityGroup = GroupOfKnobs({
    'Ways (associativity)': ways,
    'Replacement Policy': replacementPolicyType,
  }, name: 'Associativity');

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => UnmodifiableMapView({
        'Cache Type': cacheType,
        'Data Width': dataWidth,
        'Address Width': addrWidth,
        if (cacheType.value != CacheType.directMapped)
          'Associativity': associativityGroup,
        'Lines (depth)': lines,
        if (cacheType.value == CacheType.fullyAssociative)
          'Generate Occupancy': generateOccupancy,
        'Number of fill ports': numFillPorts,
        'Read Ports': readWithInvalidateKnobs,
      });

  @override
  Module createModule() {
    // Use the knob that controls the number of invalidates/fill ports to
    // determine how many read ports to create. Each read port will have a
    // corresponding read-with-invalidate toggle.
    final rp = numFillPorts.value;
    readWithInvalidateKnobs.count = rp;

    // Number of fill ports (write/fill interfaces)
    final fp = numFillPorts.value;

    // Create lists of fill and read interfaces according to knobs.
    final fills = List.generate(
        fp,
        (i) => ValidDataPortInterface(dataWidth.value, addrWidth.value,
            name: 'fill_$i'));
    // Compose FillEvictInterface instances (no eviction ports by default in
    // configurator UI).
    final compositeFills =
        List.generate(fp, (i) => FillEvictInterface(fills[i]));

    final reads = List.generate(rp, (i) {
      final group = readWithInvalidateKnobs.knobs[i] as GroupOfKnobs;
      final hasRwi =
          (group.subKnobs['Read with invalidate']! as ToggleConfigKnob).value;
      return ValidDataPortInterface(dataWidth.value, addrWidth.value,
          hasReadWithInvalidate: hasRwi, name: 'read_$i');
    });

    // Map ReplacementPolicyType to actual constructor
    ReplacementCtor replCtor = PseudoLRUReplacement.new;
    switch (replacementPolicyType.value) {
      case ReplacementPolicyType.pseudoLRU:
        replCtor = PseudoLRUReplacement.new;
    }

    switch (cacheType.value) {
      case CacheType.directMapped:
        return DirectMappedCache(Logic(), Logic(), compositeFills, reads,
            lines: lines.value);
      case CacheType.setAssociative:
        return SetAssociativeCache(
          Logic(),
          Logic(),
          compositeFills,
          reads,
          ways: ways.value,
          lines: lines.value,
          replacement: replCtor,
        );
      case CacheType.fullyAssociative:
        return FullyAssociativeCache(Logic(), Logic(), compositeFills, reads,
            ways: ways.value,
            generateOccupancy: generateOccupancy.value,
            replacement: replCtor,
            definitionName: 'FullyAssociativeCache');
    }
  }

  @override
  final String name = 'Cache';
}
