// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// general_module_imports_test.dart
// Tests generic module imports alongside legacy barrel exports.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// Verify the deprecated barrel APIs remain usable.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/associative_match_selector.dart';
import 'package:rohd_hcl/associative_matcher.dart';
import 'package:rohd_hcl/priority_mux.dart';
import 'package:rohd_hcl/rohd_hcl.dart'
    hide
        AssociativeMatchSelector,
        AssociativeMatcher,
        PriorityMux,
        SpiMain,
        SpiSub,
        SynchronousAssociativeLookupPortInterface;
import 'package:rohd_hcl/rohd_hcl.dart' as legacy;
import 'package:rohd_hcl/spi_main.dart';
import 'package:rohd_hcl/spi_sub.dart';
import 'package:rohd_hcl/synchronous_associative_lookup_port_interface.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  _Payload({String name = 'payload'})
      : super([Logic(name: 'value', width: 8)], name: name);

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

void main() {
  test('generic synchronous port coexists with the published packed port', () {
    final port = SynchronousAssociativeLookupPortInterface<_Payload>(_Payload(),
        indexWidth: 3, matchEntryCount: 4);
    final clone = port.clone();
    expect(clone, isA<SynchronousAssociativeLookupPortInterface<_Payload>>());
    expect(clone.key, isA<_Payload>());
    expect(clone.matchEntryCount, 4);
    final old = legacy.SynchronousAssociativeLookupPortInterface(
        keyWidth: 8, indexWidth: 3);
    expect(old.clone().key, isNot(isA<LogicStructure>()));
    expect(port, isA<legacy.SynchronousAssociativeLookupPortInterface>());
  });

  test('generic selection imports coexist with legacy barrel classes', () {
    final payload = _Payload();
    final mux = PriorityMux<_Payload>(Logic(), [payload], payload);
    final matcher = AssociativeMatcher<_Payload>(
        query: payload, storedKeys: [payload], validMask: Logic());
    final selector = AssociativeMatchSelector<_Payload>(
        matchVector: Logic(), selectionValues: [payload]);
    expect(mux.result, isA<_Payload>());
    expect(matcher.input('query'), isA<_Payload>());
    expect(selector.input('selectionValue_0'), isA<_Payload>());

    final oldMux = legacy.PriorityMux(Logic(), [payload], payload);
    final oldMatcher = legacy.AssociativeMatcher(
        query: payload, storedKeys: [payload], validMask: Logic());
    final oldSelector = legacy.AssociativeMatchSelector(
        matchVector: Logic(), selectionValues: [payload]);
    expect(oldMux.result, isNot(isA<LogicStructure>()));
    expect(oldMatcher.input('query'), isNot(isA<LogicStructure>()));
    expect(oldSelector.input('selectionValue_0'), isNot(isA<LogicStructure>()));
  });

  test('generic SPI imports coexist with legacy barrel classes', () {
    final intf = SpiInterface(dataLength: 8);
    final main = SpiMain<_Payload, _Payload>(intf,
        clk: Logic(),
        reset: Logic(),
        start: Logic(),
        busIn: _Payload(),
        busOutSchema: _Payload());
    final sub = SpiSub<_Payload, _Payload>(
        intf: intf, busIn: _Payload(), busOutSchema: _Payload());
    expect(main.busOut, isA<_Payload>());
    expect(sub.busOut, isA<_Payload>());

    final oldMain = legacy.SpiMain(SpiInterface(dataLength: 8),
        clk: Logic(), reset: Logic(), start: Logic(), busIn: _Payload());
    final oldSub =
        legacy.SpiSub(intf: SpiInterface(dataLength: 8), busIn: _Payload());
    expect(oldMain.busOut, isNot(isA<LogicStructure>()));
    expect(oldSub.busOut, isNot(isA<LogicStructure>()));
  });
}
