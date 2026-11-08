// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_model_systemc.dart
// Behavioral SystemC export for sparse addressed memory models.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/behavioral/systemc_storage.dart';
import 'package:rohd_hcl/src/models/memory/memory_model.dart';

/// Simulator-independent geometry of an addressed software memory.
class MemoryModelDescription implements BehavioralModelDescription {
  /// Address width.
  final int addressWidth;

  /// Data width.
  final int dataWidth;

  /// Read latency in sampling edges.
  final int readLatency;

  /// Whether reset asynchronously clears storage.
  final bool asyncReset;

  /// Optional finite register-file semantics.
  final RegisterFileModelConfiguration? registerFile;

  /// Whether each write port carries a byte mask.
  final List<bool> writeMasked;

  /// Whether each read port carries an unused mask input.
  final List<bool> readMasked;

  /// Creates frozen memory geometry.
  MemoryModelDescription({
    required this.addressWidth,
    required this.dataWidth,
    required this.readLatency,
    required this.asyncReset,
    required List<bool> writeMasked,
    required List<bool> readMasked,
    this.registerFile,
  })  : writeMasked = List.unmodifiable(writeMasked),
        readMasked = List.unmodifiable(readMasked) {
    if (addressWidth < 1 ||
        dataWidth < 1 ||
        readLatency < 0 ||
        (writeMasked.isEmpty && readMasked.isEmpty) ||
        ([...writeMasked, ...readMasked].contains(true) &&
            dataWidth % 8 != 0) ||
        (registerFile != null &&
            (readLatency != 0 ||
                asyncReset ||
                readMasked.contains(true) ||
                registerFile!.resetValues
                    .any((value) => value.width != dataWidth)))) {
      throw ArgumentError('Invalid memory model geometry.');
    }
  }

  @override
  String get kind => 'memory';

  @override
  Map<String, int> get inputPorts => Map.unmodifiable({
        'clk': 1,
        'reset': 1,
        for (var i = 0; i < writeMasked.length; i++) ...{
          'wr_en_$i': 1,
          'wr_addr_$i': addressWidth,
          'wr_data_$i': dataWidth,
          if (writeMasked[i]) 'wr_mask_$i': dataWidth ~/ 8,
        },
        for (var i = 0; i < readMasked.length; i++) ...{
          'rd_en_$i': 1,
          'rd_addr_$i': addressWidth,
          if (readMasked[i]) 'rd_mask_$i': dataWidth ~/ 8,
        },
      });

  @override
  Map<String, int> get outputPorts => Map.unmodifiable(
      {for (var i = 0; i < readMasked.length; i++) 'rd_data_$i': dataWidth});

  /// Emits the default sparse-memory implementation at a four-state boundary.
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(className)) {
      throw ArgumentError.value(
          className, 'className', 'Invalid C++ identifier.');
    }
    if (options.portType != SystemCModelPortType.fourState) {
      throw UnsupportedError('MemoryModel SystemC requires four-state ports.');
    }
    if (registerFile != null) {
      return _generateRegisterFileSystemC(className);
    }
    String portType(int width) => width == 1 ? 'bit' : 'sc_dt::sc_lv<$width>';
    String readVector(String port, int width, String type) =>
        width == 1 ? '$type($port.read())' : '$port.read()';
    final maskWidth = dataWidth % 8 == 0 ? dataWidth ~/ 8 : 1;
    final source = StringBuffer()
      ..writeln('#pragma once')
      ..writeln('#include <array>')
      ..writeln('#include <vector>')
      ..writeln(systemCSparseStorageDefinition)
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit=sc_dt::sc_logic;')
      ..writeln('  using address=sc_dt::sc_lv<$addressWidth>;')
      ..writeln('  using word=sc_dt::sc_lv<$dataWidth>;')
      ..writeln('  using mask=sc_dt::sc_lv<$maskWidth>;')
      ..writeln('  using storage=RohdHclSystemCSparseStorage<$dataWidth>;');
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
  struct write_sample { bit en; address addr; word data; mask bytes; };
  struct read_sample { bit en; address addr; };
  struct pending { int port, remaining; word value; };
  struct state {
    storage words;
    std::array<write_sample, ${writeMasked.length}> writes;
    std::array<read_sample, ${readMasked.length}> reads;
    std::array<word, ${readMasked.length}> outputs;
    std::vector<pending> reads_pending;
    bit reset=sc_dt::SC_LOGIC_X;
  };
  class image {
    friend struct $className;
    state value;
    explicit image(const state& s) : value(s) {}
  };
  state data;
  sc_core::sc_event sampled, changed, recompute;
  image snapshot() const { return image(data); }
  void restore(const image& saved) {
    data=saved.value;
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  static bool known(bit x) {
    return x==sc_dt::SC_LOGIC_0 || x==sc_dt::SC_LOGIC_1;
  }
  static address scalar_address(bit x) { address v; v[0]=x; return v; }
  static word scalar_word(bit x) { word v; v[0]=x; return v; }
  static mask scalar_mask(bit x) { mask v; v[0]=x; return v; }
  static void check_address(const std::string& value) {
    if(value.size()!=$addressWidth ||
        value.find_first_not_of("01")!=std::string::npos)
      throw std::invalid_argument("Invalid memory address");
  }
  bool contains(const std::string& addr) const {
    check_address(addr); return data.words.contains(addr);
  }
  word peek(const std::string& addr) const {
    check_address(addr);
    if(!data.words.contains(addr)) throw std::out_of_range("Unpopulated memory");
    return data.words.read(addr,word(sc_dt::SC_LOGIC_X));
  }
  void poke(const std::string& addr, const word& value) {
    check_address(addr); data.words.write(addr,value);
  }
  word read_word(const address& addr) const {
    auto key=addr.to_string();
    if(!data.words.contains(key))
      SC_REPORT_WARNING("MEMORY_INVALID_READ", "Reading unpopulated memory");
    return data.words.read(key,word(sc_dt::SC_LOGIC_X));
  }
  void input_changed() { sampled.notify(sc_core::SC_ZERO_TIME); }
  void sample() {
    data.reset=reset.read();
''');
    for (var i = 0; i < writeMasked.length; i++) {
      final mask = writeMasked[i]
          ? readVector('wr_mask_$i', maskWidth, 'scalar_mask')
          : 'mask(sc_dt::SC_LOGIC_1)';
      source.writeln('    data.writes[$i]={wr_en_$i.read(),'
          '${readVector('wr_addr_$i', addressWidth, 'scalar_address')},'
          '${readVector('wr_data_$i', dataWidth, 'scalar_word')},$mask};');
    }
    for (var i = 0; i < readMasked.length; i++) {
      source.writeln('    data.reads[$i]={rd_en_$i.read(),'
          '${readVector('rd_addr_$i', addressWidth, 'scalar_address')}};');
    }
    source.writeln('''
  }
  void drive() {
''');
    for (var i = 0; i < readMasked.length; i++) {
      source.writeln(dataWidth == 1
          ? '    rd_data_$i.write(bit(data.outputs[$i][0]));'
          : '    rd_data_$i.write(data.outputs[$i]);');
    }
    source.writeln('''
  }
  void tick() {
    std::vector<pending> remaining;
    for(auto item:data.reads_pending) {
      if(--item.remaining==0) data.outputs[item.port]=item.value;
      else remaining.push_back(item);
    }
    data.reads_pending=std::move(remaining);
    changed.notify(sc_core::SC_ZERO_TIME);
    if(data.reset==sc_dt::SC_LOGIC_1) { data.words.clear(); return; }
''');
    for (var i = 0; i < writeMasked.length; i++) {
      source.writeln('''
    {
      auto w=data.writes[$i];
      bool enabled=w.en!=sc_dt::SC_LOGIC_0;
''');
      if (writeMasked[i]) {
        source.writeln('''
      bool any_mask=false;
      for(int byte=0;byte<$maskWidth;++byte)
        if(w.bytes[byte]!=sc_dt::SC_LOGIC_0) any_mask=true;
      enabled=enabled && any_mask;
''');
      }
      source.writeln('''
      if(enabled && !w.addr.is_01()) {
        word affected(0);
''');
      if (writeMasked[i]) {
        source.writeln('''
        for(int byte=0;byte<$maskWidth;++byte)
          if(w.bytes[byte]!=sc_dt::SC_LOGIC_0)
            for(int bit=byte*8;bit<(byte+1)*8;++bit) affected[bit]=sc_dt::SC_LOGIC_1;
''');
      } else {
        source.writeln('        affected=word(sc_dt::SC_LOGIC_1);');
      }
      source.writeln('''
        data.words.write_uncertain(w.addr.to_string(),affected);
        SC_REPORT_WARNING("MEMORY_INVALID_WRITE", "Uncertain write address");
      } else if(enabled) {
''');
      if (writeMasked[i]) {
        source.writeln('''
        if(!known(w.en) || !w.bytes.is_01())
          SC_REPORT_WARNING("MEMORY_INVALID_WRITE", "Uncertain write control");
        bool need_old=false;
        for(int byte=0;byte<$maskWidth;++byte)
          if(w.bytes[byte]==sc_dt::SC_LOGIC_0) need_old=true;
        word result=need_old ? read_word(w.addr) : word(sc_dt::SC_LOGIC_X);
        for(int byte=0;byte<$maskWidth;++byte) {
          if(w.bytes[byte]==sc_dt::SC_LOGIC_0) continue;
          for(int bit=byte*8;bit<(byte+1)*8;++bit)
            result[bit]=(!known(w.en) || !known(w.bytes[byte]))
              ? sc_dt::sc_logic(sc_dt::SC_LOGIC_X) : sc_dt::sc_logic(w.data[bit]);
        }
        data.words.write(w.addr.to_string(),result);
''');
      } else {
        source.writeln('''
        if(!known(w.en))
          SC_REPORT_WARNING("MEMORY_INVALID_WRITE", "Uncertain write enable");
        data.words.write(w.addr.to_string(),
            known(w.en) ? w.data : word(sc_dt::SC_LOGIC_X));
''');
      }
      source.writeln('      }\n    }');
    }
    if (readLatency == 0) {
      source.writeln('    recompute.notify(sc_core::SC_ZERO_TIME);');
    } else {
      for (var i = 0; i < readMasked.length; i++) {
        source.writeln('''
    {
      auto r=data.reads[$i];
      word value=(!known(r.en) || r.en==sc_dt::SC_LOGIC_0 || !r.addr.is_01())
          ? word(sc_dt::SC_LOGIC_X) : read_word(r.addr);
''');
        if (readLatency == 1) {
          source.writeln('      data.outputs[$i]=value;');
        } else {
          source.writeln('      data.reads_pending.push_back'
              ' ({$i,${readLatency - 1},value});');
        }
        source.writeln('    }');
      }
    }
    source.writeln('  }');
    if (asyncReset) {
      source.writeln('  void reset_async() { data.words.clear(); }');
    }
    if (readLatency == 0) {
      source.writeln('  void read_comb() {');
      for (var i = 0; i < readMasked.length; i++) {
        source.writeln('''
    {
      bit en=rd_en_$i.read();
      address addr=${readVector('rd_addr_$i', addressWidth, 'scalar_address')};
      data.outputs[$i]=(!known(en) || en==sc_dt::SC_LOGIC_0 || !addr.is_01())
          ? word(sc_dt::SC_LOGIC_X) : read_word(addr);
    }
''');
      }
      source.writeln('    changed.notify(sc_core::SC_ZERO_TIME);\n  }');
    }
    source.writeln('''
  SC_CTOR($className) {
    for(auto& output:data.outputs) output=word(sc_dt::SC_LOGIC_Z);
    SC_METHOD(tick); sensitive << clk.pos(); dont_initialize();
    SC_METHOD(input_changed); sensitive << reset
''');
    for (var i = 0; i < writeMasked.length; i++) {
      source.writeln('      << wr_en_$i << wr_addr_$i << wr_data_$i'
          '${writeMasked[i] ? ' << wr_mask_$i' : ''}');
    }
    for (var i = 0; i < readMasked.length; i++) {
      source.writeln('      << rd_en_$i << rd_addr_$i');
    }
    source
      ..writeln('      ; dont_initialize();')
      ..writeln('    SC_METHOD(sample); sensitive << sampled;')
      ..writeln('    SC_METHOD(drive); sensitive << changed;');
    if (asyncReset) {
      source.writeln('    SC_METHOD(reset_async); sensitive << reset.pos();'
          ' dont_initialize();');
    }
    if (readLatency == 0) {
      source.writeln('    SC_METHOD(read_comb); sensitive << recompute');
      for (var i = 0; i < readMasked.length; i++) {
        source.writeln('      << rd_en_$i << rd_addr_$i');
      }
      source.writeln('      ; dont_initialize();');
    }
    source.writeln('  }\n};');
    return source.toString();
  }

  String _generateRegisterFileSystemC(String className) {
    final config = registerFile!;
    String portType(int width) => width == 1 ? 'bit' : 'sc_dt::sc_lv<$width>';
    String readVector(String port, int width, String type) =>
        width == 1 ? '$type($port.read())' : '$port.read()';
    String address(int index) =>
        index.toRadixString(2).padLeft(addressWidth, '0');
    final count = BigInt.from(config.numEntries) < (BigInt.one << addressWidth)
        ? config.numEntries
        : (BigInt.one << addressWidth).toInt();
    final maskWidth = dataWidth % 8 == 0 ? dataWidth ~/ 8 : 1;
    final source = StringBuffer()
      ..writeln('#pragma once')
      ..writeln('#include <array>')
      ..writeln(systemCSparseStorageDefinition)
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit=sc_dt::sc_logic;')
      ..writeln('  using address=sc_dt::sc_lv<$addressWidth>;')
      ..writeln('  using word=sc_dt::sc_lv<$dataWidth>;')
      ..writeln('  using mask=sc_dt::sc_lv<$maskWidth>;')
      ..writeln('  using storage=RohdHclSystemCSparseStorage<$dataWidth>;');
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
  struct write_sample { bit en; address addr; word data; mask bytes; bool masked; };
  struct state {
    storage words;
    std::array<write_sample, ${writeMasked.length}> writes;
    std::array<word, ${readMasked.length}> outputs;
    bit reset=sc_dt::SC_LOGIC_X;
  };
  class image {
    friend struct $className;
    state value;
    explicit image(const state& s) : value(s) {}
  };
  state data;
  sc_core::sc_event sampled, changed, recompute;
  image snapshot() const { return image(data); }
  void restore(const image& saved) {
    data=saved.value;
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  static address scalar_address(bit x) { address v; v[0]=x; return v; }
  static word scalar_word(bit x) { word v; v[0]=x; return v; }
  static mask scalar_mask(bit x) { mask v; v[0]=x; return v; }
  static void check_address(const std::string& value) {
    if(value.size()!=$addressWidth ||
        value.find_first_not_of("01")!=std::string::npos)
      throw std::invalid_argument("Invalid memory address");
  }
  bool contains(const std::string& addr) const {
    check_address(addr); return data.words.contains(addr);
  }
  word peek(const std::string& addr) const {
    check_address(addr);
    if(!data.words.contains(addr)) throw std::out_of_range("Unpopulated memory");
    return data.words.read(addr,word(sc_dt::SC_LOGIC_X));
  }
  void poke(const std::string& addr, const word& value) {
    check_address(addr); data.words.write(addr,value);
  }
  word read_word(const address& addr) const {
    const auto key=addr.to_string();
''');
    for (var index = 0; index < count; index++) {
      source.writeln('    if(key=="${address(index)}") '
          'return data.words.read(key,word(sc_dt::SC_LOGIC_X));');
    }
    source.writeln('''
    return word(0);
  }
  void input_changed() { sampled.notify(sc_core::SC_ZERO_TIME); }
  void sample() {
    data.reset=reset.read();
''');
    for (var i = 0; i < writeMasked.length; i++) {
      final mask = writeMasked[i]
          ? readVector('wr_mask_$i', maskWidth, 'scalar_mask')
          : 'mask(sc_dt::SC_LOGIC_1)';
      source.writeln('    data.writes[$i]={wr_en_$i.read(),'
          '${readVector('wr_addr_$i', addressWidth, 'scalar_address')},'
          '${readVector('wr_data_$i', dataWidth, 'scalar_word')},$mask,'
          '${writeMasked[i]}};');
    }
    source.writeln('''
  }
  void drive() {
''');
    for (var i = 0; i < readMasked.length; i++) {
      source.writeln(dataWidth == 1
          ? '    rd_data_$i.write(bit(data.outputs[$i][0]));'
          : '    rd_data_$i.write(data.outputs[$i]);');
    }
    source.writeln('''
  }
  void tick() {
    if(data.reset==sc_dt::SC_LOGIC_1) {
      data.words.clear();
''');
    for (var index = 0; index < count; index++) {
      final value = config.resetValues[index];
      source.writeln('      { word resetWord(sc_dt::SC_LOGIC_X);');
      for (var bit = 0; bit < dataWidth; bit++) {
        final digit = value[bit].toString(includeWidth: false).toUpperCase();
        source.writeln("        resetWord[$bit]=sc_dt::sc_logic('$digit');");
      }
      source.writeln(
          '        data.words.write("${address(index)}",resetWord); }');
    }
    source.writeln('''
    } else {
      const auto original=data.words;
''');
    for (var index = 0; index < count; index++) {
      source.writeln('''
      {
        const std::string key="${address(index)}";
        const word old=original.read(key,word(sc_dt::SC_LOGIC_X));
        for(const auto& w:data.writes) {
          bit selected=w.en;
          for(int b=0;b<$addressWidth;++b) {
            bit a=w.addr[b];
            if(a!=sc_dt::SC_LOGIC_0 && a!=sc_dt::SC_LOGIC_1)
              selected &= bit(sc_dt::SC_LOGIC_X);
            else if(a!=bit(key[$addressWidth-b-1]))
              selected &= bit(sc_dt::SC_LOGIC_0);
          }
          if(selected==sc_dt::SC_LOGIC_0) continue;
          word result=old;
          if(!w.masked) {
            result=selected==sc_dt::SC_LOGIC_1
                ? w.data : word(sc_dt::SC_LOGIC_X);
          } else {
            for(int byte=0;byte<$maskWidth;++byte) {
              if(w.bytes[byte]==sc_dt::SC_LOGIC_0) continue;
              for(int b=byte*8;b<(byte+1)*8;++b)
                result[b]=(selected==sc_dt::SC_LOGIC_1 &&
                            w.bytes[byte]==sc_dt::SC_LOGIC_1)
                    ? bit(w.data[b]) : bit(sc_dt::SC_LOGIC_X);
            }
          }
          data.words.write(key,result);
        }
      }
''');
    }
    source.writeln('''
    }
    recompute.notify(sc_core::SC_ZERO_TIME);
  }
  void read_comb() {
''');
    for (var i = 0; i < readMasked.length; i++) {
      source.writeln('''
    {
      bit en=rd_en_$i.read();
      address addr=${readVector('rd_addr_$i', addressWidth, 'scalar_address')};
      data.outputs[$i]=en==sc_dt::SC_LOGIC_0 ? word(0)
          : en!=sc_dt::SC_LOGIC_1 || !addr.is_01()
              ? word(sc_dt::SC_LOGIC_X) : read_word(addr);
    }
''');
    }
    source.writeln('''
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  SC_CTOR($className) {
    for(auto& output:data.outputs) output=word(sc_dt::SC_LOGIC_Z);
    SC_METHOD(tick); sensitive << clk.pos(); dont_initialize();
    SC_METHOD(input_changed); sensitive << reset
''');
    for (var i = 0; i < writeMasked.length; i++) {
      source.writeln('      << wr_en_$i << wr_addr_$i << wr_data_$i'
          '${writeMasked[i] ? ' << wr_mask_$i' : ''}');
    }
    source
      ..writeln('      ; dont_initialize();')
      ..writeln('    SC_METHOD(sample); sensitive << sampled;')
      ..writeln('    SC_METHOD(drive); sensitive << changed;')
      ..writeln('    SC_METHOD(read_comb); sensitive << recompute');
    for (var i = 0; i < readMasked.length; i++) {
      source.writeln('      << rd_en_$i << rd_addr_$i');
    }
    source
      ..writeln('      ;')
      ..writeln('  }\n};');
    return source.toString();
  }
}
