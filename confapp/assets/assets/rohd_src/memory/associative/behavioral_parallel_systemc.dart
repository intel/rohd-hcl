// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_parallel_systemc.dart
// SystemC implementation of parallel associative memory.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/behavioral/systemc_storage.dart';

/// Frozen port geometry for a parallel associative behavioral model.
class BehavioralParallelAssociativeDescription
    implements BehavioralModelDescription {
  /// Entry count.
  final int entryCount;

  /// Key width.
  final int keyWidth;

  /// Index width.
  final int indexWidth;

  /// Number of update ports.
  final int updateCount;

  /// Whether each lookup port exposes the full match vector.
  final List<bool> matchVectors;

  /// Number of indexed side reads.
  final int sideReadCount;

  /// Whether validity tracking ports are exposed.
  final bool trackValidity;

  /// Match preference.
  final AssociativeMatchSelection selection;

  /// Update collision priority.
  final AssociativeUpdateCollisionPolicy collision;

  /// Creates immutable parallel-memory geometry.
  BehavioralParallelAssociativeDescription({
    required this.entryCount,
    required this.keyWidth,
    required this.indexWidth,
    required this.updateCount,
    required List<bool> matchVectors,
    required this.sideReadCount,
    required this.trackValidity,
    required this.selection,
    required this.collision,
  }) : matchVectors = List.unmodifiable(matchVectors) {
    if (entryCount < 1 ||
        keyWidth < 1 ||
        indexWidth < 1 ||
        BigInt.from(entryCount) > (BigInt.one << indexWidth) ||
        updateCount < 0 ||
        matchVectors.isEmpty ||
        sideReadCount < 0 ||
        collision == AssociativeUpdateCollisionPolicy.disallow) {
      throw ArgumentError('Invalid parallel associative geometry.');
    }
  }

  @override
  String get kind => 'parallelAssociative';

  @override
  Map<String, int> get inputPorts => Map.unmodifiable({
        'clk': 1,
        'reset': 1,
        for (var i = 0; i < updateCount; i++) ...{
          'update_en_$i': 1,
          'update_index_$i': indexWidth,
          'update_key_$i': keyWidth,
          'update_entryValid_$i': 1,
        },
        for (var i = 0; i < matchVectors.length; i++) ...{
          'lookup_en_$i': 1,
          'lookup_key_$i': keyWidth,
        },
        for (var i = 0; i < sideReadCount; i++)
          'side_read_index${i == 0 ? '' : '_$i'}': indexWidth,
      });

  @override
  Map<String, int> get outputPorts => Map.unmodifiable({
        for (var i = 0; i < matchVectors.length; i++) ...{
          'lookup_hit_$i': 1,
          'lookup_index_$i': indexWidth,
          if (matchVectors[i]) 'lookup_matchVector_$i': entryCount,
        },
        if (trackValidity) ...{
          'valid_count': entryCount.bitLength,
          'full': 1,
          'empty': 1,
          'valid_mask': entryCount,
        },
        for (var i = 0; i < sideReadCount; i++) ...{
          'side_read_key${i == 0 ? '' : '_$i'}': keyWidth,
          'side_read_valid${i == 0 ? '' : '_$i'}': 1,
        },
      });

  /// Generates a combinational-lookup, synchronous-update SystemC module.
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(className)) {
      throw ArgumentError.value(className, 'className', 'Invalid identifier.');
    }
    final twoState = options.portType == SystemCModelPortType.twoState;
    final selectWidth = max(1, (entryCount - 1).bitLength);
    final countWidth = entryCount.bitLength;
    String portType(int width) => twoState
        ? width == 1
            ? 'bool'
            : width <= 64
                ? 'sc_dt::sc_uint<$width>'
                : 'sc_dt::sc_biguint<$width>'
        : width == 1
            ? 'sc_dt::sc_logic'
            : 'sc_dt::sc_lv<$width>';
    String vector(String port, int width) => width == 1
        ? 'scalar(${twoState ? 'bit($port.read())' : '$port.read()'})'
        : twoState
            ? 'sc_dt::sc_lv<$width>($port.read())'
            : '$port.read()';
    String scalarRead(String port) =>
        twoState ? 'bit($port.read())' : '$port.read()';
    String emit(String port, String expr, int width) {
      if (!twoState) {
        return width == 1
            ? '$port.write(bit(($expr)[0]));'
            : '$port.write($expr);';
      }
      final allow =
          options.unknownOutputs == SystemCUnknownOutputPolicy.zeroUntilReset
              ? '!reset_seen'
              : 'false';
      final converted = width == 1
          ? 'bit(value[0])==sc_dt::SC_LOGIC_1'
          : '${portType(width)}(value)';
      return '''
    { sc_dt::sc_lv<$width> value=$expr;
      if(!value.is_01() && !($allow))
        SC_REPORT_ERROR("$className", "Unknown output $port at two-state boundary");
      if(value.is_01()) $port.write($converted); else $port.write(0);
    }''';
    }

    final source = StringBuffer()
      ..writeln('#pragma once')
      ..writeln(systemCSparseStorageDefinition)
      ..writeln('#include <array>')
      ..writeln('#include <cstdint>')
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit=sc_dt::sc_logic;')
      ..writeln('  using key=sc_dt::sc_lv<$keyWidth>;')
      ..writeln('  using address=sc_dt::sc_lv<$indexWidth>;')
      ..writeln('  using selected=sc_dt::sc_lv<$selectWidth>;')
      ..writeln('  using mask=sc_dt::sc_lv<$entryCount>;')
      ..writeln(
          '  using storage_type=RohdHclSystemCSparseStorage<${keyWidth + 1}>;');
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
  struct image { storage_type::image entries; bool reset_seen; ${twoState ? '' : 'bit old_clock;'} };
  storage_type entries;
  bool reset_seen=false;
  ${twoState ? '' : 'bit old_clock=sc_dt::SC_LOGIC_X;'}
  sc_core::sc_event changed;
  static sc_dt::sc_lv<1> scalar(bit value) {
    sc_dt::sc_lv<1> result; result[0]=value; return result;
  }
  static bool known(bit x) {
    return x==sc_dt::SC_LOGIC_0 || x==sc_dt::SC_LOGIC_1;
  }
  static bit equal(bit a, bit b) {
    return known(a) && known(b) ? bit(a==b) : bit(sc_dt::SC_LOGIC_X);
  }
  static bit normalize(bit x) {
    return x==sc_dt::SC_LOGIC_Z ? bit(sc_dt::SC_LOGIC_X) : x;
  }
  template<int W> static sc_dt::sc_lv<W> choose(
      bit control, const sc_dt::sc_lv<W>& yes, const sc_dt::sc_lv<W>& no) {
    if(control==sc_dt::SC_LOGIC_1) return yes;
    if(control==sc_dt::SC_LOGIC_0) return no;
    sc_dt::sc_lv<W> result;
    for(int i=0;i<W;++i)
      result[i]=yes[i]==no[i] ? bit(yes[i]) : bit(sc_dt::SC_LOGIC_X);
    return result;
  }
  static bit matches_index(const address& addr, int index) {
    bit result=sc_dt::SC_LOGIC_1;
    address wanted(index);
    for(int i=0;i<$indexWidth;++i) result=result & equal(addr[i],wanted[i]);
    return result;
  }
  struct entry { key value; bit valid; };
  entry read(int index) const {
    auto stored=entries.read(std::to_string(index),
        typename storage_type::word(sc_dt::SC_LOGIC_X));
    entry result{key(sc_dt::SC_LOGIC_X),bit(stored[$keyWidth])};
    for(int i=0;i<$keyWidth;++i) result.value[i]=stored[i];
    return result;
  }
  void write(int index, const entry& value) {
    typename storage_type::word packed;
    for(int i=0;i<$keyWidth;++i) packed[i]=normalize(value.value[i]);
    packed[$keyWidth]=normalize(value.valid);
    entries.write(std::to_string(index),packed);
  }
  image snapshot() const { return {entries.snapshot(),reset_seen${twoState ? '' : ',old_clock'}}; }
  void restore(const image& saved) {
    if(!saved.entries.uncertain.empty())
      throw std::invalid_argument("Invalid associative image");
    for(const auto& item:saved.entries.entries) {
      bool valid=false;
      for(int i=0;i<$entryCount;++i)
        if(item.first==std::to_string(i)) valid=true;
      if(!valid) throw std::invalid_argument("Invalid associative index");
    }
    entries.restore(saved.entries); reset_seen=saved.reset_seen;
    ${twoState ? '' : 'old_clock=saved.old_clock;'}
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  void tick() {
    ${twoState ? '' : '''
    bit clock=clk.read(), previous=old_clock;
    old_clock=clock;
    if(!known(previous) || !known(clock)) {
      for(int i=0;i<$entryCount;++i)
        write(i,{key(sc_dt::SC_LOGIC_X),bit(sc_dt::SC_LOGIC_X)});
      changed.notify(sc_core::SC_ZERO_TIME);
      return;
    }
    if(previous!=sc_dt::SC_LOGIC_0 || clock!=sc_dt::SC_LOGIC_1) return;
    '''}
    bit rst=${scalarRead('reset')};
    if(rst==sc_dt::SC_LOGIC_1) {
      for(int i=0;i<$entryCount;++i) write(i,{key(0),bit(sc_dt::SC_LOGIC_0)});
      reset_seen=true;
    } else if(rst!=sc_dt::SC_LOGIC_0) {
      for(int i=0;i<$entryCount;++i)
        write(i,{key(sc_dt::SC_LOGIC_X),bit(sc_dt::SC_LOGIC_X)});
    } else {
      for(int i=0;i<$entryCount;++i) {
        entry next=read(i);
''');
    final ports = collision == AssociativeUpdateCollisionPolicy.lowestPortWins
        ? List.generate(updateCount, (i) => updateCount - i - 1)
        : List.generate(updateCount, (i) => i);
    for (final i in ports) {
      source.writeln('''
        { bit en=${scalarRead('update_en_$i')};
          address addr=${vector('update_index_$i', indexWidth)};
          bit selected=en & matches_index(addr,i);
          if(selected==sc_dt::SC_LOGIC_1)
            next={${vector('update_key_$i', keyWidth)},${scalarRead('update_entryValid_$i')}};
          else if(selected!=sc_dt::SC_LOGIC_0)
            next={key(sc_dt::SC_LOGIC_X),bit(sc_dt::SC_LOGIC_X)};
        }
''');
    }
    source.writeln('''
        write(i,next);
      }
    }
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  void drive() {
    mask validity;
    for(int i=0;i<$entryCount;++i) validity[i]=read(i).valid;
''');
    if (trackValidity) {
      source.writeln('''
    sc_dt::sc_lv<$countWidth> count(0);
    if(!validity.is_01()) count=sc_dt::sc_lv<$countWidth>(sc_dt::SC_LOGIC_X);
    else { unsigned n=0; for(int i=0;i<$entryCount;++i)
      if(bit(validity[i])==sc_dt::SC_LOGIC_1) ++n;
      count=sc_dt::sc_lv<$countWidth>(n); }
    bit all=sc_dt::SC_LOGIC_1, any=sc_dt::SC_LOGIC_0;
    for(int i=0;i<$entryCount;++i) { all=all & bit(validity[i]); any=any | bit(validity[i]); }
    ${emit('valid_count', 'count', countWidth)}
    ${emit('full', 'scalar(all)', 1)}
    ${emit('empty', 'scalar(~any)', 1)}
    ${emit('valid_mask', 'validity', entryCount)}
''');
    }
    for (var i = 0; i < matchVectors.length; i++) {
      source.writeln('''
    { key query=${vector('lookup_key_$i', keyWidth)};
      bit en=${scalarRead('lookup_en_$i')};
      mask matches; bit found=sc_dt::SC_LOGIC_0; selected chosen(0);
      for(int j=0;j<$entryCount;++j) {
        entry stored=read(j); bit same=sc_dt::SC_LOGIC_1;
        for(int b=0;b<$keyWidth;++b) same=same & equal(query[b],stored.value[b]);
        bit match=stored.valid & same; matches[j]=match;
        bit preferred=chosen.is_01()
            ? bit(j ${selection == AssociativeMatchSelection.lowestIndex ? '<' : '>'} chosen.to_uint64())
            : bit(sc_dt::SC_LOGIC_X);
        chosen=choose<$selectWidth>(match & (~found | preferred),selected(j),chosen);
        found=found | match;
      }
      bit hit=en & found;
      address extended(0);
      for(int b=0;b<$selectWidth;++b) extended[b]=chosen[b];
      address index=choose<$indexWidth>(hit,extended,address(0));
      mask enabled=choose<$entryCount>(en,matches,mask(0));
      ${emit('lookup_hit_$i', 'scalar(hit)', 1)}
      ${emit('lookup_index_$i', 'index', indexWidth)}
      ${matchVectors[i] ? emit('lookup_matchVector_$i', 'enabled', entryCount) : ''}
    }
''');
    }
    for (var i = 0; i < sideReadCount; i++) {
      final suffix = i == 0 ? '' : '_$i';
      source.writeln('''
    { address addr=${vector('side_read_index$suffix', indexWidth)};
      entry result{key(sc_dt::SC_LOGIC_X),bit(sc_dt::SC_LOGIC_X)};
      if(addr.is_01()) {
        sc_dt::sc_biguint<$indexWidth> n(addr);
        result=n<std::uint64_t(${entryCount}ULL)
            ? read(static_cast<int>(n.to_uint64()))
            : entry{key(0),bit(sc_dt::SC_LOGIC_0)};
      }
      ${emit('side_read_key$suffix', 'result.value', keyWidth)}
      ${emit('side_read_valid$suffix', 'scalar(result.valid)', 1)}
    }
''');
    }
    source.writeln('''
  }
  SC_CTOR($className) {
    SC_METHOD(tick); sensitive << ${twoState ? 'clk.pos()' : 'clk'}; dont_initialize();
    SC_METHOD(drive); sensitive << changed
''');
    for (var i = 0; i < matchVectors.length; i++) {
      source.writeln('      << lookup_en_$i << lookup_key_$i');
    }
    for (var i = 0; i < sideReadCount; i++) {
      source.writeln('      << side_read_index${i == 0 ? '' : '_$i'}');
    }
    source.writeln('    ;\n  }\n};');
    return source.toString();
  }
}
