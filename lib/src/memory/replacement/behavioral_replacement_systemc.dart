// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_replacement_systemc.dart
// Standalone SystemC replacement policy generation.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/replacement/behavioral_replacement.dart';

/// Immutable configuration for a portable replacement policy.
class BehavioralReplacementDescription implements BehavioralModelDescription {
  /// Replacement algorithm.
  final BehavioralReplacementKind replacementKind;

  /// Number of managed entries.
  final int entryCount;

  /// Number of ordered access ports.
  final int accessCount;

  /// Number of ordered deferred commit ports.
  final int commitCount;

  /// Number of ordered allocation ports.
  final int allocationCount;

  /// Creates a replacement description.
  BehavioralReplacementDescription({
    required this.replacementKind,
    required this.entryCount,
    required this.accessCount,
    required this.commitCount,
    required this.allocationCount,
  }) {
    if (entryCount < 1 ||
        accessCount < 0 ||
        commitCount < 0 ||
        allocationCount < 1 ||
        (replacementKind == BehavioralReplacementKind.treePseudoLru &&
            (entryCount & (entryCount - 1)) != 0)) {
      throw ArgumentError('Invalid replacement policy geometry.');
    }
  }

  /// Width of an entry index.
  int get indexWidth => max(1, (entryCount - 1).bitLength);

  /// Width of the internal policy state.
  int get stateWidth => replacementKind == BehavioralReplacementKind.roundRobin
      ? indexWidth
      : max(1, entryCount - 1);

  @override
  String get kind => 'replacement';

  @override
  Map<String, int> get inputPorts => Map.unmodifiable({
        'clk': 1,
        'reset': 1,
        'validMask': entryCount,
        'eligibleMask': entryCount,
        for (var i = 0; i < accessCount; i++) ...{
          'access_${i}_en': 1,
          'access_${i}_index': indexWidth,
        },
        for (var i = 0; i < commitCount; i++) ...{
          'commit_${i}_en': 1,
          'commit_${i}_index': indexWidth,
        },
        for (var i = 0; i < allocationCount; i++) ...{
          'allocation_${i}_en': 1,
          'allocation_${i}_commit': 1,
        },
      });

  @override
  Map<String, int> get outputPorts => Map.unmodifiable({
        'invalidAccess': 1,
        'invalidCommit': 1,
        for (var i = 0; i < allocationCount; i++) ...{
          'allocation_${i}_valid': 1,
          'allocation_${i}_index': indexWidth,
          'allocation_${i}_evict': 1,
        },
      });

  /// Generates an independently executable behavioral SystemC policy.
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(className)) {
      throw ArgumentError.value(
          className, 'className', 'Invalid C++ identifier.');
    }
    final twoState = options.portType == SystemCModelPortType.twoState;
    final tree = replacementKind == BehavioralReplacementKind.treePseudoLru;
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
      ..writeln('#include <systemc>')
      ..writeln('#include <cstdint>')
      ..writeln('SC_MODULE($className) {')
      ..writeln('  using bit=sc_dt::sc_logic;')
      ..writeln('  static constexpr int E=$entryCount, I=$indexWidth, '
          'S=$stateWidth, R=${entryCount.bitLength};');
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
  sc_core::sc_signal<sc_dt::sc_lv<S>, sc_core::SC_MANY_WRITERS> state{"state"};
  sc_core::sc_signal<bool, sc_core::SC_MANY_WRITERS> resetSeen{"resetSeen"};
  using word=sc_dt::sc_lv<I>;
  using policy_state=sc_dt::sc_lv<S>;
  using mask=sc_dt::sc_lv<E>;
  struct image { policy_state state; bool resetSeen; };
  struct selection { bit valid; word index; };
  struct allocation { bit valid; word index; bit evict; };
  struct result {
    policy_state next;
    bit invalidAccess, invalidCommit;
    allocation outputs[$allocationCount];
  };
  static sc_dt::sc_lv<1> scalar(bit v) {
    sc_dt::sc_lv<1> r; r[0]=v; return r;
  }
  template<int W> static sc_dt::sc_lv<W> number(std::uint64_t v) {
    sc_dt::sc_lv<W> r; r=v; return r;
  }
  template<int W> static sc_dt::sc_lv<W> unknown() {
    return sc_dt::sc_lv<W>(sc_dt::SC_LOGIC_X);
  }
  template<int W> static sc_dt::sc_lv<W> choose(
      bit s, const sc_dt::sc_lv<W>& a, const sc_dt::sc_lv<W>& b) {
    if(s==sc_dt::SC_LOGIC_1) return a;
    if(s==sc_dt::SC_LOGIC_0) return b;
    sc_dt::sc_lv<W> r;
    for(int i=0;i<W;++i)
      r[i]=(a[i]==b[i]) ? bit(a[i]) : bit(sc_dt::SC_LOGIC_X);
    return r;
  }
  static bit chooseBit(bit s, bit a, bit b) {
    return bit(choose(s, scalar(a), scalar(b))[0]);
  }
  template<int W> static bit less(const sc_dt::sc_lv<W>& a,
      const sc_dt::sc_lv<W>& b) {
    return a.is_01() && b.is_01()
      ? bit(a.to_uint64()<b.to_uint64()) : bit(sc_dt::SC_LOGIC_X);
  }
  template<int W> static bit greaterEqual(const sc_dt::sc_lv<W>& a,
      const sc_dt::sc_lv<W>& b) {
    return a.is_01() && b.is_01()
      ? bit(a.to_uint64()>=b.to_uint64()) : bit(sc_dt::SC_LOGIC_X);
  }
  template<int W> static bit equalIndex(const sc_dt::sc_lv<W>& a,
      std::uint64_t index) {
    bit r=sc_dt::SC_LOGIC_1;
    for(int i=0;i<W;++i)
      r=r & ~(bit(a[i]) ^ bit(bool((index>>i)&1)));
    return r;
  }
  template<int W> static sc_dt::sc_lv<W> add(const sc_dt::sc_lv<W>& a,
      const sc_dt::sc_lv<W>& b) {
    return a.is_01() && b.is_01()
      ? number<W>(a.to_uint64()+b.to_uint64()) : unknown<W>();
  }
  template<int W> static sc_dt::sc_lv<W> sub(const sc_dt::sc_lv<W>& a,
      const sc_dt::sc_lv<W>& b) {
    return a.is_01() && b.is_01()
      ? number<W>(a.to_uint64()-b.to_uint64()) : unknown<W>();
  }
  template<int W> static sc_dt::sc_lv<W+1> extend(
      const sc_dt::sc_lv<W>& v) {
    sc_dt::sc_lv<W+1> r;
    for(int i=0;i<W;++i) r[i]=v[i];
    r[W]=sc_dt::SC_LOGIC_0; return r;
  }
  static bit any(const mask& v) {
    bit r=sc_dt::SC_LOGIC_0;
    for(int i=0;i<E;++i) r=r | bit(v[i]);
    return r;
  }
  static void updateNode(policy_state& out, const policy_state& old,
      const sc_dt::sc_lv<I+1>& index, int node, int start, int end) {
    if(end-start==1) return;
    int middle=(start+end)/2;
    bit range=greaterEqual(index,number<I+1>(start)) &
      less(index,number<I+1>(end));
    out[node]=chooseBit(range,
      less(index,number<I+1>(middle)),bit(old[node]));
    updateNode(out,old,index,node*2+1,start,middle);
    updateNode(out,old,index,node*2+2,middle,end);
  }
  static policy_state updateTree(const policy_state& old, const word& index) {
    if(E==1) return old;
    policy_state out=old;
    updateNode(out,old,extend(index),0,0,E);
    return out;
  }
  static selection selectTree(const policy_state& state, const mask& candidates,
      int node, int start, int end) {
    if(end-start==1) return {bit(candidates[start]),number<I>(start)};
    int middle=(start+end)/2;
    selection left=selectTree(state,candidates,node*2+1,start,middle);
    selection right=selectTree(state,candidates,node*2+2,middle,end);
    bit chooseRight=chooseBit(bit(state[node]),right.valid,
      ~left.valid & right.valid);
    return {left.valid | right.valid,choose(chooseRight,right.index,left.index)};
  }
  static selection selectRoundRobin(const policy_state& state,
      const mask& candidates) {
    sc_dt::sc_lv<R> pointer;
    for(int i=0;i<R;++i) pointer[i]=i<S ? bit(state[i]) : bit(sc_dt::SC_LOGIC_0);
    bit found=sc_dt::SC_LOGIC_0;
    word selected=number<I>(0);
    sc_dt::sc_lv<R> selectedValue=number<R>(0);
    for(int i=0;i<E;++i) {
      auto current=number<R>(i);
      auto rank=choose(greaterEqual(current,pointer),sub(current,pointer),
        add(sub(number<R>(E),pointer),current));
      bit take=bit(candidates[i]) & (~found | less(rank,selectedValue));
      selected=choose(take,number<I>(i),selected);
      selectedValue=choose(take,rank,selectedValue);
      found=found | bit(candidates[i]);
    }
    return {found,selected};
  }
  static policy_state access(const policy_state& s, const word& index) {
    return ${tree ? 'updateTree(s,index)' : 's'};
  }
  static policy_state allocate(const policy_state& s, const word& index) {
    return ${tree ? 'updateTree(s,index)' : 'choose(equalIndex(index,E-1),number<I>(0),add(index,number<I>(1)))'};
  }
  static selection select(const policy_state& s, const mask& candidates) {
    return ${tree ? 'selectTree(s,candidates,0,0,E)' : 'selectRoundRobin(s,candidates)'};
  }
  result compute() const {
    result r;
    r.next=state.read();
    r.invalidAccess=sc_dt::SC_LOGIC_0;
    r.invalidCommit=sc_dt::SC_LOGIC_0;
    mask valid=${vector('validMask', entryCount)};
    mask eligible=${vector('eligibleMask', entryCount)};
''');
    for (var i = 0; i < accessCount; i++) {
      source.writeln('''
    {
      word index=${vector('access_${i}_index', indexWidth)};
      bit en=${twoState ? 'bit(access_${i}_en.read())' : 'access_${i}_en.read()'};
      bit inRange=less(extend(index),number<I+1>(E));
      r.invalidAccess=r.invalidAccess | (en & ~inRange);
      r.next=choose(en & inRange,access(r.next,index),r.next);
    }
''');
    }
    for (var i = 0; i < commitCount; i++) {
      source.writeln('''
    {
      word index=${vector('commit_${i}_index', indexWidth)};
      bit en=${twoState ? 'bit(commit_${i}_en.read())' : 'commit_${i}_en.read()'};
      bit inRange=less(extend(index),number<I+1>(E));
      r.invalidCommit=r.invalidCommit | (en & ~inRange);
      r.next=choose(en & inRange,allocate(r.next,index),r.next);
    }
''');
    }
    source.writeln('    mask reserved=number<E>(0);');
    for (var i = 0; i < allocationCount; i++) {
      source.writeln('''
    {
      bit en=${twoState ? 'bit(allocation_${i}_en.read())' : 'allocation_${i}_en.read()'};
      bit commit=${twoState ? 'bit(allocation_${i}_commit.read())' : 'allocation_${i}_commit.read()'};
      mask available=eligible & ~reserved;
      mask unused=available & ~valid;
      mask candidates=choose(any(unused),unused,available);
      selection choice=select(r.next,candidates);
      bit granted=en & choice.valid;
      bit committed=granted & commit;
      r.invalidCommit=r.invalidCommit | (commit & ~granted);
      bit selectedValid=sc_dt::SC_LOGIC_0;
      mask reservation;
      for(int j=0;j<E;++j) {
        bit matches=equalIndex(choice.index,j);
        selectedValid=selectedValid | (bit(valid[j]) & matches);
        reservation[j]=granted & matches;
      }
      r.outputs[$i]={granted,choose(granted,choice.index,number<I>(0)),
        granted & selectedValid};
      reserved=reserved | reservation;
      r.next=choose(committed,allocate(r.next,choice.index),r.next);
    }
''');
    }
    source
      ..writeln('    return r;\n  }')
      ..writeln('  void evaluate() {\n    result r=compute();');
    void write(String port, String expr, {required bool scalar}) {
      if (!twoState) {
        final value = scalar || indexWidth != 1 ? expr : 'bit($expr[0])';
        source.writeln('    $port.write($value);');
      } else {
        final valid = '$expr.is_01()';
        final convert = scalar
            ? '$expr==sc_dt::SC_LOGIC_1'
            : indexWidth == 1
                ? 'bit($expr[0])==sc_dt::SC_LOGIC_1'
                : '$expr.to_uint64()';
        final allow =
            options.unknownOutputs == SystemCUnknownOutputPolicy.zeroUntilReset
                ? '!resetSeen.read()'
                : 'false';
        source.writeln('''
    if(!$valid && !($allow))
      SC_REPORT_ERROR("$className", "Unknown output $port at two-state boundary");
    $port.write($valid ? ($convert) : 0);
''');
      }
    }

    write('invalidAccess', 'r.invalidAccess', scalar: true);
    write('invalidCommit', 'r.invalidCommit', scalar: true);
    for (var i = 0; i < allocationCount; i++) {
      write('allocation_${i}_valid', 'r.outputs[$i].valid', scalar: true);
      write('allocation_${i}_index', 'r.outputs[$i].index', scalar: false);
      write('allocation_${i}_evict', 'r.outputs[$i].evict', scalar: true);
    }
    source.writeln('''
  }
  void tick() {
    bit rst=${twoState ? 'bit(reset.read())' : 'reset.read()'};
    if(rst==sc_dt::SC_LOGIC_1) resetSeen.write(true);
    state.write(choose(rst,number<S>(0),compute().next));
  }
  image snapshot() const { return {state.read(),resetSeen.read()}; }
  void restore(const image& saved) {
    state.write(saved.state); resetSeen.write(saved.resetSeen);
  }
  SC_CTOR($className) {
    state.write(unknown<S>());
    resetSeen.write(false);
    SC_METHOD(tick); sensitive << clk.pos(); dont_initialize();
    SC_METHOD(evaluate); sensitive << state << resetSeen
''');
    for (final name
        in inputPorts.keys.where((key) => key != 'clk' && key != 'reset')) {
      source.writeln('      << $name');
    }
    source.writeln('      ;\n  }\n};');
    return source.toString();
  }
}
