// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_model_systemc.dart
// SystemC export for CSR software models.
//
// 2026 October 16
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/behavioral/systemc_storage.dart';

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
    if (registers.keys.any((address) => address.isNegative)) {
      throw UnsupportedError(
          'Behavioral SystemC CSR addresses must be nonnegative.');
    }
    final addressWidth = max(
        max(frontRead?.addressWidth ?? 1, frontWrite?.addressWidth ?? 1) + 1,
        registers.values.fold<int>(
            1,
            (width, entry) =>
                max(width, (entry.blockBase + entry.blockSize).bitLength)));
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
            ? 'address_type($name.read())'
            : 'address_type($name.read().to_bool())'
        : 'address_type($name.read())';
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
      ..writeln(systemCSparseStorageDefinition)
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using word = sc_dt::sc_lv<$width>;')
      ..writeln('  using address_type = sc_dt::sc_biguint<$addressWidth>;');
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
    void writeOutput(String port, int width, String value,
        {String? diagnosticName}) {
      if (twoStatePorts) {
        final converted = width == 1
            ? 'visible[0].to_bool()'
            : '${portType(width)}'
                '(visible.to_string(sc_dt::SC_BIN,true).c_str())';
        source
          ..writeln('    { sc_dt::sc_lv<$width> visible( '
              '($value).to_string().c_str());')
          ..writeln('      if(prepare_output(visible,'
              '${diagnosticName ?? '"$port"'}))'
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
      ..writeln('  struct reg { int width; bool readonly; word reset;'
          ' address_type block_base, block_size; bool front_writable;'
          ' std::vector<field> fields; };')
      ..writeln('  struct target { size_t index; int offset; };')
      ..writeln('  std::vector<reg> registers;')
      ..writeln('  using storage = RohdHclSystemCSparseStorage<$width>;')
      ..writeln('  storage values;')
      ..writeln('  std::map<address_type, target> reads, writes;')
      ..writeln('  std::map<address_type, size_t> addresses;')
      ..writeln('  sc_core::sc_event changed;');
    final hardwareWidths = hardware.keys
        .map((address) => registers[address]!.config.width)
        .toSet();
    for (final hardwareWidth in hardwareWidths) {
      source
        ..writeln('  struct hardware_$hardwareWidth { size_t index;'
            ' sc_core::sc_in<${portType(1)}>* enable;'
            ' sc_core::sc_in<${portType(hardwareWidth)}>* data;'
            ' sc_core::sc_out<${portType(hardwareWidth)}>* output; };')
        ..writeln('  std::vector<hardware_$hardwareWidth>'
            ' hardware_ports_$hardwareWidth;');
    }
    source
      ..writeln('  sc_dt::sc_logic old_clk ='
          ' sc_dt::SC_LOGIC_${twoStatePorts ? '0' : 'X'};')
      ..writeln('  sc_dt::sc_logic old_reset ='
          ' sc_dt::SC_LOGIC_${twoStatePorts ? '0' : 'X'};')
      ..writeln('  class image {')
      ..writeln('    friend struct $className;')
      ..writeln('    storage::image values; sc_dt::sc_logic clk, reset;'
          ' bool reset_seen;')
      ..writeln('    image(storage::image v, sc_dt::sc_logic c,'
          ' sc_dt::sc_logic r, bool seen)'
          ' : values(std::move(v)),clk(c),reset(r),reset_seen(seen) {}')
      ..writeln('  };')
      ..writeln('  image snapshot() const { return image(values.snapshot(),'
          ' old_clk,old_reset,${twoStatePorts ? 'has_reset' : 'false'}); }')
      ..writeln('  void restore(const image& saved) {')
      ..writeln('    values.restore(saved.values); old_clk=saved.clk;'
          ' old_reset=saved.reset;')
      ..writeln(twoStatePorts ? '    has_reset=saved.reset_seen;' : '')
      ..writeln('    changed.notify(sc_core::SC_ZERO_TIME);')
      ..writeln('  }')
      ..writeln('  static bool known(sc_dt::sc_logic v) {'
          ' return v == sc_dt::SC_LOGIC_0 || v == sc_dt::SC_LOGIC_1; }')
      ..writeln('  static word slice(const word& value, int start, int count) {'
          ' word result(0); for(int i=0;i<count;++i) result[i]=value[start+i];'
          ' return result; }')
      ..writeln('  word get_value(size_t index) const {'
          ' return values.read(std::to_string(index),'
          ' word(sc_dt::SC_LOGIC_X)); }')
      ..writeln('  void set_value(size_t index, const word& value) {'
          ' values.write(std::to_string(index),value); }')
      ..writeln('  word peek(const address_type& address) const {'
          ' return get_value(addresses.at(address)); }')
      ..writeln('  void poke(const address_type& address, const word& value) {'
          ' set_value(addresses.at(address),value);'
          ' changed.notify(sc_core::SC_ZERO_TIME); }')
      ..writeln('  word transform(size_t index, const word& data, int offset,'
          ' int count, bool backdoor) {')
      ..writeln('    const auto& r=registers[index];')
      ..writeln('    word current=get_value(index);')
      ..writeln('    if(r.readonly && !backdoor) return current & current;')
      ..writeln('    word proposed=current, result=current;')
      ..writeln('    for(int i=0;i<count;++i) proposed[offset+i]=data[i];')
      ..writeln('    if(r.fields.empty()) return proposed & proposed;')
      ..writeln('    for(const auto& f:r.fields) {')
      ..writeln('      word incoming=slice(proposed,f.start,f.width);')
      ..writeln('      word original=slice(current,f.start,f.width),'
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
      ..writeln('      for(size_t i=0;i<registers.size();++i)'
          ' set_value(i,word(sc_dt::SC_LOGIC_X));')
      ..writeln('    } else if(edge && r==sc_dt::SC_LOGIC_1) {')
      ..writeln(twoStatePorts ? '      has_reset=true;' : '')
      ..writeln('      for(size_t i=0;i<registers.size();++i)'
          ' set_value(i,registers[i].reset);')
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
        ..writeln('            set_value(t.index,known($enable) ?'
            ' transform(t.index,$writeData,t.offset,'
            ' std::min(${writePort.dataWidth},reg.width-t.offset),false)'
            ' : word(sc_dt::SC_LOGIC_X));')
        ..writeln('          }')
        ..writeln('        } else {')
        ..writeln('          for(const auto& it:writes) {')
        ..writeln('            set_value(it.second.index,'
            ' word(sc_dt::SC_LOGIC_X));')
        ..writeln('            touched.push_back(it.second.index); }')
        ..writeln('        }')
        ..writeln('      }');
    }
    for (final hardwareWidth in hardwareWidths) {
      final enable = scalar('(*port.enable)');
      final wordData = data('(*port.data)', hardwareWidth);
      source
        ..writeln('      for(const auto& port:hardware_ports_$hardwareWidth) {')
        ..writeln('        if(!port.enable) continue;')
        ..writeln('        auto enable=$enable;')
        ..writeln('        if(enable!=sc_dt::SC_LOGIC_0 &&'
            ' std::find(touched.begin(),touched.end(),port.index) '
            '==touched.end())')
        ..writeln('          set_value(port.index,known(enable) ?'
            ' transform(port.index,$wordData,0,$hardwareWidth,true)'
            ' : word(sc_dt::SC_LOGIC_X));')
        ..writeln('      }');
    }
    source
      ..writeln('    }')
      ..writeln('    changed.notify(sc_core::SC_ZERO_TIME);')
      ..writeln('  }')
      ..writeln('  word hardware_value(size_t index) {')
      ..writeln('    const auto& reg=registers[index];')
      ..writeln('    word value=get_value(index);');
    if (writePort != null) {
      final writeValid = valid('frontWrite_addr', writePort.addressWidth);
      final writeAddress = address('frontWrite_addr', writePort.addressWidth);
      final writeData = data('frontWrite_data', writePort.dataWidth);
      final writeOnly = CsrFieldAccess.writeOnly.index;
      source
        ..writeln('    if(reg.front_writable && std::any_of('
            ' reg.fields.begin(),reg.fields.end(),'
            ' [](const field& f) { return f.access==$writeOnly; })) {')
        ..writeln('      auto enable=${scalar('frontWrite_en')} &'
            ' (($writeValid) ? sc_dt::sc_logic( '
            '($writeAddress)>=reg.block_base &&'
            ' ($writeAddress)<reg.block_base+reg.block_size)'
            ' : sc_dt::SC_LOGIC_X);')
        ..writeln('      bool address_known=$writeValid;')
        ..writeln('      auto it=address_known ? writes.find($writeAddress)'
            ' : writes.end();')
        ..writeln('      int offset=it==writes.end() ? 0 : it->second.offset,'
            ' count=std::min(${writePort.dataWidth},reg.width-offset);')
        ..writeln('      word data=$writeData;')
        ..writeln('      for(const auto& f:reg.fields) {')
        ..writeln('        if(f.access!=$writeOnly) continue;')
        ..writeln('        bool overlaps=it!=writes.end() &&'
            ' it->second.index==index && f.start<offset+count &&'
            ' f.start+f.width>offset;')
        ..writeln('        sc_dt::sc_logic selected=address_known'
            ' ? sc_dt::sc_logic(overlaps) : sc_dt::SC_LOGIC_X;')
        ..writeln('        sc_dt::sc_logic select=enable & selected;')
        ..writeln('        if(select==sc_dt::SC_LOGIC_0) continue;')
        ..writeln('        for(int i=f.start;i<f.start+f.width;++i) {')
        ..writeln('          sc_dt::sc_logic written=sc_dt::SC_LOGIC_0;')
        ..writeln('          if(!address_known &&'
            ' reg.width>${writePort.dataWidth}) written=sc_dt::SC_LOGIC_X;')
        ..writeln('          else if((overlaps || !address_known) &&'
            ' i>=offset && i<offset+count)')
        ..writeln('            written=sc_dt::sc_logic(data[i-offset]) &'
            ' sc_dt::sc_logic(data[i-offset]);')
        ..writeln('          if(select==sc_dt::SC_LOGIC_1 ||'
            ' sc_dt::sc_logic(value[i])==written) value[i]=written;')
        ..writeln('          else value[i]=sc_dt::SC_LOGIC_X;')
        ..writeln('        }')
        ..writeln('      }')
        ..writeln('    }');
    }
    source
      ..writeln('    return value;')
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
        ..writeln('      value=slice(get_value(t.index),t.offset,'
            ' std::min(${readPort.dataWidth},'
            ' registers[t.index].width-t.offset)); } }');
      writeOutput('frontRead_data', readPort.dataWidth, 'value & value');
    }
    for (final hardwareWidth in hardwareWidths) {
      source
        ..writeln('    for(const auto& port:hardware_ports_$hardwareWidth) {')
        ..writeln('      if(!port.output) continue;')
        ..writeln('      word value=hardware_value(port.index);');
      writeOutput('(*port.output)', hardwareWidth, 'value',
          diagnosticName: 'port.output->name()');
      source.writeln('    }');
    }
    source
      ..writeln('  }')
      ..writeln('  static constexpr const char* register_metadata=R"ROHD_CSR(');
    for (final entry in registers.entries) {
      final description = entry.value;
      final register = description.config;
      source.writeln('R ${entry.key} ${register.width} '
          '${register.access == CsrAccess.readOnly ? 1 : 0} '
          '${number(register.resetValue, register.width)} '
          '${register.fields.length} ${description.blockBase} '
          '${description.blockSize} ${register.isFrontdoorWritable ? 1 : 0}');
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
      ..writeln('      std::string address_text; metadata >> address_text;')
      ..writeln('      address_type address(address_text.c_str());')
      ..writeln("      if(kind=='R') {")
      ..writeln('        reg r; size_t count; std::string value,base,size;')
      ..writeln('        metadata >> r.width >> r.readonly >> value >> count'
          ' >> base >> size >> r.front_writable;')
      ..writeln('        r.block_base=base.c_str(); r.block_size=size.c_str();')
      ..writeln('        r.reset=word(value.c_str());')
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
      ..writeln('    }');
    for (final hardwareWidth in hardwareWidths) {
      source.writeln('    hardware_ports_$hardwareWidth = {');
      for (final exposed in hardware.entries.where(
          (entry) => registers[entry.key]!.config.width == hardwareWidth)) {
        final index = indices[registers[exposed.key]!]!;
        String pointer(String? port) => port == null ? 'nullptr' : '&$port';
        source.writeln('      {$index,${pointer(exposed.value.writeEnable)},'
            '${pointer(exposed.value.writeData)},'
            '${pointer(exposed.value.read)}},');
      }
      source.writeln('    };');
    }
    source
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
