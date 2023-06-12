// Copyright (C) 2023 Intel Corporation
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
  test('sparse memory storage can load a simple file', () {
    final hex = File('test/example1.hex').readAsStringSync();
    final storage = SparseMemoryStorage(addrWidth: 32)..loadMemHex(hex);

    expect(storage.getData(LogicValue.ofInt(0x8000000c, 32))!.toInt(),
        equals(0x1ff50513));
  });
}
