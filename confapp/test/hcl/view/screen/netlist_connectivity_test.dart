// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// netlist_connectivity_test.dart
// Connectivity regressions for HCL components in ROHD netlists.
//
// 2026 November 19
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  for (final configName in [
    'Register File',
    'Cache (Experimental)',
    'Extrema',
    'PRBS Checker',
  ]) {
    test('$configName preserves netlist connectivity', () async {
      final config = componentRegistry.singleWhere((c) => c.name == configName);
      final module = config.createModule();
      await module.build();

      for (final dce in [false, true]) {
        for (final collapse in [false, true]) {
          final netlist = jsonDecode(NetlistSynthesizer(
            configuration: NetlistSynthesizerConfiguration(
              enableDeadCellElimination: dce,
              collapseTransparentClusters: collapse,
            ),
          ).synthesizeToJson(module)) as Map<String, dynamic>;
          final definitions = netlist['modules'] as Map<String, dynamic>;
          final selected = definitions.entries.where((entry) =>
              configName == 'Cache (Experimental)'
                  ? entry.key.startsWith('RegisterFile_') ||
                      entry.key.startsWith('ParallelAssociativeMemory_')
                  : entry.key == module.definitionName);
          expect(selected, isNotEmpty);
          if (configName == 'Cache (Experimental)') {
            expect(
                selected.where((entry) =>
                    entry.key.startsWith('ParallelAssociativeMemory_')),
                hasLength(2));
            expect(
                selected
                    .where((entry) => entry.key.startsWith('RegisterFile_')),
                isNotEmpty);
          }
          for (final entry in selected) {
            final definition = entry.value as Map<String, dynamic>;
            final ports = definition['ports'] as Map<String, dynamic>;
            final cells = definition['cells'] as Map<String, dynamic>;
            final drivers = <int, List<String>>{};
            void addDriver(Object? bits, String name) {
              for (final bit in (bits! as List).whereType<int>()) {
                (drivers[bit] ??= []).add(name);
              }
            }

            for (final portEntry in ports.entries) {
              final port = portEntry.value as Map<String, dynamic>;
              if (port['direction'] == 'input' ||
                  port['direction'] == 'inout') {
                addDriver(port['bits'], 'port ${portEntry.key}');
              }
            }
            for (final cellEntry in cells.entries) {
              final cell = cellEntry.value as Map<String, dynamic>;
              final directions =
                  cell['port_directions'] as Map<String, dynamic>;
              for (final connection
                  in (cell['connections'] as Map<String, dynamic>).entries) {
                if (directions[connection.key] == 'output' ||
                    directions[connection.key] == 'inout') {
                  addDriver(
                      connection.value, '${cellEntry.key}.${connection.key}');
                }
              }
            }

            final context = '${entry.key} (DCE=$dce, collapse=$collapse)';
            for (final cellEntry in cells.entries) {
              final cell = cellEntry.value as Map<String, dynamic>;
              final directions =
                  cell['port_directions'] as Map<String, dynamic>;
              for (final connection
                  in (cell['connections'] as Map<String, dynamic>).entries) {
                if (directions[connection.key] == 'input') {
                  for (final bit
                      in (connection.value as List).whereType<int>()) {
                    expect(drivers[bit], isNotEmpty,
                        reason: '$context: ${cellEntry.key}.${connection.key} '
                            'bit $bit is undriven');
                  }
                }
              }
            }
            for (final portEntry in ports.entries) {
              final port = portEntry.value as Map<String, dynamic>;
              if (port['direction'] == 'output') {
                for (final bit in (port['bits'] as List).whereType<int>()) {
                  expect(drivers[bit], isNotEmpty,
                      reason: '$context: output ${portEntry.key} '
                          'bit $bit is undriven');
                }
              }
            }
            expect(
              drivers.entries.where((entry) => entry.value.length > 1),
              isEmpty,
              reason: '$context has multiple drivers',
            );
            if (entry.key.startsWith('RegisterFile') ||
                entry.key.startsWith('ParallelAssociativeMemory_')) {
              final sequential = cells.values
                  .cast<Map<String, dynamic>>()
                  .singleWhere((cell) => cell['type'] == 'Sequential');
              final seqDirections =
                  sequential['port_directions'] as Map<String, dynamic>;
              final seqConnections =
                  sequential['connections'] as Map<String, dynamic>;
              final stateBits = <int>{
                for (final port in seqConnections.entries)
                  if (seqDirections[port.key] == 'output')
                    ...(port.value as List).whereType<int>(),
              };
              final reads = cells.values
                  .cast<Map<String, dynamic>>()
                  .where((cell) => cell['type'] == 'Combinational')
                  .expand((cell) =>
                      (cell['connections'] as Map<String, dynamic>).entries)
                  .where((port) =>
                      port.key.startsWith('storageBank[') ||
                      port.key.contains('_entryValid_'))
                  .toList();
              expect(reads, isNotEmpty, reason: context);
              for (final read in reads) {
                expect(stateBits, containsAll((read.value as List).cast<int>()),
                    reason: '$context: ${read.key} must read stored state');
              }
            }
          }
        }
      }
    },
        // These fixes are not yet in the released ROHD dependency.
        // ignore: do_not_use_environment
        skip: !const bool.fromEnvironment('ROHD_LOCAL_NETLIST_TEST')
            ? 'ROHD release with corrected netlist connectivity is required'
            : false);
  }
}
