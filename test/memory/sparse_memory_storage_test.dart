// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sparse_memory_storage_test.dart
// Tests for sparse memory storage
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/models/sparse_memory_storage.dart';
import 'package:test/test.dart';

void main() {
  group('sparse memory storage', () {
    test('can load a simple file (legacy)', () {
      final hex = File('test/example1.hex').readAsStringSync();
      final storage = SparseMemoryStorage(addrWidth: 32, dataWidth: 32)
        // ignore: deprecated_member_use_from_same_package
        ..loadMemHex(hex);

      expect(storage.getData(LogicValue.ofInt(0x8000000c, 32))!.toInt(),
          equals(0x1ff50513));
    });

    test('can load, dump, and reload a simple file', () {
      final hex = File('test/example1.hex').readAsStringSync();
      final storage = SparseMemoryStorage(addrWidth: 32, dataWidth: 32)
        ..loadMemString(hex);

      expect(storage.getData(LogicValue.ofInt(0x8000000c, 32))!.toInt(),
          equals(0x1ff50513));

      final dumped = storage.dumpMemString();

      final storage2 = SparseMemoryStorage(addrWidth: 32, dataWidth: 32)
        ..loadMemString(dumped);

      expect(storage2.getData(LogicValue.ofInt(0x8000000c, 32))!.toInt(),
          equals(0x1ff50513));
    });

    test('double load', () {
      const hex = '''
@1000
12 34 56 78
''';
      final storage = SparseMemoryStorage(addrWidth: 32, dataWidth: 32)
        ..loadMemString(hex)
        ..loadMemString(hex);

      const expected = 0x78563412;

      final addr = LogicValue.ofInt(0x1000, 32);
      final expectedData = LogicValue.ofInt(expected, 32);

      expect(storage.getData(addr)!.toInt(), equals(expectedData.toInt()),
          reason: 'Data at address $addr '
              'should be $expectedData but was '
              '${storage.getData(addr)!}');
    });

    test('example simple memory load with double load', () {
      const hex = '''
@80000000
6F 00 80 04 73 2F 20 34 25 0F 80 00 63 08 AB 03
25 0F 90 00 63 04 AB 03 25 0F B0 00 63 00 AB 03
13 0F 00 00 63 04 0F 00 67 00 0F 00 73 2F 20 34
63 54 0F 00 6F 00 40 00 25 E1 91 53 17 1F 00 00
''';

      final storage = SparseMemoryStorage(addrWidth: 32, dataWidth: 32)
        ..loadMemString(hex)
        ..loadMemString(hex);

      final expected = [
        0x0480006f,
        0x34202f73,
        0x00800f25,
        0x03ab0863,
        0x00900f25,
        0x03ab0463,
        0x00b00f25,
        0x03ab0063,
        0x00000f13,
        0x000f0463,
        0x000f0067,
        0x34202f73,
        0x000f5463,
        0x0040006f,
        0x5391e125,
      ];

      for (var i = 0; i < expected.length; i++) {
        final addr = LogicValue.ofInt(0x80000000 + i * 4, 32);
        final expectedData = LogicValue.ofInt(expected[i], 32);
        expect(storage.getData(addr)!.toInt(), equals(expectedData.toInt()),
            reason: 'Data at address $addr '
                'should be $expectedData but was '
                '${storage.getData(addr)!}');
      }
    });

    test('store 32-bit 1-per-addr data', () {
      final storage = SparseMemoryStorage(addrWidth: 8, dataWidth: 32);
      for (var i = 0; i < 10; i++) {
        storage.setData(
            LogicValue.ofInt(i, 8), LogicValue.ofInt(i, 4).replicate(8));
      }

      final memStr = storage.dumpMemString(bitsPerAddress: 32);

      expect(memStr, '''
@0
00000000
11111111
22222222
33333333
44444444
55555555
66666666
77777777
88888888
99999999
''');
    });

    test('binary radix read and write', () {
      const data = '''
@2
00000000
11111111
01010101
1010 1111
''';

      final storage = SparseMemoryStorage(addrWidth: 8, dataWidth: 8)
        ..loadMemString(data, radix: 2);

      final memStr = storage.dumpMemString(radix: 2);

      const expected = '''
@2
00000000
11111111
01010101
11111010
''';

      expect(memStr, expected);
    });

    test('comments and whitespace and out of order work properly', () {
      const data = '''

@100
00000000
//11111111
2222 //2222

33333333  // some comment
4444//4444
@80
5555 4321

// @100
65432100
77777 777


8 8888887
 9876 
54 3 
2


''';

      final storage = SparseMemoryStorage(addrWidth: 12, dataWidth: 32)
        ..loadMemString(data, bitsPerAddress: 32);

      final memStr = storage.dumpMemString(bitsPerAddress: 32);

      const expected = '''
@80
43215555
65432100
77777777
88888878
23549876
@100
00000000
33332222
44443333
''';

      expect(memStr, expected);
    });
  });
}
