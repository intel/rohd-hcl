// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';

/// One word-addressed write with one enable per byte, least-significant first.
/// {@category Memory}
class ByteMaskedWriteRequest extends LogicStructure {
  /// Word address, not byte address.
  Logic get address => elements[0];

  /// Data to write.
  Logic get data => elements[1];

  /// Enables for corresponding bytes of [data].
  Logic get byteEnable => elements[2];

  /// Width of [address].
  final int addressWidth;

  /// Width of [data].
  final int dataWidth;

  /// Creates a byte-masked request for a positive number of whole bytes.
  ByteMaskedWriteRequest({
    required this.addressWidth,
    required this.dataWidth,
    String? name,
  }) : super(_fields(addressWidth, dataWidth),
            name: name ?? 'byte_masked_write_request');

  static List<Logic> _fields(int addressWidth, int dataWidth) {
    if (addressWidth < 1 || dataWidth < 8 || dataWidth % 8 != 0) {
      throw ArgumentError(
        'addressWidth must be positive and dataWidth must be whole bytes.',
      );
    }
    return [
      Logic(name: 'address', width: addressWidth),
      Logic(name: 'data', width: dataWidth),
      Logic(name: 'byteEnable', width: dataWidth ~/ 8),
    ];
  }

  @override
  ByteMaskedWriteRequest clone({String? name}) => ByteMaskedWriteRequest(
      addressWidth: addressWidth,
      dataWidth: dataWidth,
      name: name ?? this.name);
}
