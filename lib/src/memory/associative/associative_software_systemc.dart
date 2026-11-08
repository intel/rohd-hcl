// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_software_systemc.dart
// SystemC export for clock-stepped associative software models.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/behavioral/systemc_storage.dart';

/// Portable port geometry for a clock-stepped associative software model.
class AssociativeSoftwareDescription implements BehavioralModelDescription {
  /// Frozen associative-memory request.
  final AssociativeMemoryRequest configuration;

  /// Creates a description of a model using [configuration].
  AssociativeSoftwareDescription(this.configuration);

  @override
  String get kind => 'associative';

  @override
  Map<String, int> get inputPorts {
    if (configuration.matchMode == AssociativeMatchMode.contextQualified) {
      throw UnsupportedError('Context width is defined by the custom matcher.');
    }
    return Map.unmodifiable({
      'clk': 1,
      'reset': 1,
      for (var i = 0; i < configuration.updatePortCount; i++) ...{
        'update_${i}_en': 1,
        'update_${i}_index': configuration.indexWidth,
        'update_${i}_key': configuration.keyWidth,
        'update_${i}_valid': 1,
      },
      for (var i = 0; i < configuration.lookupPortCount; i++) ...{
        'lookup_${i}_en': 1,
        'lookup_${i}_key': configuration.keyWidth,
        if (configuration.matchMode == AssociativeMatchMode.masked)
          'lookup_${i}_mask': configuration.keyWidth,
      },
    });
  }

  @override
  Map<String, int> get outputPorts => Map.unmodifiable({
        for (var i = 0; i < configuration.lookupPortCount; i++) ...{
          'lookup_${i}_valid': 1,
          'lookup_${i}_hit': 1,
          'lookup_${i}_index': configuration.indexWidth,
          'lookup_${i}_matches': configuration.entryCount,
        }
      });

  /// Generates the supported four-state, synchronous SystemC implementation.
  ///
  /// Requests are sampled at rising clock edges, including zero-latency
  /// lookups. Unknown enables and indices are reported as errors. Custom
  /// matching, asynchronous reset, duplicate-key enforcement, and two-state
  /// boundaries are not implemented by this exporter and are rejected.
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(className)) {
      throw ArgumentError.value(
          className, 'className', 'Invalid C++ identifier.');
    }
    final c = configuration;
    if (options.portType != SystemCModelPortType.fourState ||
        c.matchMode == AssociativeMatchMode.contextQualified ||
        c.duplicateKeyPolicy == AssociativeDuplicateKeyPolicy.disallow ||
        c.requiredResetTiming == AssociativeMemoryResetTiming.asynchronous ||
        c.lookupUpdatePolicy == AssociativeLookupUpdatePolicy.undefined) {
      throw UnsupportedError('This associative SystemC configuration is not '
          'implemented by the clock-stepped exporter.');
    }
    final output = StringBuffer()
      ..writeln('#pragma once')
      ..writeln('#include <systemc>')
      ..writeln('#include <array>')
      ..writeln('#include <cstdint>')
      ..writeln('#include <vector>')
      ..writeln(systemCSparseStorageDefinition)
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit = sc_dt::sc_logic;')
      ..writeln('  using key = sc_dt::sc_lv<${c.keyWidth}>;')
      ..writeln('  using index = sc_dt::sc_lv<${c.indexWidth}>;')
      ..writeln('  using matches = sc_dt::sc_lv<${c.entryCount}>;');
    for (final (ports, direction) in [
      (inputPorts, 'in'),
      (outputPorts, 'out')
    ]) {
      for (final port in ports.entries) {
        final scalar = port.key == 'clk' ||
            port.key == 'reset' ||
            port.key.endsWith('_en') ||
            port.key.endsWith('_hit') ||
            port.key.endsWith('_valid');
        final type = scalar ? 'bit' : 'sc_dt::sc_lv<${port.value}>';
        output.writeln('  sc_core::sc_$direction<$type> '
            '${port.key}{"${port.key}"};');
      }
    }
    output.writeln('''
  struct entry { key value; bit valid; };
  struct update { std::uint64_t due; int port; unsigned index_value;
                  key value; bit valid; };
  struct result { bit hit; index selected; matches vector; };
  struct lookup { std::uint64_t due; int port; result value; };
  using entry_storage = RohdHclSystemCSparseStorage<${c.keyWidth + 1}>;
  struct state {
    std::uint64_t cycle=0;
    entry_storage entries;
    std::vector<update> updates;
    std::vector<lookup> lookups;
    std::array<result, ${c.lookupPortCount}> visible;
    std::array<bool, ${c.lookupPortCount}> valid{};
    bit old_clk=sc_dt::SC_LOGIC_0;
  };
  class image {
    friend struct $className;
    state value;
    explicit image(const state& s) : value(s) {}
  };
  state data;
  sc_core::sc_event changed;
  image snapshot() const { return image(data); }
  void restore(const image& saved) {
    data=saved.value;
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  static bool known(bit x) {
    return x==sc_dt::SC_LOGIC_0 || x==sc_dt::SC_LOGIC_1;
  }
  static bit normalize(bit x) {
    return x==sc_dt::SC_LOGIC_Z ? bit(sc_dt::SC_LOGIC_X) : x;
  }
  static key normalize_key(key value) {
    for(int i=0;i<${c.keyWidth};++i) value[i]=normalize(value[i]);
    return value;
  }
  static bit equal_key(const key& left, const key& right) {
    bit result=sc_dt::SC_LOGIC_1;
    for(int i=0;i<${c.keyWidth};++i) {
      bit a=left[i], b=right[i];
      bit same=known(a) && known(b) ? bit(a==b) : bit(sc_dt::SC_LOGIC_X);
      result=result & same;
    }
    return result;
  }
  static entry read_entry(const entry_storage& entries, int i) {
    auto value=entries.read(std::to_string(i),typename entry_storage::word(0));
    entry result{key(0),bit(value[${c.keyWidth}])};
    for(int bit=0;bit<${c.keyWidth};++bit) result.value[bit]=value[bit];
    return result;
  }
  static void write_entry(entry_storage& entries, int i, const entry& value) {
    typename entry_storage::word packed(0);
    for(int bit=0;bit<${c.keyWidth};++bit) packed[bit]=value.value[bit];
    packed[${c.keyWidth}]=value.valid;
    entries.write(std::to_string(i),packed);
  }
  static index select_index(bit control, const index& yes, const index& no) {
    if(control==sc_dt::SC_LOGIC_1) return yes;
    if(control==sc_dt::SC_LOGIC_0) return no;
    index result;
    for(int i=0;i<${c.indexWidth};++i)
      result[i]=(yes[i]==no[i]) ? yes[i] : bit(sc_dt::SC_LOGIC_X);
    return result;
  }
  result find(const key& query, const key& mask,
              const entry_storage& entries) const {
    result out{sc_dt::SC_LOGIC_0, index(0), matches(0)};
    bit found=sc_dt::SC_LOGIC_0;
    index selected(0);
    for(int i=0;i<${c.entryCount};++i) {
      auto stored=read_entry(entries,i);
      bit equal=${c.matchMode == AssociativeMatchMode.masked ? 'equal_key(query & mask, stored.value & mask)' : 'equal_key(query, stored.value)'};
      bit match=stored.valid & equal;
      out.vector[i]=match;
      bit preferred=selected.is_01()
          ? bit(i ${c.matchSelection == AssociativeMatchSelection.lowestIndex ? '<' : '>'} selected.to_uint64())
          : bit(sc_dt::SC_LOGIC_X);
      bit choose=match & (~found | preferred);
      selected=select_index(choose,index(i),selected);
      found=found | match;
    }
    out.hit=found;
    out.selected=select_index(found,selected,index(0));
    return out;
  }
  void clear_entries() {
    data.entries.clear();
    data.updates.clear(); data.lookups.clear(); data.valid.fill(false);
  }
  void drive() {
''');
    for (var i = 0; i < c.lookupPortCount; i++) {
      output
        ..writeln('    lookup_${i}_valid.write(bit(data.valid[$i]));')
        ..writeln('    lookup_${i}_hit.write(data.visible[$i].hit);')
        ..writeln('    lookup_${i}_index.write(data.visible[$i].selected);')
        ..writeln('    lookup_${i}_matches.write(data.visible[$i].vector);');
    }
    output.writeln('''
  }
  void tick() {
    bit clock=clk.read();
    if(!known(clock) || !known(data.old_clk)) {
      SC_REPORT_ERROR("ASSOCIATIVE_CLOCK", "Unknown clock transition");
      data.old_clk=clock; return;
    }
    bool edge=data.old_clk==sc_dt::SC_LOGIC_0 && clock==sc_dt::SC_LOGIC_1;
    data.old_clk=clock;
    if(!edge) return;
    bit rst=reset.read();
    if(!known(rst)) {
      SC_REPORT_ERROR("ASSOCIATIVE_RESET", "Unknown reset"); return;
    }
    if(rst==sc_dt::SC_LOGIC_1) {
''');
    if (c.requiredResetBehavior == AssociativeMemoryResetBehavior.none) {
      output.writeln('      SC_REPORT_ERROR("ASSOCIATIVE_RESET", '
          '"Reset behavior is not configured"); return;');
    } else {
      output.writeln(
          '      clear_entries(); changed.notify(sc_core::SC_ZERO_TIME);'
          ' return;');
    }
    output.writeln('''
    }
    std::vector<update> incoming;
''');
    for (var i = 0; i < c.updatePortCount; i++) {
      output.writeln('''
    if(!known(update_${i}_en.read())) {
      SC_REPORT_ERROR("ASSOCIATIVE_UPDATE", "Unknown update enable"); return;
    }
    if(update_${i}_en.read()==sc_dt::SC_LOGIC_1) {
      if(!update_${i}_index.read().is_01() ||
          sc_dt::sc_biguint<${c.indexWidth}>(update_${i}_index.read())>=${c.entryCount}) {
        SC_REPORT_ERROR("ASSOCIATIVE_UPDATE", "Invalid update index"); return;
      }
      incoming.push_back({data.cycle+${c.updateLatency}, $i,
          static_cast<unsigned>(update_${i}_index.read().to_uint64()),
          normalize_key(update_${i}_key.read()), normalize(update_${i}_valid.read())});
    }
''');
    }
    for (var i = 0; i < c.lookupPortCount; i++) {
      output.writeln('''
    if(!known(lookup_${i}_en.read())) {
      SC_REPORT_ERROR("ASSOCIATIVE_LOOKUP", "Unknown lookup enable"); return;
    }
''');
    }
    if (c.updateCollisionPolicy == AssociativeUpdateCollisionPolicy.disallow) {
      output.writeln('''
    for(std::size_t i=0;i<incoming.size();++i)
      for(std::size_t j=i+1;j<incoming.size();++j)
        if(incoming[i].index_value==incoming[j].index_value) {
          SC_REPORT_ERROR("ASSOCIATIVE_UPDATE", "Update collision"); return;
        }
''');
    }
    output.writeln('''
    auto next=data.entries;
    std::vector<update> all=data.updates;
    all.insert(all.end(),incoming.begin(),incoming.end());
    for(int target=0;target<${c.entryCount};++target) {
      const update* chosen=nullptr;
      for(const auto& item:all) {
        if(item.due!=data.cycle || item.index_value!=static_cast<unsigned>(target))
          continue;
        if(chosen==nullptr || item.port ${c.updateCollisionPolicy == AssociativeUpdateCollisionPolicy.lowestPortWins ? '<' : '>'} chosen->port)
          chosen=&item;
      }
      if(chosen!=nullptr) {
        write_entry(next,target,{chosen->value,chosen->valid});
      }
    }
    auto visible_entries=${c.lookupUpdatePolicy == AssociativeLookupUpdatePolicy.lookupBeforeUpdate ? 'data.entries' : 'next'};
    std::vector<lookup> accepted;
''');
    for (var i = 0; i < c.lookupPortCount; i++) {
      final mask = c.matchMode == AssociativeMatchMode.masked
          ? 'lookup_${i}_mask.read()'
          : 'key(0)';
      output.writeln('''
    if(lookup_${i}_en.read()==sc_dt::SC_LOGIC_1)
      accepted.push_back({data.cycle+${c.lookupLatency}, $i,
          find(lookup_${i}_key.read(), $mask, visible_entries)});
''');
    }
    output.writeln('''
    data.entries=next;
    data.updates.clear();
    for(const auto& item:all)
      if(item.due!=data.cycle) data.updates.push_back(item);
    data.lookups.insert(data.lookups.end(),accepted.begin(),accepted.end());
    data.valid.fill(false);
    std::vector<lookup> pending;
    for(const auto& item:data.lookups) {
      if(item.due==data.cycle) {
        data.visible[item.port]=item.value; data.valid[item.port]=true;
      } else pending.push_back(item);
    }
    data.lookups=std::move(pending);
    ++data.cycle;
    changed.notify(sc_core::SC_ZERO_TIME);
  }
  SC_CTOR($className) {
    clear_entries();
    for(auto& r:data.visible)
      r={sc_dt::SC_LOGIC_0, index(0), matches(0)};
    SC_METHOD(tick); sensitive << clk; dont_initialize();
    SC_METHOD(drive); sensitive << changed;
  }
};
''');
    return output.toString();
  }
}
