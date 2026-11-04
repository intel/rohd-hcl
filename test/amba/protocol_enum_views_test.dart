// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// protocol_enum_views_test.dart
// Tests for opt-in protocol enum views.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void checkMapping<T extends Enum>(Logic raw, LogicEnum<T> view,
    Iterable<T> values, int Function(T) encoding) {
  for (final value in values) {
    raw.put(encoding(value));
    expect(view.valueEnum, value);
    expect(raw.value.toInt(), encoding(value));
  }
}

void checkInvalidValues(Logic raw, LogicEnum view, List<LogicValue> values) {
  for (final value in values) {
    raw.put(value);
    expect(raw.value, value);
    expect(view.value.isValid, isFalse);
    expect(() => view.valueEnum, throwsStateError);
  }
}

class _AxiBurstHarness extends Module {
  _AxiBurstHarness() {
    final request = Axi4ArChannelInterface();
    request.burst! <= addInput('burst', Logic(width: 2), width: 2);
    addOutput('raw', width: 2) <= request.burst!;
    addOutput('incrementing') <= request.burstEnum!.eq(Axi4BurstField.incr);
    final response = Axi5BChannelInterface(config: Axi5BChannelConfig());
    response.resp! <= addInput('resp', Logic(width: 4), width: 4);
    addOutput('responseError') <= response.respEnum!.eq(Axi5RespField.slvErr);
    final lti = LtiLrChannelInterface(config: LtiLrChannelConfig());
    lti.resp! <= addInput('ltiResp', Logic(width: 3), width: 3);
    addOutput('translationFault') <= lti.respEnum!.eq(LtiRespField.faultAbort);
  }
}

void main() {
  tearDown(Simulator.reset);

  test('AXI4 request and response views use protocol encodings', () {
    final requests = [Axi4ArChannelInterface(), Axi4AwChannelInterface()];
    for (final request in requests) {
      expect(identical(request.burstEnum, request.burstEnum), isTrue);
      checkMapping(request.burst!, request.burstEnum!, Axi4BurstField.values,
          (value) => value.value);
      checkMapping(request.size!, request.sizeEnum!, Axi4SizeField.values,
          (value) => value.value);
      checkInvalidValues(request.burst!, request.burstEnum!, [
        LogicValue.ofInt(3, 2),
        LogicValue.ofString('1x'),
        LogicValue.ofString('1z'),
      ]);
    }

    final read = Axi4RChannelInterface();
    final write = Axi4BChannelInterface();
    checkMapping(read.resp!, read.respEnum!, Axi4RespField.values,
        (value) => value.value);
    checkMapping(write.resp!, write.respEnum!, Axi4RespField.values,
        (value) => value.value);
    final lite = Axi4LiteArChannelInterface();
    expect(lite.burstEnum, isNull);
    expect(lite.sizeEnum, isNull);
  });

  test('AXI5 request and response views preserve raw invalid values', () {
    final read = Axi5ArChannelInterface(config: Axi5ArChannelConfig());
    final write = Axi5AwChannelInterface(config: Axi5AwChannelConfig());
    for (final request in <Axi5RequestSignals>[read, write]) {
      checkMapping(request.burst!, request.burstEnum!, Axi5BurstField.values,
          (value) => value.value);
      checkMapping(request.size!, request.sizeEnum!, Axi5SizeField.values,
          (value) => value.value);
      checkInvalidValues(request.burst!, request.burstEnum!, [
        LogicValue.ofInt(3, 2),
        LogicValue.ofString('xz'),
      ]);
    }
    final readResponse = Axi5RChannelInterface(config: Axi5RChannelConfig());
    final writeResponse = Axi5BChannelInterface(config: Axi5BChannelConfig());
    for (final (raw, view) in [
      (readResponse.resp!, readResponse.respEnum!),
      (writeResponse.resp!, writeResponse.respEnum!),
    ]) {
      checkMapping(raw, view, Axi5RespField.values, (value) => value.value);
      checkInvalidValues(raw, view, [
        LogicValue.ofInt(8, raw.width),
        LogicValue.ofString('00xz'),
      ]);
    }
    final lite = Axi5LiteArChannelInterface(config: Axi5LiteArChannelConfig());
    expect(lite.burstEnum, isNull);
    expect(lite.sizeEnum, isNotNull);
    final absent =
        Axi5BChannelInterface(config: Axi5BChannelConfig(respWidth: 0));
    expect(absent.respEnum, isNull);
    final narrow =
        Axi5BChannelInterface(config: Axi5BChannelConfig(respWidth: 1));
    for (final value
        in Axi5RespField.values.where((value) => value.value < 2)) {
      narrow.resp!.put(value.value);
      expect(narrow.respEnum!.valueEnum, value);
    }

    final clone = read.clone();
    expect(identical(clone.burstEnum, read.burstEnum), isFalse);
    read.burst!.put(Axi5BurstField.incr.value);
    clone.burst!.put(Axi5BurstField.fixed.value);
    expect(read.burstEnum!.valueEnum, Axi5BurstField.incr);
    expect(clone.burstEnum!.valueEnum, Axi5BurstField.fixed);
  });

  test('LTI response view uses sparse LTI encodings', () {
    final response = LtiLrChannelInterface(config: LtiLrChannelConfig());
    checkMapping(response.resp!, response.respEnum!, LtiRespField.values,
        (value) => value.value);
    checkInvalidValues(response.resp!, response.respEnum!, [
      LogicValue.ofInt(3, 3),
      LogicValue.ofString('1z0'),
    ]);
  });

  test('valid enum views synthesize and compare like raw fields', () async {
    final dut = _AxiBurstHarness();
    await dut.build();
    final vectors = <Vector>[
      for (final value in Axi4BurstField.values)
        Vector({
          'burst': value.value,
          'resp': Axi5RespField.okay.value,
          'ltiResp': LtiRespField.success.value,
        }, {
          'raw': value.value,
          'incrementing': value == Axi4BurstField.incr ? 1 : 0,
          'responseError': 0,
          'translationFault': 0,
        }),
      for (final value in Axi5RespField.values)
        Vector({
          'burst': Axi4BurstField.fixed.value,
          'resp': value.value,
          'ltiResp': LtiRespField.success.value,
        }, {
          'raw': Axi4BurstField.fixed.value,
          'incrementing': 0,
          'responseError': value == Axi5RespField.slvErr ? 1 : 0,
          'translationFault': 0,
        }),
      for (final value in LtiRespField.values)
        Vector({
          'burst': Axi4BurstField.fixed.value,
          'resp': Axi5RespField.okay.value,
          'ltiResp': value.value,
        }, {
          'raw': Axi4BurstField.fixed.value,
          'incrementing': 0,
          'responseError': 0,
          'translationFault': value == LtiRespField.faultAbort ? 1 : 0,
        }),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });
}
