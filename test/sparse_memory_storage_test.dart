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
