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
        ..loadMemHex(hex);

      expect(storage.getData(LogicValue.ofInt(0x8000000c, 32))!.toInt(),
          equals(0x1ff50513));
    });

    test('can load, dump, and load a simple file', () {
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

    test('store 32-bit 1-addr data', () {
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
  });

  // TODO Testplan:
  //  - comments (at start of line, end of line)
  //  - radix 2, 16
  //  - weird chunks of data not aligned
}
