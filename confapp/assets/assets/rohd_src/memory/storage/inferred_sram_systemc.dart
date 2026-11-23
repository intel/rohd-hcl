// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inferred_sram_systemc.dart
// Portable SystemC implementation of inferred SRAM semantics.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/behavioral/systemc_storage.dart';

/// Immutable port geometry and capacity for a single-port SRAM.
class InferredSramDescription implements BehavioralModelDescription {
  /// Address width.
  final int addressWidth;

  /// Word width.
  final int dataWidth;

  /// Number of words.
  final int entryCount;

  /// Creates a validated SRAM description.
  InferredSramDescription({
    required this.addressWidth,
    required this.dataWidth,
    required this.entryCount,
  }) {
    if (addressWidth < 1 ||
        dataWidth < 1 ||
        entryCount < 1 ||
        BigInt.from(entryCount) > (BigInt.one << addressWidth)) {
      throw ArgumentError('Invalid SRAM geometry.');
    }
  }

  @override
  String get kind => 'inferredSram';

  @override
  Map<String, int> get inputPorts => Map.unmodifiable({
        'clk': 1,
        'reset': 1,
        'wr_en_0': 1,
        'wr_addr_0': addressWidth,
        'wr_data_0': dataWidth,
        'rd_en_0': 1,
        'rd_addr_0': addressWidth,
      });

  @override
  Map<String, int> get outputPorts =>
      Map.unmodifiable({'rd_data_0': dataWidth});

  /// Generates standalone SystemC using shared sparse storage.
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
        return twoState ? 'scalar(bit($port.read()))' : 'scalar($port.read())';
      }
      return twoState ? 'sc_dt::sc_lv<$width>($port.read())' : '$port.read()';
    }

    final source = StringBuffer()
      ..writeln('#pragma once')
      ..writeln(systemCSparseStorageDefinition)
      ..writeln('#include <cstdint>')
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit=sc_dt::sc_logic;')
      ..writeln('  using word=sc_dt::sc_lv<$dataWidth>;')
      ..writeln('  using address=sc_dt::sc_lv<$addressWidth>;')
      ..writeln(
          '  using storage_type=RohdHclSystemCSparseStorage<$dataWidth>;');
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
  struct image { storage_type::image storage; word output; bool resetSeen; };
  storage_type storage;
  sc_core::sc_signal<word,sc_core::SC_MANY_WRITERS> output{"output"};
  sc_core::sc_signal<bool,sc_core::SC_MANY_WRITERS> resetSeen{"resetSeen"};
  static sc_dt::sc_lv<1> scalar(bit value) {
    sc_dt::sc_lv<1> result; result[0]=value; return result;
  }
  static word unknown() { return word(sc_dt::SC_LOGIC_X); }
  static bool inRange(const address& addr) {
    if(!addr.is_01()) return false;
    sc_dt::sc_biguint<$addressWidth> number(addr);
    return number < std::uint64_t(${entryCount}ULL);
  }
  bool contains(const address& addr) const {
    if(!inRange(addr)) throw std::out_of_range("Invalid SRAM address");
    return storage.contains(addr.to_string());
  }
  word peek(const address& addr) const {
    if(!inRange(addr)) throw std::out_of_range("Invalid SRAM address");
    return storage.read(addr.to_string(),unknown());
  }
  void poke(const address& addr, const word& value) {
    if(!inRange(addr)) throw std::out_of_range("Invalid SRAM address");
    storage.write(addr.to_string(),value);
  }
  image snapshot() const {
    return {storage.snapshot(),output.read(),resetSeen.read()};
  }
  void restore(const image& saved) {
    if(!saved.storage.uncertain.empty())
      throw std::invalid_argument("Invalid SRAM image");
    for(const auto& item:saved.storage.entries) {
      if(item.first.size()!=$addressWidth ||
          item.first.find_first_not_of("01")!=std::string::npos)
        throw std::invalid_argument("Invalid SRAM image address");
      address addr(item.first.c_str());
      if(!inRange(addr)) throw std::invalid_argument("SRAM image out of range");
    }
    storage.restore(saved.storage);
    output.write(saved.output);
    resetSeen.write(saved.resetSeen);
  }
  void tick() {
    bit rst=${twoState ? 'bit(reset.read())' : 'reset.read()'};
    bit we=${twoState ? 'bit(wr_en_0.read())' : 'wr_en_0.read()'};
    bit re=${twoState ? 'bit(rd_en_0.read())' : 'rd_en_0.read()'};
    if(rst==sc_dt::SC_LOGIC_1) {
      resetSeen.write(true);
      output.write(word(0));
    } else if(we==sc_dt::SC_LOGIC_1) {
      address addr=${vector('wr_addr_0', addressWidth)};
      if(inRange(addr)) storage.write(addr.to_string(),${vector('wr_data_0', dataWidth)});
    } else if(re==sc_dt::SC_LOGIC_1) {
      address addr=${vector('rd_addr_0', addressWidth)};
      output.write(inRange(addr) ? storage.read(addr.to_string(),unknown()) : unknown());
    }
  }
  void emit() {
    word value=output.read();
''');
    if (twoState) {
      final allow =
          options.unknownOutputs == SystemCUnknownOutputPolicy.zeroUntilReset
              ? '!resetSeen.read()'
              : 'false';
      final conversion = dataWidth == 1
          ? 'bit(value[0])==sc_dt::SC_LOGIC_1'
          : '${portType(dataWidth)}(value)';
      source.writeln('''
    if(!value.is_01() && !($allow))
      SC_REPORT_ERROR("$className", "Unknown SRAM output at two-state boundary");
    if(value.is_01()) rd_data_0.write($conversion);
    else rd_data_0.write(0);
''');
    } else {
      source.writeln(dataWidth == 1
          ? '    rd_data_0.write(bit(value[0]));'
          : '    rd_data_0.write(value);');
    }
    source.writeln('''
  }
  SC_CTOR($className) {
    output.write(unknown()); resetSeen.write(false);
    SC_METHOD(tick); sensitive << clk.pos(); dont_initialize();
    SC_METHOD(emit); sensitive << output << resetSeen;
  }
};
''');
    return source.toString();
  }
}
