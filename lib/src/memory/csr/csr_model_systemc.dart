// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_model_systemc.dart
// SystemC export for CSR software models.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Behavioral SystemC export for whole-top software CSRs.
extension CsrModelSystemC on CsrModelDescription {
  /// Emits a standalone SystemC header with the CSR top's ROHD port names.
  ///
  /// Use `sc_signal<sc_logic>` for one-bit ports and `sc_signal<sc_lv<W>>`
  /// for wider ports. This is an explicit behavioral backend, not synthesized
  /// RTL. The returned class can replace the CSR top at an external boundary.
  /// [options] selects boundary types and an explicit unknown-output policy.
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    final twoStatePorts = options.portType == SystemCModelPortType.twoState;
    final identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
    for (final name in [className, ...inputPorts.keys, ...outputPorts.keys]) {
      if (!identifier.hasMatch(name)) {
        throw ArgumentError.value(name, 'name', 'Invalid SystemC identifier.');
      }
    }
    if ((frontRead?.addressWidth ?? 0) > 63 ||
        (frontWrite?.addressWidth ?? 0) > 63 ||
        registers.keys.any((address) => address < 0)) {
      throw UnsupportedError(
          'Behavioral SystemC CSR addresses require 0..63 bits.');
    }
    final width = maximumValueWidth;
    String bits(LogicValue value) =>
        MemoryValueCodec.binary(value, width: width);
    String number(int value, int bitWidth) =>
        bits(LogicValue.ofInt(value, bitWidth));
    String scalar(String name) =>
        twoStatePorts ? 'sc_dt::sc_logic($name.read())' : '$name.read()';
    String data(String name, int width) => width == 1
        ? 'word(${scalar(name)})'
        : twoStatePorts
            ? 'word($name.read().to_string(sc_dt::SC_BIN,false).c_str())'
            : 'word($name.read().to_string().c_str())';
    String valid(String name, int width) => twoStatePorts
        ? 'true'
        : width == 1
            ? 'known($name.read())'
            : '$name.read().is_01()';
    String address(String name, int width) => width == 1
        ? twoStatePorts
            ? '$name.read()'
            : '$name.read().to_bool()'
        : '$name.read().to_uint64()';
    String portType(int width) => twoStatePorts
        ? width == 1
            ? 'bool'
            : width <= 64
                ? 'sc_dt::sc_uint<$width>'
                : 'sc_dt::sc_biguint<$width>'
        : width == 1
            ? 'sc_dt::sc_logic'
            : 'sc_dt::sc_lv<$width>';
    final indices = <CsrModelRegisterDescription, int>{
      for (final entry in registers.values) entry: 0,
    };
    var next = 0;
    for (final entry in indices.keys) {
      indices[entry] = next++;
    }
    final source = StringBuffer()
      ..writeln('#pragma once')
      ..writeln('#include <systemc>')
      ..writeln('#include <algorithm>')
      ..writeln('#include <map>')
      ..writeln('#include <vector>')
      ..writeln('#include <sstream>')
      ..writeln('#include <stdexcept>')
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using word = sc_dt::sc_lv<$width>;');
    for (final (ports, direction) in [
      (inputPorts, 'in'),
      (outputPorts, 'out'),
    ]) {
      for (final port in ports.entries) {
        final type = portType(port.value);
        source.writeln(
            '  sc_core::sc_$direction<$type> ${port.key}{"${port.key}"};');
      }
    }
    if (twoStatePorts) {
      final unknownIsError =
          options.unknownOutputs == SystemCUnknownOutputPolicy.error
              ? 'true'
              : 'has_reset';
      source
        ..writeln('  bool has_reset=false;')
        ..writeln('  template<int W> bool prepare_output( '
            'sc_dt::sc_lv<W>& value, const char* port) {')
        ..writeln('    if(value.is_01()) return true;')
        ..writeln('    if($unknownIsError) {')
        ..writeln('      SC_REPORT_ERROR("CSR_UNKNOWN_OUTPUT", port);')
        ..writeln('      return false;')
        ..writeln('    }')
        ..writeln('    value=sc_dt::sc_lv<W>(0); return true;')
        ..writeln('  }');
    }
    void writeOutput(String port, int width, String value) {
      if (twoStatePorts) {
        final converted = width == 1
            ? 'visible[0].to_bool()'
            : '${portType(width)}'
                '(visible.to_string(sc_dt::SC_BIN,true).c_str())';
        source
          ..writeln('    { sc_dt::sc_lv<$width> visible( '
              '($value).to_string().c_str());')
          ..writeln('      if(prepare_output(visible,"$port"))'
              ' $port.write($converted); }');
      } else {
        source.writeln(width == 1
            ? '    $port.write(sc_dt::sc_logic(($value)[0]));'
            : '    $port.write(sc_dt::sc_lv<$width>'
                ' (($value).to_string().c_str()));');
      }
    }

    source
      ..writeln('  struct field { int start, width, access; word fallback;'
          ' std::vector<word> legal; };')
      ..writeln('  struct reg { int width; bool readonly; word reset, value;'
          ' std::vector<field> fields; };')
      ..writeln('  struct target { size_t index; int offset; };')
      ..writeln('  std::vector<reg> registers;')
      ..writeln('  std::map<unsigned long long, target> reads, writes;')
      ..writeln('  std::map<unsigned long long, size_t> addresses;')
      ..writeln('  sc_core::sc_event changed;')
      ..writeln('  sc_dt::sc_logic old_clk ='
          ' sc_dt::SC_LOGIC_${twoStatePorts ? '0' : 'X'};')
      ..writeln('  sc_dt::sc_logic old_reset ='
          ' sc_dt::SC_LOGIC_${twoStatePorts ? '0' : 'X'};')
      ..writeln('  static bool known(sc_dt::sc_logic v) {'
          ' return v == sc_dt::SC_LOGIC_0 || v == sc_dt::SC_LOGIC_1; }')
      ..writeln('  static word slice(const word& value, int start, int count) {'
          ' word result(0); for(int i=0;i<count;++i) result[i]=value[start+i];'
          ' return result; }')
      ..writeln('  word peek(unsigned long long address) const {'
          ' return registers.at(addresses.at(address)).value; }')
      ..writeln('  void poke(unsigned long long address, const word& value) {'
          ' registers.at(addresses.at(address)).value=value;'
          ' changed.notify(sc_core::SC_ZERO_TIME); }')
      ..writeln('  word transform(size_t index, const word& data, int offset,'
          ' int count, bool backdoor) {')
      ..writeln('    const auto& r=registers[index];')
      ..writeln('    if(r.readonly) return r.value & r.value;')
      ..writeln('    word proposed=r.value, result=r.value;')
      ..writeln('    for(int i=0;i<count;++i) proposed[offset+i]=data[i];')
      ..writeln('    if(r.fields.empty()) return proposed & proposed;')
      ..writeln('    for(const auto& f:r.fields) {')
      ..writeln('      word incoming=slice(proposed,f.start,f.width);')
      ..writeln('      word original=slice(r.value,f.start,f.width),'
          ' updated=original;')
      ..writeln('      switch(f.access) {')
      ..writeln('        case ${CsrFieldAccess.readWrite.index}:'
          ' updated=incoming; break;')
      ..writeln('        case ${CsrFieldAccess.writeOnesClear.index}:'
          ' updated=backdoor ? original|incoming : original&~incoming; break;')
      ..writeln('        case ${CsrFieldAccess.readWriteLegal.index}: {')
      ..writeln('          updated=f.fallback;')
      ..writeln('          for(const auto& legal:f.legal)'
          ' if(incoming==legal) { updated=incoming; break; }')
      ..writeln('          break; }')
      ..writeln('        default: break;')
      ..writeln('      }')
      ..writeln('      for(int i=0;i<f.width;++i)'
          ' if(f.start+i>=offset && f.start+i<offset+count)'
          ' result[f.start+i]=updated[i];')
      ..writeln('    }')
      ..writeln('    return result & result;')
      ..writeln('  }')
      ..writeln('  void tick() {')
      ..writeln('    auto c=${scalar('clk')}, r=${scalar('reset')};')
      ..writeln('    bool invalid=clk.event() && (!known(old_clk)||!known(c));')
      ..writeln('    bool edge=clk.event() && old_clk==sc_dt::SC_LOGIC_0'
          ' && c==sc_dt::SC_LOGIC_1;');
    if (asyncReset) {
      source
        ..writeln('    invalid=invalid || (reset.event() &&'
            ' (!known(old_reset)||!known(r)));')
        ..writeln(
            '    edge=edge || (reset.event() && old_reset==sc_dt::SC_LOGIC_0'
            ' && r==sc_dt::SC_LOGIC_1);');
    }
    source
      ..writeln('    old_clk=c; old_reset=r;')
      ..writeln('    if(invalid || (edge && !known(r))) {')
      ..writeln(
          '      for(auto& reg:registers) reg.value=word(sc_dt::SC_LOGIC_X);')
      ..writeln('    } else if(edge && r==sc_dt::SC_LOGIC_1) {')
      ..writeln(twoStatePorts ? '      has_reset=true;' : '')
      ..writeln('      for(auto& reg:registers) reg.value=reg.reset;')
      ..writeln('    } else if(edge) {')
      ..writeln('      std::vector<size_t> touched;');
    final writePort = frontWrite;
    if (writePort != null) {
      final writeData = data('frontWrite_data', writePort.dataWidth);
      final writeAddress = address('frontWrite_addr', writePort.addressWidth);
      final writeValid = valid('frontWrite_addr', writePort.addressWidth);
      final enable = scalar('frontWrite_en');
      source
        ..writeln('      if($enable!=sc_dt::SC_LOGIC_0) {')
        ..writeln('        if($writeValid) {')
        ..writeln('          auto it=writes.find($writeAddress);')
        ..writeln('          if(it!=writes.end()) { auto t=it->second;')
        ..writeln('            auto& reg=registers[t.index];'
            ' touched.push_back(t.index);')
        ..writeln('            reg.value=known($enable) ?'
            ' transform(t.index,$writeData,t.offset,'
            ' std::min(${writePort.dataWidth},reg.width-t.offset),false)'
            ' : word(sc_dt::SC_LOGIC_X);')
        ..writeln('          }')
        ..writeln('        } else {')
        ..writeln('          for(const auto& it:writes) {')
        ..writeln('            registers[it.second.index].value='
            ' word(sc_dt::SC_LOGIC_X);')
        ..writeln('            touched.push_back(it.second.index); }')
        ..writeln('        }')
        ..writeln('      }');
    }
    for (final exposed in hardware.entries) {
      if (!exposed.value.hasWrite) {
        continue;
      }
      final register = registers[exposed.key]!;
      final index = indices[register]!;
      final enable = scalar(exposed.value.writeEnable!);
      final wordData = data(exposed.value.writeData!, register.config.width);
      source
        ..writeln('      if($enable!=sc_dt::SC_LOGIC_0 &&'
            ' std::find(touched.begin(),touched.end(),$index)==touched.end())')
        ..writeln('        registers[$index].value=known($enable) ?'
            ' transform($index,$wordData,0,${register.config.width},true)'
            ' : word(sc_dt::SC_LOGIC_X);');
    }
    source
      ..writeln('    }')
      ..writeln('    changed.notify(sc_core::SC_ZERO_TIME);')
      ..writeln('  }')
      ..writeln('  void drive() {');
    final readPort = frontRead;
    if (readPort != null) {
      final readValid = valid('frontRead_addr', readPort.addressWidth);
      final readAddress = address('frontRead_addr', readPort.addressWidth);
      source
        ..writeln('    word value(0);')
        ..writeln('    if(!($readValid)) value=word(sc_dt::SC_LOGIC_X);')
        ..writeln('    else { auto it=reads.find($readAddress);'
            ' if(it!=reads.end()) { auto t=it->second;')
        ..writeln('      value=slice(registers[t.index].value,t.offset,'
            ' std::min(${readPort.dataWidth},'
            ' registers[t.index].width-t.offset)); } }');
      writeOutput('frontRead_data', readPort.dataWidth, 'value & value');
    }
    for (final exposed in hardware.entries) {
      if (!exposed.value.hasRead) {
        continue;
      }
      final register = registers[exposed.key]!;
      final index = indices[register]!;
      final output = exposed.value.read!;
      source.writeln('    { word value=registers[$index].value;');
      if (writePort != null && register.config.isFrontdoorWritable) {
        final writeValid = valid('frontWrite_addr', writePort.addressWidth);
        final writeAddress = address('frontWrite_addr', writePort.addressWidth);
        final writeData = data('frontWrite_data', writePort.dataWidth);
        source.writeln('      auto enable=${scalar('frontWrite_en')} &'
            ' (($writeValid) ? sc_dt::sc_logic( '
            '($writeAddress)>=${register.blockBase}ULL &&'
            ' ($writeAddress)<'
            '${register.blockBase + register.blockSize}ULL)'
            ' : sc_dt::SC_LOGIC_X);');
        for (final field in register.config.fields
            .where((field) => field.access == CsrFieldAccess.writeOnly)) {
          source
            ..writeln('      if(enable!=sc_dt::SC_LOGIC_0 && (')
            ..writeln('        (!known(enable) &&'
                ' (${register.config.width > writePort.dataWidth}'
                ' || !($writeValid))) ||')
            ..writeln('        (enable==sc_dt::SC_LOGIC_1 && !($writeValid) &&'
                ' ${register.config.width <= writePort.dataWidth})))')
            ..writeln('        for(int i=${field.start};'
                ' i<${field.start + field.width};++i)'
                ' value[i]=sc_dt::SC_LOGIC_X;');
        }
        source
          ..writeln(
              '      if($writeValid) { auto it=writes.find($writeAddress);')
          ..writeln(
              '        if(it!=writes.end() && it->second.index==$index) {')
          ..writeln('          int offset=it->second.offset,'
              ' count=std::min(${writePort.dataWidth},'
              '${register.config.width}-offset);')
          ..writeln('          word data=$writeData;');
        for (final field in register.config.fields
            .where((field) => field.access == CsrFieldAccess.writeOnly)) {
          source
            ..writeln('          if(${field.start}<offset+count &&'
                ' ${field.start + field.width}>offset &&'
                ' enable!=sc_dt::SC_LOGIC_0) {')
            ..writeln('            for(int i=${field.start};'
                ' i<${field.start + field.width};++i)')
            ..writeln('              value[i]=!known(enable)'
                ' ? sc_dt::SC_LOGIC_X : i>=offset && i<offset+count'
                ' ? sc_dt::sc_logic(data[i-offset]) : sc_dt::SC_LOGIC_0;')
            ..writeln('          }');
        }
        source
          ..writeln('        }')
          ..writeln('      }');
      }
      for (final field in register.config.fields
          .where((field) => field.access == CsrFieldAccess.writeOnly)) {
        source.writeln(
            '      if(!slice(value,${field.start},${field.width}).is_01())'
            ' for(int i=${field.start};i<${field.start + field.width};++i)'
            ' value[i]=sc_dt::SC_LOGIC_X;');
      }
      writeOutput(output, register.config.width, 'value');
      source.writeln('    }');
    }
    source
      ..writeln('  }')
      ..writeln('  static constexpr const char* register_metadata=R"ROHD_CSR(');
    for (final entry in registers.entries) {
      final register = entry.value.config;
      source.writeln('R ${entry.key} ${register.width} '
          '${register.access == CsrAccess.readOnly ? 1 : 0} '
          '${number(register.resetValue, register.width)} '
          '${register.fields.length}');
      for (final field in register.fields) {
        final fallback = entry.value.illegalValues[field];
        final legal = field.legalValues
            .map((value) => number(value, field.width))
            .join(' ');
        source.writeln('${field.start} ${field.width} ${field.access.index} '
            '${fallback == null ? number(0, field.width) : bits(fallback)} '
            '${field.legalValues.length} $legal');
      }
    }
    for (final (name, index) in [('D', reads), ('W', writes)]) {
      for (final target in index.entries) {
        source.writeln('$name ${target.key} '
            '${indices[target.value.$1]} ${target.value.$2}');
      }
    }
    source
      ..writeln(')ROHD_CSR";')
      ..writeln('  SC_CTOR($className) {')
      ..writeln('    std::istringstream metadata(register_metadata);')
      ..writeln('    char kind;')
      ..writeln('    while(metadata >> kind) {')
      ..writeln('      unsigned long long address; metadata >> address;')
      ..writeln("      if(kind=='R') {")
      ..writeln('        reg r; size_t count; std::string value;')
      ..writeln('        metadata >> r.width >> r.readonly >> value >> count;')
      ..writeln('        r.reset=word(value.c_str());')
      ..writeln('        r.value=word(sc_dt::SC_LOGIC_X);')
      ..writeln('        for(size_t i=0;i<count;++i) {')
      ..writeln('          field f; size_t legal;')
      ..writeln('          metadata >> f.start >> f.width >> f.access'
          ' >> value >> legal;')
      ..writeln('          f.fallback=word(value.c_str());')
      ..writeln('          for(size_t j=0;j<legal;++j) { metadata >> value;')
      ..writeln('            f.legal.push_back(word(value.c_str())); }')
      ..writeln('          r.fields.push_back(std::move(f));')
      ..writeln('        }')
      ..writeln('        addresses.emplace(address,registers.size());')
      ..writeln('        registers.push_back(std::move(r));')
      ..writeln('      } else { target t; metadata >> t.index >> t.offset;')
      ..writeln("        (kind=='D' ? reads : writes).emplace(address,t); }")
      ..writeln('    }')
      ..writeln('    SC_METHOD(tick); sensitive << clk'
          '${asyncReset ? ' << reset' : ''}; dont_initialize();')
      ..writeln('    SC_METHOD(drive); sensitive << changed');
    if (readPort != null) {
      source.writeln('      << frontRead_addr');
    }
    if (writePort != null) {
      source.writeln(
          '      << frontWrite_en << frontWrite_addr << frontWrite_data');
    }
    source
      ..writeln('      ;')
      ..writeln('  }')
      ..writeln('};');
    return source.toString();
  }
}
