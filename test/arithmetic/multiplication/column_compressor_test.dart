// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// column_compressor_test.dart
// Tests for the column compressor.
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

/// This [CompressorTestMod] module is used to test instantiation, where we can
/// catch trace errors (IO not added) not found in a simple test instantiation.
class CompressorTestMod extends Module {
  late final PartialProductGeneratorBase pp;

  late final ColumnCompressor compressor;

  Logic get r0 => output('r0');

  Logic get r1 => output('r1');

  CompressorTestMod(Logic ia, Logic ib, RadixEncoder encoder, Logic? iclk,
      {bool signed = true})
      : super(name: 'compressor_test_mod') {
    final a = addInput('a', ia, width: ia.width);
    final b = addInput('b', ib, width: ib.width);
    Logic? clk;
    if (iclk != null) {
      clk = addInput('clk', iclk);
    }

    final pp = PartialProduct(a, b, encoder,
        signedMultiplicand: StaticOrRuntimeParameter.staticValue(value: signed),
        signedMultiplier: StaticOrRuntimeParameter.staticValue(value: signed));
    final ppWithOutputs = pp
      ..generateOutputs(
        beforeGenerateOutputs: (array) =>
            CompactRectSignExtension(array).signExtend(),
      );

    compressor =
        ColumnCompressor(ppWithOutputs.rows, ppWithOutputs.rowShift, clk: clk);
    final r0 = addOutput('r0', width: compressor.columns.length);
    final r1 = addOutput('r1', width: compressor.columns.length);

    r0 <= compressor.add0;
    r1 <= compressor.add1;
  }
}

class _Compression42Harness extends Module {
  late final ColumnCompressor compressor;

  _Compression42Harness(List<int> widths, List<int> shifts,
      {bool use42 = true, CompressionTreeDelayConfig? delayConfig}) {
    final inputs = [
      for (var i = 0; i < widths.length; i++)
        addInput('row_$i', Logic(width: widths[i]), width: widths[i])
    ];
    compressor = ColumnCompressor(inputs, shifts,
        use42Compressors: use42, delayConfig: delayConfig);
    addOutput('result', width: compressor.add0.width) <=
        compressor.add0 + compressor.add1;
  }
}

class _Compression42Products extends Module {
  _Compression42Products() {
    final a = addInput('a', Logic(width: 6), width: 6);
    final b = addInput('b', Logic(width: 6), width: 6);
    final c = addInput('c', Logic(width: 13), width: 13);
    final sa = addInput('sa', Logic());
    final sb = addInput('sb', Logic());
    final sc = addInput('sc', Logic());
    StaticOrRuntimeParameter sign(Logic signal, String name) =>
        StaticOrRuntimeParameter.runtime(signal, name: name);

    final legacy = CompressionTreeMultiplier(a, b,
        radix: 2,
        signedMultiplicand: sign(sa, 'sa'),
        signedMultiplier: sign(sb, 'sb'));
    final multiplier = CompressionTreeMultiplier(a, b,
        radix: 2,
        use42Compressors: true,
        signedMultiplicand: sign(sa, 'sa'),
        signedMultiplier: sign(sb, 'sb'));
    final mac = CompressionTreeMultiplyAccumulate(a, b, c,
        radix: 2,
        use42Compressors: true,
        signedMultiplicand: sign(sa, 'sa'),
        signedMultiplier: sign(sb, 'sb'),
        signedAddend: sign(sc, 'sc'));
    final dot = CompressionTreeDotProduct([a, b], [b, a],
        productRadix: 2,
        use42Compressors: true,
        signedMultiplicand: sign(sa, 'sa'),
        signedMultiplier: sign(sb, 'sb'));
    addOutput('legacy', width: legacy.product.width) <= legacy.product;
    addOutput('product', width: multiplier.product.width) <= multiplier.product;
    addOutput('mac', width: mac.accumulate.width) <= mac.accumulate;
    addOutput('dot', width: dot.product.width) <= dot.product;
  }
}

class _ClockedCompression42 extends Module {
  _ClockedCompression42(
      {bool use42 = true, CompressionTreeDelayConfig? delayConfig}) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enable = addInput('enable', Logic());
    final rows = [
      for (var i = 0; i < 8; i++) addInput('row_$i', Logic(width: 3), width: 3)
    ];
    final compressor = ColumnCompressor(rows, List.filled(8, 0),
        clk: clk,
        reset: reset,
        enable: enable,
        use42Compressors: use42,
        delayConfig: delayConfig);
    addOutput('result', width: 3) <= compressor.add0 + compressor.add1;
  }
}

class _ClockedCompression42Products extends Module {
  _ClockedCompression42Products() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final enable = addInput('enable', Logic());
    final a = addInput('a', Logic(width: 6), width: 6);
    final b = addInput('b', Logic(width: 6), width: 6);
    final c = addInput('c', Logic(width: 13), width: 13);
    final multiplier = CompressionTreeMultiplier(a, b,
        clk: clk,
        reset: reset,
        enable: enable,
        radix: 2,
        use42Compressors: true);
    final mac = CompressionTreeMultiplyAccumulate(a, b, c,
        clk: clk,
        reset: reset,
        enable: enable,
        radix: 2,
        use42Compressors: true);
    addOutput('product', width: 12) <= multiplier.product;
    addOutput('mac', width: 13) <= mac.accumulate;
  }
}

class _Compression42Configurations extends Module {
  _Compression42Configurations() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final rows = [
      for (var i = 0; i < 5; i++) addInput('row_$i', Logic(width: 3), width: 3)
    ];
    final plain =
        ColumnCompressor(rows, List.filled(5, 0), use42Compressors: true);
    final shifted =
        ColumnCompressor(rows, [1, 0, 0, 0, 0], use42Compressors: true);
    final clocked = ColumnCompressor(rows, List.filled(5, 0),
        clk: clk, reset: reset, use42Compressors: true);
    addOutput('plain', width: 3) <= plain.add0 + plain.add1;
    addOutput('shifted', width: 4) <= shifted.add0 + shifted.add1;
    addOutput('clocked', width: 3) <= clocked.add0 + clocked.add1;
  }
}

class _ConfiguredCompressionProducts extends Module {
  final Map<Module, CompressionTreeDelayConfig> configured = {};

  _ConfiguredCompressionProducts(CompressionTreeDelayConfig delays) {
    final a = addInput('a', Logic(width: 4), width: 4);
    final b = addInput('b', Logic(width: 4), width: 4);
    final c = addInput('c', Logic(width: 9), width: 9);
    for (final use42 in [false, true]) {
      for (final (kind, config) in [
        ('default', null),
        ('custom', delays),
        (
          'custom_b',
          CompressionTreeDelayConfig(
            compressor3: CompressorDelayTable(sum: [5, 2, 1], carry: [1, 3, 4]),
          )
        ),
      ]) {
        final label = '${kind}_${use42 ? "c42" : "c32"}';
        final multiplier = CompressionTreeMultiplier(a, b,
            radix: 2, use42Compressors: use42, delayConfig: config);
        final mac = CompressionTreeMultiplyAccumulate(a, b, c,
            radix: 2, use42Compressors: use42, delayConfig: config);
        final dot = CompressionTreeDotProduct([a, b], [b, a],
            productRadix: 2, use42Compressors: use42, delayConfig: config);
        if (config != null) {
          for (final module in [multiplier, mac, dot]) {
            configured[module] = config;
          }
        }
        addOutput('${label}_product', width: 8) <= multiplier.product;
        addOutput('${label}_mac', width: 9) <= mac.accumulate;
        addOutput('${label}_dot', width: dot.product.width) <= dot.product;
      }
    }
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('delay tables derive 4:2 pin paths and validate their shape', () {
    final sum = <double>[1, 2, 3];
    final fullAdder = CompressorDelayTable(sum: sum, carry: [4, 5, 6]);
    final derived = CompressionTreeDelayConfig(compressor3: fullAdder);
    expect(derived.compressor4.sum, [4, 5, 6, 2, 1]);
    expect(derived.compressor4.carry, [7, 8, 9, 5, 4]);
    expect(derived.compressor4.cout, [4, 5, 6, null, null]);
    sum[0] = 100;
    expect(fullAdder.sum[0], 1);
    expect(() => fullAdder.sum[0] = 100, throwsUnsupportedError);
    expect(
        () => CompressorDelayTable(sum: [1], carry: [1]), throwsArgumentError);
    expect(() => CompressorDelayTable(sum: [1, 1], carry: [1]),
        throwsArgumentError);
    expect(() => CompressorDelayTable(sum: [double.nan, 1], carry: [1, 1]),
        throwsArgumentError);
    expect(() => CompressorDelayTable(sum: [1, 1], carry: [double.infinity, 1]),
        throwsArgumentError);
    expect(() => CompressorDelayTable(sum: [-1, 1], carry: [1, 1]),
        throwsArgumentError);
    expect(
        () => CompressorDelayTable(
            sum: [1, 1, 1, 1, 1],
            carry: [1, 1, 1, 1, 1],
            cout: [1, 1, 1, 1, null]),
        throwsArgumentError);
    expect(() => CompressionTreeDelayConfig(compressor2: fullAdder),
        throwsArgumentError);
  });

  test('2:1 and 3:2 use the delay of each physical input pin', () {
    final delays = CompressionTreeDelayConfig(
      compressor2: CompressorDelayTable(sum: [10, 20], carry: [2, 30]),
      compressor3: CompressorDelayTable(sum: [10, 20, 30], carry: [40, 2, 1]),
    );
    for (final count in [3, 4]) {
      final tree = ColumnCompressor(
        [for (var i = 0; i <= count; i++) Logic()],
        [for (var i = 0; i < count; i++) 0, 2],
        dontCompress: true,
        delayConfig: delays,
      );
      final inputs = tree.columns[0].toList();
      tree.columns[0].clear();
      for (var i = 0; i < inputs.length; i++) {
        inputs[i].delay = [1, 3, 7, 11][i].toDouble();
      }
      tree.columns[0].addAll(inputs);
      tree.compress();
      final sum = tree.columns[0]
          .toList()
          .singleWhere((term) => term.type == CompressTermType.sum);
      final carry = tree.columns[1].toList().single;
      expect(sum.delay, count == 3 ? 21 : 31);
      expect(carry.delay, count == 3 ? 31 : 47);
    }
  });

  test('4:2 uses all configured output paths and preserves default delays', () {
    final custom = CompressionTreeDelayConfig(
      compressor4: CompressorDelayTable(
        sum: [10, 20, 30, 40, 1000],
        carry: [50, 40, 30, 20, 1000],
        cout: [1, 8, 2, null, null],
      ),
    );
    for (final config in [null, custom]) {
      final tree = ColumnCompressor(
        [for (var i = 0; i < 5; i++) Logic()],
        [0, 0, 0, 0, 2],
        dontCompress: true,
        use42Compressors: true,
        delayConfig: config,
      );
      final inputs = tree.columns[0].toList();
      tree.columns[0].clear();
      for (var i = 0; i < inputs.length; i++) {
        inputs[i].delay = [1, 3, 7, 11][i].toDouble();
      }
      tree.columns[0].addAll(inputs);
      tree.compress();
      final sum = tree.columns[0].toList().single;
      final carries = tree.columns[1].toList();
      final carry = carries.singleWhere(
          (term) => term.inputs.first.type == CompressTermType.sum);
      final cout = carries
          .singleWhere((term) => term.inputs.first.type == CompressTermType.pp);
      expect(sum.delay, config == null ? 13 : 51);
      expect(carry.delay, config == null ? 13 : 51);
      expect(cout.delay, config == null ? 10 : 11);
    }
  });

  test('configured delays change which terms the tree compresses', () {
    final custom = CompressionTreeDelayConfig(
      compressor3: CompressorDelayTable(sum: [10, 20, 30], carry: [1, 1, 1]),
    );
    for (final config in [null, custom]) {
      final tree = ColumnCompressor(
        [for (var i = 0; i < 6; i++) Logic()],
        [0, 0, 0, 0, 0, 2],
        dontCompress: true,
        delayConfig: config,
      );
      final inputs = tree.columns[0].toList();
      tree.columns[0].clear();
      for (var i = 0; i < inputs.length; i++) {
        inputs[i].delay = [1, 3, 7, 11, 20][i].toDouble();
      }
      tree.columns[0].addAll(inputs);
      tree.compress();
      final lastSum = tree.columns[0].toList().singleWhere((term) =>
          term.type == CompressTermType.sum && term.inputs.length == 2);
      expect(
          lastSum.inputs.map((term) => term.type),
          config == null
              ? [CompressTermType.sum, CompressTermType.pp]
              : [CompressTermType.pp, CompressTermType.pp]);
    }
  });

  test('4:2 accounts for a delayed horizontal carry input', () {
    final config = CompressionTreeDelayConfig(
      compressor4: CompressorDelayTable(
        sum: [10, 20, 30, 40, 50],
        carry: [50, 40, 30, 20, 10],
        cout: [100, 0, 0, null, null],
      ),
    );
    final tree = ColumnCompressor(
      [for (var i = 0; i < 4; i++) Logic(width: 2), Logic()],
      [0, 0, 0, 0, 2],
      dontCompress: true,
      use42Compressors: true,
      delayConfig: config,
    );
    for (final column in tree.columns.take(2)) {
      final inputs = column.toList();
      column.clear();
      for (var i = 0; i < inputs.length; i++) {
        inputs[i].delay = [1, 3, 7, 11][i].toDouble();
      }
      column.addAll(inputs);
    }
    tree.compress();
    final sum = tree.columns[1]
        .toList()
        .singleWhere((term) => term.type == CompressTermType.sum);
    expect(sum.inputs.last.delay, 101);
    expect(sum.delay, 151);
  });

  test('custom and default delay trees coexist and preserve arithmetic in RTL',
      () async {
    final config = CompressionTreeDelayConfig(
      compressor3: CompressorDelayTable(sum: [1, 4, 2], carry: [3, 1, 5]),
    );
    final dut = _ConfiguredCompressionProducts(config);
    await dut.build();
    for (final entry in dut.configured.entries) {
      expect(
          entry.key.subModules.whereType<ColumnCompressor>().single.delayConfig,
          same(entry.value));
    }
    final vectors = <Vector>[];
    for (var a = 0; a < 16; a++) {
      for (var b = 0; b < 16; b++) {
        final c = (a * 17 + b * 3) & 511;
        vectors.add(Vector({
          'a': a,
          'b': b,
          'c': c
        }, {
          for (final label in [
            'default_c32',
            'custom_c32',
            'custom_b_c32',
            'default_c42',
            'custom_c42',
            'custom_b_c42',
          ]) ...{
            '${label}_product': a * b,
            '${label}_mac': (a * b + c) & 511,
            '${label}_dot': 2 * a * b,
          }
        }));
      }
    }
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final use42 in [false, true]) {
    test('custom delays preserve shifted-column arithmetic, 4:2 $use42',
        () async {
      final widths = [2, 1, 3, 2, 1, 3, 2, 1, 3];
      final shifts = [0, 3, 1, 4, 6, 0, 3, 5, 2];
      final config = CompressionTreeDelayConfig(
        compressor2: CompressorDelayTable(sum: [5, 1], carry: [2, 7]),
        compressor3: CompressorDelayTable(sum: [2, 7, 1], carry: [5, 3, 8]),
      );
      final dut = _Compression42Harness(widths, shifts,
          use42: use42, delayConfig: config);
      await dut.build();
      final random = Random(146);
      final vectors = <Vector>[];
      var lastResult = 0;
      for (var sample = 0; sample < 100; sample++) {
        final values = [for (final width in widths) random.nextInt(1 << width)];
        var result = 0;
        for (var i = 0; i < values.length; i++) {
          result += values[i] << shifts[i];
        }
        lastResult = result.toUnsigned(dut.output('result').width);
        vectors.add(Vector({
          for (var i = 0; i < values.length; i++) 'row_$i': values[i],
        }, {
          'result': lastResult,
        }));
      }
      await SimCompare.checkFunctionalVector(dut, vectors);
      expect(
          dut.compressor.evaluate().$1.toUnsigned(dut.output('result').width),
          BigInt.from(lastResult));
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('clocked custom-delay tree honors reset and enable in RTL', () async {
    final dut = _ClockedCompression42(
      use42: false,
      delayConfig: CompressionTreeDelayConfig(
        compressor3: CompressorDelayTable(sum: [2, 1, 3], carry: [1, 4, 2]),
      ),
    );
    await dut.build();
    final vectors = <Vector>[];
    void cycle(int row,
        {required int reset, required int enable, required int expected}) {
      final inputs = {
        'reset': reset,
        'enable': enable,
        for (var i = 0; i < 8; i++) 'row_$i': i < 3 ? row : 0,
      };
      vectors
        ..add(Vector({'clk': 0, ...inputs}, {}))
        ..add(Vector({'clk': 1, ...inputs}, {}))
        ..add(Vector({'clk': 0, ...inputs}, {'result': expected}));
    }

    cycle(7, reset: 1, enable: 1, expected: 0);
    cycle(2, reset: 0, enable: 1, expected: 6);
    cycle(1, reset: 0, enable: 0, expected: 6);
    cycle(1, reset: 0, enable: 1, expected: 3);
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('4:2 compressor covers all inputs in functional simulation and RTL',
      () async {
    expect(() => Compressor4(Logic(width: 3), Logic()),
        throwsA(isA<RohdHclException>()));
    final compressor = Compressor4(Logic(width: 4), Logic());
    await compressor.build();
    final vectors = <Vector>[];
    for (var input = 0; input < 16; input++) {
      for (var cin = 0; cin < 2; cin++) {
        final firstCount = [
          for (var bit = 0; bit < 3; bit++) (input >> bit) & 1
        ].reduce((a, b) => a + b);
        final secondCount = (firstCount & 1) + ((input >> 3) & 1) + cin;
        vectors.add(Vector({
          'compressBits': input,
          'carryIn': cin,
        }, {
          'sum': secondCount & 1,
          'carry': secondCount >= 2 ? 1 : 0,
          'cout': firstCount >= 2 ? 1 : 0,
        }));
      }
    }
    await SimCompare.checkFunctionalVector(compressor, vectors);
    SimCompare.checkIverilogVector(compressor, vectors);
  });

  for (final (widths, shifts) in [
    (List<int>.filled(8, 4), List<int>.filled(8, 0)),
    ([2, 1, 3, 2, 1, 3, 2, 1, 3], [0, 3, 1, 4, 6, 0, 3, 5, 2]),
  ]) {
    test('4:2 compression preserves shifted rows $shifts', () async {
      final dut = _Compression42Harness(widths, shifts);
      await dut.build();
      if (widths.length == 8) {
        expect(
          dut.compressor.subModules
              .whereType<Compressor4>()
              .where((compressor) => compressor.name.startsWith('cmp4_col1_'))
              .length,
          3,
        );
      }
      final random = Random(42);
      final vectors = <Vector>[];
      final width = dut.output('result').width;
      var expected = 0;
      for (var sample = 0; sample < 100; sample++) {
        final values = [
          for (final rowWidth in widths)
            if (sample == 0)
              0
            else if (sample == 1)
              (1 << rowWidth) - 1
            else
              random.nextInt(1 << rowWidth)
        ];
        expected = 0;
        for (var i = 0; i < values.length; i++) {
          expected += values[i] << shifts[i];
        }
        expected &= (1 << width) - 1;
        vectors.add(Vector({
          for (var i = 0; i < values.length; i++) 'row_$i': values[i],
        }, {
          'result': expected,
        }));
      }
      await SimCompare.checkFunctionalVector(dut, vectors);
      expect(dut.compressor.evaluate().$1.toUnsigned(width),
          BigInt.from(expected));
      for (final column in dut.compressor.columns) {
        for (final term in column.toList()) {
          expect(term.evaluate(), term.logic.value);
        }
      }
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('4:2 multiplier, MAC and dot product match signed references and RTL',
      () async {
    final dut = _Compression42Products();
    await dut.build();
    final random = Random(120);
    final vectors = <Vector>[];
    int interpret(int value, int width, {required bool signed}) =>
        signed && value >= 1 << (width - 1) ? value - (1 << width) : value;

    for (var flags = 0; flags < 8; flags++) {
      final sa = flags & 1;
      final sb = (flags >> 1) & 1;
      final sc = (flags >> 2) & 1;
      for (var i = 0; i < 30; i++) {
        final a = random.nextInt(64);
        final b = random.nextInt(64);
        final c = random.nextInt(8192);
        final product =
            interpret(a, 6, signed: sa == 1) * interpret(b, 6, signed: sb == 1);
        final mac = product + interpret(c, 13, signed: sc == 1);
        final dot = product +
            interpret(b, 6, signed: sa == 1) * interpret(a, 6, signed: sb == 1);
        vectors.add(Vector({
          'a': a,
          'b': b,
          'c': c,
          'sa': sa,
          'sb': sb,
          'sc': sc,
        }, {
          'legacy': product.toUnsigned(12),
          'product': product.toUnsigned(12),
          'mac': mac.toUnsigned(13),
          'dot': dot.toUnsigned(dut.output('dot').width),
        }));
      }
    }
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('4:2 tree pipeline honors reset and enable in RTL', () async {
    final dut = _ClockedCompression42();
    await dut.build();
    final vectors = <Vector>[];
    void cycle(int row,
        {required int reset, required int enable, required int expected}) {
      final inputs = {
        'reset': reset,
        'enable': enable,
        for (var i = 0; i < 8; i++) 'row_$i': i < 3 ? row : 0,
      };
      vectors
        ..add(Vector({'clk': 0, ...inputs}, {}))
        ..add(Vector({'clk': 1, ...inputs}, {}))
        ..add(Vector({'clk': 0, ...inputs}, {'result': expected}));
    }

    cycle(7, reset: 1, enable: 1, expected: 0);
    cycle(2, reset: 0, enable: 1, expected: 6);
    cycle(1, reset: 0, enable: 0, expected: 6);
    cycle(1, reset: 0, enable: 1, expected: 3);
    cycle(7, reset: 1, enable: 1, expected: 0);
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('4:2 multiplier and MAC pipelines honor reset and enable in RTL',
      () async {
    final dut = _ClockedCompression42Products();
    await dut.build();
    final vectors = <Vector>[];
    void cycle({
      required int a,
      required int b,
      required int c,
      required int reset,
      required int enable,
      required int product,
      required int mac,
    }) {
      final inputs = {
        'a': a,
        'b': b,
        'c': c,
        'reset': reset,
        'enable': enable,
      };
      vectors
        ..add(Vector({'clk': 0, ...inputs}, {}))
        ..add(Vector({'clk': 1, ...inputs}, {}))
        ..add(Vector({'clk': 0, ...inputs}, {'product': product, 'mac': mac}));
    }

    cycle(a: 0, b: 0, c: 0, reset: 1, enable: 1, product: 0, mac: 0);
    cycle(a: 6, b: 7, c: 9, reset: 0, enable: 1, product: 42, mac: 51);
    cycle(a: 2, b: 3, c: 4, reset: 0, enable: 0, product: 42, mac: 51);
    cycle(a: 2, b: 3, c: 4, reset: 0, enable: 1, product: 6, mac: 10);
    cycle(a: 0, b: 0, c: 0, reset: 1, enable: 1, product: 0, mac: 0);
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('4:2 trees with different shifts and clocks coexist in RTL', () async {
    final dut = _Compression42Configurations();
    await dut.build();
    final inputs = {
      'row_0': 3,
      'row_1': 2,
      'row_2': 1,
      'row_3': 0,
      'row_4': 0,
    };
    final vectors = [
      Vector({'clk': 0, 'reset': 1, ...inputs}, {}),
      Vector({'clk': 1, 'reset': 1, ...inputs}, {}),
      Vector({'clk': 0, 'reset': 0, ...inputs},
          {'plain': 6, 'shifted': 9, 'clocked': 0}),
      Vector({'clk': 1, 'reset': 0, ...inputs}, {}),
      Vector({'clk': 0, 'reset': 0, ...inputs},
          {'plain': 6, 'shifted': 9, 'clocked': 6}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('Column Compressor: evaluate flopped', () async {
    final clk = SimpleClockGenerator(10).clk;
    const widthX = 6;
    const widthY = 6;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    var av = 3;
    const bv = 6;
    var bA = SignedBigInt.fromSignedInt(av, widthX, signed: true);
    final bB = SignedBigInt.fromSignedInt(bv, widthY, signed: true);

    // Set these so that printing inside module build will have Logic values
    a.put(bA);
    b.put(bB);
    const radix = 2;
    final encoder = RadixEncoder(radix);

    final compressorTestMod = CompressorTestMod(a, b, encoder, clk);
    await compressorTestMod.build();

    unawaited(Simulator.run());

    await clk.nextNegedge;
    expect(compressorTestMod.compressor.evaluate().$1,
        equals(BigInt.from(av * bv)));
    av = 4;
    bA = BigInt.from(av).toSigned(widthX);
    a.put(bA);
    await clk.nextNegedge;
    expect(compressorTestMod.compressor.evaluate().$1,
        equals(BigInt.from(av * bv)));
    await Simulator.endSimulation();
  });

  test('Column Compressor: single compressor evaluate', () {
    const widthX = 3;
    const widthY = 3;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = -3;
    const bv = -3;
    for (final signed in [true, false]) {
      final bA = SignedBigInt.fromSignedInt(av, widthX, signed: signed);
      final bB = SignedBigInt.fromSignedInt(bv, widthY, signed: signed);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      const radix = 4;
      final encoder = RadixEncoder(radix);
      for (final useSelect in [false, true]) {
        final selectSignedMultiplicand =
            useSelect ? Logic(name: 'mcand') : null;
        final selectSignedMultiplier = useSelect ? Logic(name: 'mult') : null;
        if (useSelect) {
          selectSignedMultiplicand!.put(signed ? 1 : 0);
          selectSignedMultiplier!.put(signed ? 1 : 0);
        }
        final pp = PartialProduct(a, b, encoder,
            signedMultiplicand: StaticOrRuntimeParameter.staticValue(
                value: !useSelect & signed),
            signedMultiplier: StaticOrRuntimeParameter.staticValue(
                value: !useSelect & signed),
            selectSignedMultiplicand: selectSignedMultiplicand,
            selectSignedMultiplier: selectSignedMultiplier);
        final ppWithOutputs = pp
          ..generateOutputs(
            beforeGenerateOutputs: (array) =>
                CompactRectSignExtension(array).signExtend(),
          );
        final compressor = ColumnCompressor(
            ppWithOutputs.rows, ppWithOutputs.rowShift,
            dontCompress: true);
        expect(compressor.evaluate().$1, equals(bA * bB));
        compressor.compress();
        expect(compressor.evaluate().$1, equals(bA * bB));
      }
    }
  });
}
