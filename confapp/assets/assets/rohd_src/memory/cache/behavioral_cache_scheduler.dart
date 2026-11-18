// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_cache_scheduler.dart
// Behavioral fixed-priority cache resource scheduler.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/cache/cache_scheduler_contract.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Portable geometry of a fixed-priority cache scheduler.
@experimental
class CacheSchedulerDescription implements BehavioralModelDescription {
  /// Number of candidate requests.
  final int requestCount;

  /// Capacity of each resource.
  final List<int> capacities;

  /// Creates immutable scheduler geometry.
  CacheSchedulerDescription(
      {required this.requestCount, required List<int> capacities})
      : capacities = List.unmodifiable(capacities) {
    if (requestCount < 1 ||
        capacities.isEmpty ||
        capacities.any((capacity) => capacity < 1)) {
      throw ArgumentError('Scheduling needs requests and positive resources.');
    }
  }

  @override
  String get kind => 'cacheScheduler';

  @override
  Map<String, int> get inputPorts => Map.unmodifiable({
        'clk': 1,
        'reset': 1,
        for (final (i, capacity) in capacities.indexed)
          'available_$i': capacity.bitLength,
        for (var i = 0; i < requestCount; i++) ...{
          'request_${i}_conflicts': requestCount,
          'request_${i}_valid': 1,
          for (final (r, capacity) in capacities.indexed)
            'request_${i}_demand_$r': capacity.bitLength,
        }
      });

  @override
  Map<String, int> get outputPorts => Map.unmodifiable({
        'invalidInputs': 1,
        for (var i = 0; i < requestCount; i++) 'request_${i}_grant': 1,
      });

  /// Generates an independent combinational SystemC scheduler.
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(className)) {
      throw ArgumentError.value(
          className, 'className', 'Invalid C++ identifier.');
    }
    final twoState = options.portType == SystemCModelPortType.twoState;
    String portType(int width) => twoState
        ? width == 1
            ? 'bool'
            : width <= 64
                ? 'sc_dt::sc_uint<$width>'
                : 'sc_dt::sc_biguint<$width>'
        : width == 1
            ? 'sc_dt::sc_logic'
            : 'sc_dt::sc_lv<$width>';
    String vector(String port, int width) {
      if (width == 1) {
        return twoState
            ? 'scalar(sc_dt::sc_logic($port.read()))'
            : 'scalar($port.read())';
      }
      return twoState ? 'sc_dt::sc_lv<$width>($port.read())' : '$port.read()';
    }

    final source = StringBuffer()
      ..writeln('#pragma once')
      ..writeln('#include <systemc>')
      ..writeln('#include <cstdint>')
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit=sc_dt::sc_logic;');
    for (final (ports, direction) in [
      (inputPorts, 'in'),
      (outputPorts, 'out')
    ]) {
      for (final port in ports.entries) {
        source.writeln('  sc_core::sc_$direction<${portType(port.value)}> '
            '${port.key}{"${port.key}"};');
      }
    }
    source.writeln('''
  static sc_dt::sc_lv<1> scalar(bit value) {
    sc_dt::sc_lv<1> result; result[0]=value; return result;
  }
  template<int W> static bit gt(const sc_dt::sc_lv<W>& a, std::uint64_t b) {
    return a.is_01() ? bit(a.to_uint64()>b) : bit(sc_dt::SC_LOGIC_X);
  }
  template<int W> static bit le(const sc_dt::sc_lv<W>& a, const sc_dt::sc_lv<W>& b) {
    return a.is_01() && b.is_01()
      ? bit(a.to_uint64()<=b.to_uint64()) : bit(sc_dt::SC_LOGIC_X);
  }
  template<int W> static sc_dt::sc_lv<W> choose(
      bit s, const sc_dt::sc_lv<W>& a, const sc_dt::sc_lv<W>& b) {
    if(s==sc_dt::SC_LOGIC_1) return a;
    if(s==sc_dt::SC_LOGIC_0) return b;
    sc_dt::sc_lv<W> result;
    for(int i=0;i<W;++i)
      result[i]=(a[i]==b[i]) ? bit(a[i]) : bit(sc_dt::SC_LOGIC_X);
    return result;
  }
  template<int W> static sc_dt::sc_lv<W> subtract(
      const sc_dt::sc_lv<W>& a, const sc_dt::sc_lv<W>& b) {
    if(!a.is_01() || !b.is_01()) return sc_dt::sc_lv<W>(sc_dt::SC_LOGIC_X);
    sc_dt::sc_lv<W> result;
    result=a.to_uint64()-b.to_uint64();
    return result;
  }
  void evaluate() {
    bit rst=${twoState ? 'bit(reset.read())' : 'reset.read()'};
''');
    for (final (r, capacity) in capacities.indexed) {
      final available = vector('available_$r', capacity.bitLength);
      source
        ..writeln('    auto available$r=$available;')
        ..writeln('    auto remaining$r=available$r;');
      for (var i = 0; i < requestCount; i++) {
        source.writeln('    auto demand${i}_$r='
            '${vector('request_${i}_demand_$r', capacity.bitLength)};');
      }
    }
    for (var i = 0; i < requestCount; i++) {
      final valid = twoState
          ? 'bit(request_${i}_valid.read())'
          : 'request_${i}_valid.read()';
      final conflicts = vector('request_${i}_conflicts', requestCount);
      source
        ..writeln('    bit valid$i=$valid;')
        ..writeln('    auto conflicts$i=$conflicts;');
    }
    source.writeln('    bit invalid=sc_dt::SC_LOGIC_0;');
    for (final (r, capacity) in capacities.indexed) {
      source.writeln('    invalid=invalid | gt(available$r,${capacity}ULL);');
      for (var i = 0; i < requestCount; i++) {
        source.writeln('    invalid=invalid | '
            '(valid$i & gt(demand${i}_$r,${capacity}ULL));');
      }
    }
    source.writeln(twoState
        ? '    invalidInputs.write(invalid==sc_dt::SC_LOGIC_1);'
        : '    invalidInputs.write(invalid);');
    for (var i = 0; i < requestCount; i++) {
      source.writeln('    bit grant$i=(~rst) & (~invalid) & valid$i;');
      for (var r = 0; r < capacities.length; r++) {
        source.writeln('    grant$i=grant$i & le(demand${i}_$r,remaining$r);');
      }
      for (var earlier = 0; earlier < i; earlier++) {
        source.writeln('    grant$i=grant$i & ~(grant$earlier & '
            '(bit(conflicts$earlier[$i]) | bit(conflicts$i[$earlier])));');
      }
      source.writeln(twoState
          ? '    request_${i}_grant.write(grant$i==sc_dt::SC_LOGIC_1);'
          : '    request_${i}_grant.write(grant$i);');
      for (final (r, capacity) in capacities.indexed) {
        source.writeln('    remaining$r=subtract(remaining$r,choose(grant$i, '
            'demand${i}_$r,sc_dt::sc_lv<${capacity.bitLength}>(0)));');
      }
    }
    source.writeln('  }\n  SC_CTOR($className) {\n'
        '    SC_METHOD(evaluate); sensitive << reset');
    for (final name
        in inputPorts.keys.where((name) => name != 'clk' && name != 'reset')) {
      source.writeln('      << $name');
    }
    source.writeln('      ;\n  }\n};');
    return source.toString();
  }
}

/// Software equivalent of the fixed-priority cache scheduler.
@experimental
class BehavioralFixedPriorityCacheScheduler extends Module
    with SystemVerilog
    implements BehavioralModel, BehavioralModelProvider {
  @override
  final CacheSchedulerDescription description;

  @override
  BehavioralModel get behavioralModel => this;

  /// Creates a combinational scheduler with the RTL scheduler's ports.
  BehavioralFixedPriorityCacheScheduler({
    required Logic clk,
    required Logic reset,
    required CacheSchedulerPorts ports,
    super.name = 'behavioral_cache_scheduler',
  })  : description = CacheSchedulerDescription(
            requestCount: ports.requests.length, capacities: ports.capacities),
        super(
            definitionName: 'BehavioralFixedPriorityCacheScheduler_'
                'N${ports.requests.length}_C${ports.capacities.join('_')}') {
    if (clk.width != 1 || reset.width != 1) {
      throw ArgumentError('Scheduler clock and reset must be one bit.');
    }
    addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final local = addInterfacePorts(ports,
        inputTags: [PairDirection.fromProvider],
        outputTags: [PairDirection.fromConsumer],
        uniquify: (signal) => signal.startsWith('conflicts_')
            ? 'request_${signal.substring('conflicts_'.length)}_conflicts'
            : signal);
    void refresh() {
      final available = [for (final value in local.available) value.value];
      final valid = [for (final request in local.requests) request.valid.value];
      final demand = [
        for (final request in local.requests)
          [for (final value in request.demand) value.value]
      ];
      final conflicts = [for (final value in local.conflicts) value.value];
      var invalid = LogicValue.zero;
      for (final (r, capacity) in ports.capacities.indexed) {
        final limit = LogicValue.ofInt(capacity, capacity.bitLength);
        invalid |= available[r] > limit;
        for (var i = 0; i < valid.length; i++) {
          invalid |= valid[i] & (demand[i][r] > limit);
        }
      }
      local.invalidInputs.put(invalid);
      var remaining = available;
      final grants = <LogicValue>[];
      for (var i = 0; i < valid.length; i++) {
        var feasible = ~localReset.value & ~invalid & valid[i];
        for (var r = 0; r < available.length; r++) {
          feasible &= demand[i][r] <= remaining[r];
        }
        for (var earlier = 0; earlier < i; earlier++) {
          feasible &= ~(grants[earlier] &
              (conflicts[earlier][i] | conflicts[i][earlier]));
        }
        grants.add(feasible);
        local.requests[i].grant.put(feasible);
        remaining = [
          for (var r = 0; r < available.length; r++)
            remaining[r] -
                selectLogicValue(feasible, demand[i][r],
                    LogicValue.filled(demand[i][r].width, LogicValue.zero))
        ];
      }
    }

    for (final signal in [
      localReset,
      ...local.available,
      ...local.conflicts,
      for (final request in local.requests) ...[
        request.valid,
        ...request.demand
      ],
    ]) {
      signal.glitch.listen((_) => refresh());
    }
    Simulator.injectAction(refresh);
  }

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) =>
      description.generateSystemC(className: className, options: options);

  @override
  String? definitionVerilog(String definitionType) =>
      throw UnsupportedError('Behavioral scheduler cannot be exported as RTL.');
}
