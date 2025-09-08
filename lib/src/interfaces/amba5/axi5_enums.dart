// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_enums.dart
// Enumerations for signal interpretation on AXI5.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

/// Helper to enumerate the encodings of the xBURST signal.
enum Axi5BurstField {
  /// Address remains constants.
  fixed(0x0),

  /// Address increments by the transfer size.
  incr(0x1),

  /// Similar to incr, but wraps around to a lower boundary point
  /// when an upper boundary point is reached.
  wrap(0x2);

  /// Underlying value.
  final int value;

  const Axi5BurstField(this.value);
}

/// Helper to enumerate the encodings of the xSIZE signal.
enum Axi5SizeField {
  /// 1 byte.
  bit8(0x0),

  /// 2 bytes.
  bit16(0x1),

  /// 4 bytes.
  bit32(0x2),

  /// 8 bytes.
  bit64(0x3),

  /// 16 bytes.
  bit128(0x4),

  /// 32 bytes.
  bit256(0x5),

  /// 64 bytes.
  bit512(0x6),

  /// 128 bytes.
  bit1024(0x7);

  /// Underlying value.
  final int value;

  const Axi5SizeField(this.value);

  factory Axi5SizeField.fromValue(int value) {
    switch (value) {
      case 0x0:
        return Axi5SizeField.bit8;
      case 0x1:
        return Axi5SizeField.bit16;
      case 0x2:
        return Axi5SizeField.bit32;
      case 0x3:
        return Axi5SizeField.bit64;
      case 0x4:
        return Axi5SizeField.bit128;
      case 0x5:
        return Axi5SizeField.bit256;
      case 0x6:
        return Axi5SizeField.bit512;
      case 0x7:
        return Axi5SizeField.bit1024;
      default:
        throw ArgumentError('Invalid field value: $value');
    }
  }

  factory Axi5SizeField.fromSize(int value) {
    switch (value) {
      case 0x8:
        return Axi5SizeField.bit8;
      case 0x10:
        return Axi5SizeField.bit16;
      case 0x20:
        return Axi5SizeField.bit32;
      case 0x40:
        return Axi5SizeField.bit64;
      case 0x80:
        return Axi5SizeField.bit128;
      case 0x100:
        return Axi5SizeField.bit256;
      case 0x200:
        return Axi5SizeField.bit512;
      case 0x400:
        return Axi5SizeField.bit1024;
      default:
        throw ArgumentError('Invalid size value: $value');
    }
  }

  /// Helper to determine the implied size of the access.
  static int getImpliedSize(Axi5SizeField size) {
    switch (size) {
      case Axi5SizeField.bit8:
        return 8;
      case Axi5SizeField.bit16:
        return 16;
      case Axi5SizeField.bit32:
        return 32;
      case Axi5SizeField.bit64:
        return 64;
      case Axi5SizeField.bit128:
        return 128;
      case Axi5SizeField.bit256:
        return 256;
      case Axi5SizeField.bit512:
        return 512;
      case Axi5SizeField.bit1024:
        return 1024;
    }
  }
}

/// Helper to enumerate the one hot encodings of the AxPROT signal.
enum Axi5ProtField {
  /// Transaction to be performed in privileged mode (1) or non-privileged (0).
  privileged(0x1),

  /// Transaction is accessing secure memory (0) or unsecure memory (1).
  secure(0x2),

  /// Transaction is performing an instruction fetch (1) or data fetch (0).
  instruction(0x4);

  /// Underlying value.
  final int value;

  const Axi5ProtField(this.value);
}

/// Helper to enumerate the one hot encodings of the AxCACHE signal.
enum Axi5CacheField {
  /// Transaction can be buffered.
  bufferable(0x1),

  /// Transaction can be cached.
  cacheable(0x2),

  /// Cache space can be allocated during a read.
  readAllocate(0x4),

  /// Cache space can be allocated during a write
  writeAllocate(0x8);

  /// Underlying one hot encoded value.
  final int value;

  const Axi5CacheField(this.value);
}

/// Helper to enumerate the encodings of the xRESP signal.
enum Axi5RespField {
  /// Expected result.
  okay(0x0),

  /// Okay, exclusive access granted.
  exOkay(0x1),

  /// Subordinate recoverable error.
  slvErr(0x2),

  /// Subordinate fatal error.
  decErr(0x3);

  /// Underlying value.
  final int value;

  const Axi5RespField(this.value);
}
