// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_transaction_adapter_test.dart
// Tests token tracking and ready/valid transport.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  _Harness() {
    final cache = CacheTransactionPort<Logic, Logic, Logic, Logic>(
      addressWidth: 8,
      tokenWidth: 2,
      dataSchema: Logic(width: 8),
      writeMaskWidth: 1,
      lineMetadataSchema: Logic(width: 2),
      contextSchema: Logic(width: 4),
      resultSchema: Logic(width: 2),
    );
    final requests =
        IrrevocableReadyValidInterface(cache.requests.data.clone());
    final responses =
        IrrevocableReadyValidInterface(cache.responses.data.clone());
    final evictions =
        IrrevocableReadyValidInterface(cache.evictions.data.clone());
    requests.valid <= addInput('iv', Logic());
    requests.data.token <= addInput('it', Logic(width: 2), width: 2);
    requests.data.address <= addInput('ia', Logic(width: 8), width: 8);
    requests.data.context <= addInput('ic', Logic(width: 4), width: 4);
    requests.data.operation <= Const(0, width: 2);
    requests.data.data <= Const(0, width: 8);
    requests.data.writeMask <= Const(1);
    requests.data.lineMetadata <= Const(0, width: 2);
    responses.ready <= addInput('orr', Logic());
    evictions.ready <= addInput('oer', Logic());
    cache.requests.ready <= addInput('crr', Logic());
    cache.responses.valid <= addInput('crv', Logic());
    cache.responses.data.token <= addInput('crt', Logic(width: 2), width: 2);
    cache.responses.data.status <= Const(0, width: 2);
    cache.responses.data.data <= addInput('crd', Logic(width: 8), width: 8);
    cache.responses.data.lineMetadata <= Const(0, width: 2);
    cache.responses.data.context <= Const(0, width: 4);
    cache.responses.data.result <= Const(0, width: 2);
    cache.evictions.valid <= addInput('cev', Logic());
    cache.evictions.data.token <= addInput('cet', Logic(width: 2), width: 2);
    cache.evictions.data.cause <= Const(0);
    cache.evictions.data.address <= Const(0, width: 8);
    cache.evictions.data.data <= Const(0, width: 8);
    cache.evictions.data.lineMetadata <= Const(0, width: 2);
    cache.evictions.data.context <= Const(0, width: 4);
    cache.tokenConflict <= Const(0);
    final adapter = CacheTransactionAdapter(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      requests: requests,
      responses: responses,
      evictions: evictions,
      cache: cache,
      maxOutstanding: 2,
    );
    addOutput('ir') <= requests.ready;
    addOutput('cqv') <= cache.requests.valid;
    addOutput('cqt', width: 2) <= cache.requests.data.token;
    addOutput('cqa', width: 8) <= cache.requests.data.address;
    addOutput('cqc', width: 4) <= cache.requests.data.context;
    addOutput('orv') <= responses.valid;
    addOutput('ort', width: 2) <= responses.data.token;
    addOutput('ord', width: 8) <= responses.data.data;
    addOutput('crready') <= cache.responses.ready;
    addOutput('oev') <= evictions.valid;
    addOutput('ceready') <= cache.evictions.ready;
    addOutput('duplicate') <= adapter.duplicateRequest;
    addOutput('badResponse') <= adapter.invalidResponse;
    addOutput('badEviction') <= adapter.invalidEviction;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('tracks tokens through stalls, out-of-order responses and reset',
      () async {
    final dut = _Harness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'iv': 0,
        'it': 1,
        'ia': 0x11,
        'ic': 5,
        'orr': 0,
        'oer': 0,
        'crr': 0,
        'crv': 0,
        'crt': 0,
        'crd': 0,
        'cev': 0,
        'cet': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'iv': 1}, {'ir': 1}),
      Vector({'clk': 1}, {'cqv': 1, 'cqt': 1, 'cqa': 0x11, 'cqc': 5}),
      Vector({'clk': 0, 'iv': 0, 'ia': 0x77, 'ic': 0},
          {'cqv': 1, 'cqt': 1, 'cqa': 0x11, 'cqc': 5}),
      Vector({'clk': 1}, {'cqv': 1, 'cqa': 0x11}),
      Vector({'clk': 0, 'crr': 1}, {'cqv': 1}),
      Vector({'clk': 1}, {'cqv': 0}),
      Vector({'clk': 0, 'iv': 1, 'it': 2, 'ia': 0x22, 'ic': 6}, {'ir': 1}),
      Vector({'clk': 1}, {'cqv': 1, 'cqt': 2}),
      Vector({'clk': 0, 'iv': 0}, {'cqv': 1}),
      Vector({'clk': 1}, {'cqv': 0}),
      Vector({'clk': 0, 'iv': 1, 'it': 1}, {'ir': 0, 'duplicate': 1}),
      Vector({'iv': 0, 'crv': 1, 'crt': 3},
          {'badResponse': 1, 'orv': 0, 'crready': 0}),
      Vector({'crt': 2, 'crd': 0x52},
          {'badResponse': 0, 'orv': 1, 'ort': 2, 'ord': 0x52, 'crready': 0}),
      Vector({'clk': 1}, {'orv': 1, 'ort': 2, 'ord': 0x52}),
      Vector({'clk': 0, 'cev': 1, 'cet': 3},
          {'badEviction': 1, 'oev': 0, 'ceready': 0}),
      Vector({'cet': 1}, {'badEviction': 0, 'oev': 1, 'ceready': 0}),
      Vector({'oer': 1, 'orr': 1}, {'ceready': 1, 'crready': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'cev': 0, 'crv': 0, 'iv': 1, 'it': 1},
          {'duplicate': 1, 'ir': 0}),
      Vector({'iv': 0, 'crv': 1, 'crt': 1}, {'orv': 1, 'crready': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'crv': 0, 'iv': 1, 'it': 1}, {'ir': 1, 'duplicate': 0}),
      Vector({'clk': 1}, {'cqv': 1}),
      Vector({'clk': 0, 'reset': 1, 'iv': 0}, {'cqv': 0, 'ir': 0}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'crv': 1, 'crt': 1},
          {'badResponse': 1, 'orv': 0, 'crready': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  });

  test('full capacity releases only on the response edge', () async {
    final dut = _Harness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'iv': 0,
        'it': 1,
        'ia': 0x11,
        'ic': 5,
        'orr': 0,
        'oer': 0,
        'crr': 1,
        'crv': 0,
        'crt': 0,
        'crd': 0,
        'cev': 0,
        'cet': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'iv': 1}, {'ir': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 0}, {'cqv': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 1, 'it': 2}, {'ir': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 0}, {'cqv': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 1, 'it': 3}, {'ir': 0, 'duplicate': 0}),
      Vector({'crv': 1, 'crt': 1, 'orr': 1}, {'ir': 0, 'orv': 1, 'crready': 1}),
      Vector({'clk': 1}, {'ir': 1, 'cqv': 0}),
      Vector({'clk': 0, 'crv': 0}, {'ir': 1}),
      Vector({'clk': 1}, {'cqv': 1, 'cqt': 3}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('unknown tokens cannot create known transfers or diagnostics', () async {
    final dut = _Harness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'iv': 0,
        'it': 1,
        'ia': 0x11,
        'ic': 5,
        'orr': 0,
        'oer': 0,
        'crr': 1,
        'crv': 0,
        'crt': 0,
        'crd': 0,
        'cev': 0,
        'cet': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'iv': 1}, {'ir': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 1, 'it': LogicValue.ofString('0x')},
          {'ir': LogicValue.x, 'duplicate': LogicValue.x}),
      Vector({
        'iv': 0,
        'crv': 1,
        'crt': LogicValue.ofString('0x'),
        'cev': 1,
        'cet': LogicValue.ofString('0x'),
      }, {
        'badResponse': LogicValue.x,
        'orv': LogicValue.x,
        'crready': 0,
        'badEviction': LogicValue.x,
        'oev': LogicValue.x,
        'ceready': 0,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
