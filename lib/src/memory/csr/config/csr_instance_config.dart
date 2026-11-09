// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_instance_config.dart
// Configuration for an instance of a control and status register (CSR).
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configuration for a register instance.
///
/// Apply implementation specific information to an architectural register.
/// This includes instantiation of fields that require runtime configuration.
/// Such runtime configuration might also apply for conditional
/// instantiation of fields within the register
@immutable
class CsrInstanceConfig {
  /// Underlying architectural configuration.
  final CsrConfig arch;

  /// Register's address within its block
  ///
  /// This can be thought of as an offset relative to the block address.
  /// This can also be thought of as a unique ID for this register.
  final BigInt addr;

  /// Number of bits in the register.
  final int width;

  /// Accessor to the name of the architectural register.
  String get name => arch.name;

  /// Accessor to the architectural access rule of the register.
  CsrAccess get access => arch.access;

  /// Reset value of the register.
  final int resetValue;

  /// Frontdoor readability of the register.
  final bool isFrontdoorReadable;

  /// Frontdoor writability of the register.
  final bool isFrontdoorWritable;

  /// Backdoor readability of the register.
  final bool isBackdoorReadable;

  /// Backdoor writability of the register.
  final bool isBackdoorWritable;

  /// Helper for determining if the register is frontdoor accessible.
  bool get frontdoorAccessible => isFrontdoorReadable || isFrontdoorWritable;

  /// Helper for determining if the register is frontdoor accessible.
  bool get backdoorAccessible => isBackdoorReadable || isBackdoorWritable;

  /// Accessor to the fields of the register.
  List<CsrFieldConfig> get fields => arch.fields;

  /// Construct a new register configuration.
  CsrInstanceConfig({
    required this.arch,
    required int addr,
    required this.width,
    int? resetValue,
    bool? isFrontdoorReadable,
    bool? isFrontdoorWritable,
    bool? isBackdoorReadable,
    bool? isBackdoorWritable,
  })  : addr = BigInt.from(addr),
        resetValue = resetValue ?? arch.resetValue,
        isFrontdoorReadable = isFrontdoorReadable ?? arch.isFrontdoorReadable,
        isFrontdoorWritable = isFrontdoorWritable ?? arch.isFrontdoorWritable,
        isBackdoorReadable = isBackdoorReadable ?? arch.isBackdoorReadable,
        isBackdoorWritable = isBackdoorWritable ?? arch.isBackdoorWritable {
    _validate();
  }

  /// Constructs a register with an arbitrary-width address offset.
  CsrInstanceConfig.wide({
    required this.arch,
    required this.addr,
    required this.width,
    int? resetValue,
    bool? isFrontdoorReadable,
    bool? isFrontdoorWritable,
    bool? isBackdoorReadable,
    bool? isBackdoorWritable,
  })  : resetValue = resetValue ?? arch.resetValue,
        isFrontdoorReadable = isFrontdoorReadable ?? arch.isFrontdoorReadable,
        isFrontdoorWritable = isFrontdoorWritable ?? arch.isFrontdoorWritable,
        isBackdoorReadable = isBackdoorReadable ?? arch.isBackdoorReadable,
        isBackdoorWritable = isBackdoorWritable ?? arch.isBackdoorWritable {
    _validate();
  }

  /// Accessor to the config of a particular field
  /// within the register by name [name].
  CsrFieldConfig getFieldByName(String name) => arch.getFieldByName(name);

  /// Method to validate the configuration of a single register.
  ///
  /// Must check that its fields are mutually valid.
  void _validate() {
    if (addr.isNegative) {
      throw CsrValidationException('Register $name has a negative address.');
    }
    // reset value must fit within the register's width
    if (resetValue.bitLength > width) {
      throw CsrValidationException(
          'Register $name reset value does not fit within its width.');
    }

    // check that the field widths don't exceed the register width
    var impliedEnd = 0;
    for (final field in fields) {
      final currEnd = field.start + field.width - 1;
      if (currEnd > impliedEnd) {
        impliedEnd = currEnd;
      }
    }
    if (impliedEnd > width - 1) {
      throw CsrValidationException(
          'Register width implied by its fields exceeds true register width.');
    }
  }

  /// Clone the register configuration with optional overrides.
  CsrInstanceConfig clone(
      {CsrConfig? arch,
      int? addr,
      BigInt? wideAddr,
      int? width,
      int? resetValue,
      bool? isFrontdoorReadable,
      bool? isFrontdoorWritable,
      bool? isBackdoorReadable,
      bool? isBackdoorWritable}) {
    if (addr != null && wideAddr != null) {
      throw ArgumentError('Specify either addr or wideAddr, not both.');
    }
    return CsrInstanceConfig.wide(
      arch: arch ?? this.arch,
      addr: wideAddr ?? (addr == null ? this.addr : BigInt.from(addr)),
      width: width ?? this.width,
      resetValue: resetValue ?? this.resetValue,
      isFrontdoorReadable: isFrontdoorReadable ?? this.isFrontdoorReadable,
      isFrontdoorWritable: isFrontdoorWritable ?? this.isFrontdoorWritable,
      isBackdoorReadable: isBackdoorReadable ?? this.isBackdoorReadable,
      isBackdoorWritable: isBackdoorWritable ?? this.isBackdoorWritable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrInstanceConfig &&
        other.arch == arch &&
        other.addr == addr &&
        other.width == width &&
        other.resetValue == resetValue &&
        other.isFrontdoorReadable == isFrontdoorReadable &&
        other.isFrontdoorWritable == isFrontdoorWritable &&
        other.isBackdoorReadable == isBackdoorReadable &&
        other.isBackdoorWritable == isBackdoorWritable;
  }

  @override
  int get hashCode =>
      arch.hashCode ^
      addr.hashCode ^
      width.hashCode ^
      resetValue.hashCode ^
      isFrontdoorReadable.hashCode ^
      isFrontdoorWritable.hashCode ^
      isBackdoorReadable.hashCode ^
      isBackdoorWritable.hashCode;
}
