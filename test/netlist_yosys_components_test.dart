// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// netlist_yosys_components_test.dart
// Optional direct-netlist versus SystemVerilog component checks.
//
// 2026 November 20
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/bit_operations/selection/priority_mux.dart' as typed;
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Pair extends LogicStructure {
  _Pair({super.name})
      : super([Logic(name: 'lo', width: 2), Logic(name: 'hi', width: 2)]);

  @override
  _Pair clone({String? name}) => _Pair(name: name);
}

const _pairTechmap = r'''
(* techmap_celltype = "$struct_unpack" *)
module unpack_pair #(
  parameter STRUCT_NAME="", FIELD_COUNT=2,
  parameter FIELD_0_NAME="", FIELD_0_OFFSET=0, FIELD_0_WIDTH=2,
  parameter FIELD_1_NAME="", FIELD_1_OFFSET=2, FIELD_1_WIDTH=2
)(input [3:0] A, output [1:0] lo, output [1:0] hi);
  assign lo = A[FIELD_0_OFFSET +: FIELD_0_WIDTH];
  assign hi = A[FIELD_1_OFFSET +: FIELD_1_WIDTH];
endmodule
(* techmap_celltype = "$struct_pack" *)
module pack_pair #(
  parameter STRUCT_NAME="", FIELD_COUNT=2,
  parameter FIELD_0_NAME="", FIELD_0_OFFSET=0, FIELD_0_WIDTH=2,
  parameter FIELD_1_NAME="", FIELD_1_OFFSET=2, FIELD_1_WIDTH=2
)(input [1:0] lo, input [1:0] hi, output [3:0] Y);
  assign Y[FIELD_0_OFFSET +: FIELD_0_WIDTH] = lo;
  assign Y[FIELD_1_OFFSET +: FIELD_1_WIDTH] = hi;
endmodule
''';

const _replicationTechmap = '''
(* techmap_celltype = "ReplicationOp" *)
module replicate (
  input _subset_0_0_selector, _subset_1_1_selector, _subset_2_2_selector,
  output [3:0] _replicated__subset_0_0_selector,
  output [3:0] _replicated__subset_1_1_selector,
  output [3:0] _replicated__subset_2_2_selector
);
  assign _replicated__subset_0_0_selector = {4{_subset_0_0_selector}};
  assign _replicated__subset_1_1_selector = {4{_subset_1_1_selector}};
  assign _replicated__subset_2_2_selector = {4{_subset_2_2_selector}};
endmodule
''';

NetlistSynthesizerConfiguration? _optionalConfiguration() {
  try {
    // Keep this optional test compilable against the supported older ROHD.
    return Function.apply(
      NetlistSynthesizerConfiguration.new,
      const [],
      {#omitRohdMetadata: true},
    ) as NetlistSynthesizerConfiguration;
    // The supported older ROHD constructor does not have this named argument.
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {
    return null;
  }
}

bool _yosysAvailable(String executable) {
  try {
    return Process.runSync(executable, ['-V']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void _checkTechmapShapes(Map<String, dynamic> document, String? techmap) {
  final modules = document['modules'] as Map<String, dynamic>;
  final special = <Map<String, dynamic>>[];
  for (final definition in modules.values.cast<Map<String, dynamic>>()) {
    final cells = definition['cells'] as Map<String, dynamic>;
    special.addAll(cells.values.cast<Map<String, dynamic>>().where((cell) => [
          r'$struct_unpack',
          r'$struct_pack',
          'ReplicationOp'
        ].contains(cell['type'])));
  }
  if (techmap == _pairTechmap) {
    expect(special, hasLength(10));
    for (final cell in special) {
      final unpack = cell['type'] == r'$struct_unpack';
      expect(cell['type'], anyOf(r'$struct_unpack', r'$struct_pack'));
      final parameters = cell['parameters'] as Map<String, dynamic>;
      expect(parameters['FIELD_COUNT'], 2);
      expect(parameters['FIELD_0_NAME'], 'lo');
      expect(parameters['FIELD_0_OFFSET'], 0);
      expect(parameters['FIELD_0_WIDTH'], 2);
      expect(parameters['FIELD_1_NAME'], 'hi');
      expect(parameters['FIELD_1_OFFSET'], 2);
      expect(parameters['FIELD_1_WIDTH'], 2);
      final connections = cell['connections'] as Map<String, dynamic>;
      final directions = cell['port_directions'] as Map<String, dynamic>;
      final bus = unpack ? 'A' : 'Y';
      expect(connections.keys.toSet(), {bus, 'lo', 'hi'});
      expect(directions[bus], unpack ? 'input' : 'output');
      expect((connections[bus] as List).length, 4);
      for (final field in ['lo', 'hi']) {
        expect(directions[field], unpack ? 'output' : 'input');
        expect((connections[field] as List).length, 2);
      }
    }
  } else if (techmap == _replicationTechmap) {
    expect(special, hasLength(3));
    final inputs = <String>{};
    for (final cell in special) {
      expect(cell['type'], 'ReplicationOp');
      final directions = cell['port_directions'] as Map<String, dynamic>;
      final connections = cell['connections'] as Map<String, dynamic>;
      final input = directions.entries.singleWhere((e) => e.value == 'input');
      final output = directions.entries.singleWhere((e) => e.value == 'output');
      expect(directions.length, 2);
      expect(connections.keys.toSet(), {input.key, output.key});
      expect(output.key, '_replicated_${input.key}');
      expect((connections[input.key] as List).length, 1);
      expect((connections[output.key] as List).length, 4);
      inputs.add(input.key);
    }
    expect(inputs, {
      '_subset_0_0_selector',
      '_subset_1_1_selector',
      '_subset_2_2_selector',
    });
  } else {
    expect(special, isEmpty);
  }
}

Future<void> main() async {
  final configuration = _optionalConfiguration();
  final uri =
      await Isolate.resolvePackageUri(Uri.parse('package:rohd/rohd.dart'));
  final tool = uri == null
      ? null
      : File(
          '${File.fromUri(uri).parent.parent.path}/tool/yosys_netlist_miter.dart');
  final configuredYosys = Platform.environment['ROHD_YOSYS'];
  final yosys = configuredYosys ?? 'yosys';
  final available = _yosysAvailable(yosys);
  final skip = configuration == null
      ? 'Requires ROHD with omitRohdMetadata support'
      : tool == null || !tool.existsSync()
          ? 'Requires the ROHD checkout with its Yosys miter tool'
          : !available && configuredYosys == null
              ? 'Yosys executable not available'
              : null;

  final cases = <(String, Module Function(), String?)>[
    ('full adder', () => FullAdder(Logic(), Logic(), carryIn: Logic()), null),
    (
      'bitwise mux',
      () => BitwiseMux(List.generate(3, (_) => Logic(width: 4)),
          List.generate(3, (_) => Logic(width: 4))),
      null
    ),
    (
      'priority mux',
      () => typed.PriorityMux<Logic>(Logic(width: 3),
          List.generate(3, (_) => Logic(width: 4)), Logic(width: 4)),
      null
    ),
    (
      'structured priority mux',
      () => typed.PriorityMux<_Pair>(
          Logic(width: 2), List.generate(2, (_) => _Pair()), _Pair()),
      _pairTechmap
    ),
    (
      'one-hot mux',
      () =>
          OneHotMux(Logic(width: 3), List.generate(3, (_) => Logic(width: 4))),
      _replicationTechmap
    ),
  ];

  for (final (name, create, techmap) in cases) {
    test('$name JSON and SystemVerilog have equivalent outputs', () async {
      final module = create();
      await module.build();
      final json = NetlistSynthesizer(configuration: configuration!)
          .synthesizeToJson(module);
      _checkTechmapShapes(jsonDecode(json) as Map<String, dynamic>, techmap);
      final directory = await Directory.systemTemp.createTemp('hcl_yosys_');
      addTearDown(() async {
        await directory.delete(recursive: true);
        await Simulator.reset();
      });
      final netlist = File('${directory.path}/design.json');
      final sv = File('${directory.path}/design.sv');
      await netlist.writeAsString(json);
      await sv
          .writeAsString(SystemVerilogService(module, register: false).output);
      final map = File('${directory.path}/techmap.v');
      if (techmap != null) {
        await map.writeAsString(techmap);
      }
      final result = await Process.run(Platform.resolvedExecutable, [
        tool!.path,
        netlist.path,
        sv.path,
        module.definitionName,
        if (techmap != null) map.path,
      ], environment: {
        'ROHD_YOSYS': yosys
      });
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout,
          contains('SAT proof finished - no model found: SUCCESS'));
    }, skip: skip);
  }
}
