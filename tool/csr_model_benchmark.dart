// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_model_benchmark.dart
// Benchmark for CSR model configuration and simulation.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:yaml/yaml.dart';

/// Measures CSR configuration, construction, build, and simulation separately.
///
/// Run each implementation in a fresh process for comparable peak RSS:
/// `dart run tool/csr_model_benchmark.dart --count=6325 --software`
/// `dart run tool/csr_model_benchmark.dart --yaml=/path/map.yaml --software`
///
/// YAML support is a benchmark adapter for the supplied module/blocks/registers
/// schema, not a replacement for the downstream configuration loader.
Future<void> main(List<String> arguments) async {
  final software = arguments.contains('--software');
  final count = int.parse(arguments
      .firstWhere((arg) => arg.startsWith('--count='),
          orElse: () => '--count=1000')
      .substring('--count='.length));
  final yaml = arguments.where((arg) => arg.startsWith('--yaml=')).firstOrNull;
  final clock = Stopwatch()..start();
  final config = yaml == null
      ? _synthetic(count)
      : _fromYaml(yaml.substring('--yaml='.length));
  final configurationMicros = clock.elapsedMicroseconds;
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic()..put(0);
  final read = DataPortInterface(config.maxRegWidth(), config.minAddrBits())
    ..en.put(1)
    ..addr.put(config.blocks.first.baseAddr);
  final write = DataPortInterface(config.maxRegWidth(), config.minAddrBits())
    ..en.put(0)
    ..addr.put(0)
    ..data.put(0);
  clock.reset();
  final top = CsrTop(
    config: config,
    clk: clk,
    reset: reset,
    frontRead: read,
    frontWrite: write,
    implementationConfiguration: software
        ? CsrImplementationConfiguration.software
        : const CsrImplementationConfiguration(),
  );
  final constructionMicros = clock.elapsedMicroseconds;
  clock.reset();
  await top.build();
  final buildMicros = clock.elapsedMicroseconds;
  var modules = 0;
  void visit(Module module) {
    for (final child in module.subModules) {
      modules++;
      visit(child);
    }
  }

  visit(top);
  clock.reset();
  final generated =
      software ? top.generateModelSystemC(className: 'BenchmarkCsr') : null;
  final exportMicros = clock.elapsedMicroseconds;
  final output =
      arguments.where((arg) => arg.startsWith('--systemc-output=')).firstOrNull;
  if (output != null) {
    if (generated == null) {
      throw ArgumentError('--systemc-output requires --software.');
    }
    await File(output.substring('--systemc-output='.length))
        .writeAsString(generated);
  }
  Simulator.setMaxSimTime(12000);
  unawaited(Simulator.run());
  reset.inject(1);
  await clk.nextPosedge;
  await clk.nextNegedge;
  reset.inject(0);
  clock.reset();
  final addresses = [
    for (final block in config.blocks)
      for (final register in block.registers) block.baseAddr + register.addr,
  ];
  for (var cycle = 0; cycle < 1000; cycle++) {
    final address = addresses[cycle % addresses.length];
    read.addr.inject(address);
    write.addr.inject(address);
    write.en.inject(1);
    write.data.inject(cycle);
    await clk.nextPosedge;
    await clk.nextNegedge;
  }
  final simulationMicros = clock.elapsedMicroseconds;
  await Simulator.endSimulation();
  // Machine-readable benchmark output is the command's public result.
  // ignore: avoid_print
  print(jsonEncode({
    'implementation': software ? 'software' : 'rtl',
    'blocks': config.blocks.length,
    'registers': addresses.length,
    'fields': config.blocks
        .expand((block) => block.registers)
        .fold<int>(0, (sum, register) => sum + register.fields.length),
    'configuration_us': configurationMicros,
    'construction_us': constructionMicros,
    'build_us': buildMicros,
    'internal_modules': modules,
    'systemc_export_us': generated == null ? null : exportMicros,
    'systemc_bytes': generated?.length,
    'simulation_1000_cycles_us': simulationMicros,
    'peak_rss_bytes': ProcessInfo.maxRss,
    'hardware_exposure': 'none',
  }));
}

CsrTopConfig _synthetic(int count) => CsrTopConfig(
      name: 'benchmark',
      blockSize: 256,
      blocks: [
        for (var block = 0; block < 109; block++)
          CsrBlockConfig(name: 'b$block', baseAddr: block * 256, registers: [
            for (var index = block; index < count; index += 109)
              CsrInstanceConfig(
                arch: CsrConfig(
                    name: 'r$index',
                    access: CsrAccess.readWrite,
                    fields: const [],
                    isBackdoorReadable: false,
                    isBackdoorWritable: false),
                addr: index ~/ 109,
                width: 32,
              ),
          ]),
      ],
    );

CsrTopConfig _fromYaml(String path) {
  final root = loadYaml(File(path).readAsStringSync()) as YamlMap;
  final module = root['module'] as YamlMap;
  final blocks = <CsrBlockConfig>[];
  for (final rawBlock in module['blocks'] as YamlList) {
    final block = rawBlock as YamlMap;
    final registers = <CsrInstanceConfig>[];
    for (final rawRegister in block['registers'] as YamlList) {
      final register = rawRegister as YamlMap;
      final fields = <CsrFieldConfig>[];
      for (final rawField in (register['fields'] as YamlList? ?? YamlList())) {
        final field = rawField as YamlMap;
        final bits = '${field['bits']}'.split(':').map(int.parse).toList();
        final access = switch (field['access']) {
          'read_only' => CsrFieldAccess.readOnly,
          'read_write' => CsrFieldAccess.readWrite,
          'write_ones_clear' => CsrFieldAccess.writeOnesClear,
          final Object? value =>
            throw FormatException('Unsupported field access $value.'),
        };
        fields.add(CsrFieldConfig(
          name: field['name'] as String,
          start: bits.last,
          width: bits.first - bits.last + 1,
          access: access,
          resetValue: field['reset'] as int? ?? 0,
        ));
      }
      fields.sort((a, b) => a.start.compareTo(b.start));
      final access = switch (register['access']) {
        'read_only' => CsrAccess.readOnly,
        'read_write' || 'write_ones_clear' => CsrAccess.readWrite,
        final Object? value =>
          throw FormatException('Unsupported register access $value.'),
      };
      registers.add(CsrInstanceConfig(
        arch: CsrConfig(
          name: register['name'] as String,
          access: access,
          fields: fields,
          isBackdoorReadable: false,
          isBackdoorWritable: false,
        ),
        addr: register['addr'] as int,
        width: register['width'] as int,
      ));
    }
    blocks.add(CsrBlockConfig(
      name: block['name'] as String,
      baseAddr: block['base_addr'] as int,
      blockSize: registers
          .map((register) => register.addr + 1)
          .reduce((a, b) => a > b ? a : b),
      registers: registers,
    ));
  }
  return CsrTopConfig(
      name: module['name'] as String,
      blockSize: 1,
      blocks: blocks,
      asyncReset: true);
}
