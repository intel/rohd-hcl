// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_field_config.dart
// Configuration for a field within a control and status register (CSR).
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configuration for a register field.
///
/// If [start] and/or [width] is symbolic based on
/// the parent register width and/or other fields,
/// it is assumed that those symbolic values are resolved
/// before construction of the field config.
/// If a field should be duplicated n times within a register,
/// it is assumed that this object is instantiated n times
/// within the parent register config accordingly.
@immutable
class CsrFieldConfig {
  /// Starting bit position of the field in the register.
  final int start;

  /// Number of bits in the field.
  final int width;

  /// Name for the field.
  final String name;

  /// Access rule for the field.
  final CsrFieldAccess access;

  /// Reset value for the field.
  ///
  /// Can be unspecified in which case takes 0.
  final int resetValue;

  /// A list of legal values for the field.
  ///
  /// This list can be empty and in general is only
  /// applicable for fields with [CsrFieldAccess.readWriteLegal] access.
  final List<int> legalValues;

  /// Construct a new field configuration.
  CsrFieldConfig({
    required this.start,
    required this.width,
    required this.name,
    required this.access,
    List<int> legalValues = const [],
    this.resetValue = 0,
  }) : legalValues = List.unmodifiable(legalValues) {
    _validate();
  }

  /// Method to return a legal value from an illegal one.
  ///
  /// Only applicable for fields with [CsrFieldAccess.readWriteLegal] access.
  /// This is a default implementation that simply takes the first
  /// legal value but can be overridden in a derived class.
  int transformIllegalValue() => legalValues[0];

  /// Method to validate the configuration of a single field.
  void _validate() {
    // reset value must fit within the field's width
    if (resetValue.bitLength > width) {
      throw CsrValidationException(
          'Field $name reset value does not fit within the field.');
    }

    // there must be at least 1 legal value for a READ_WRITE_LEGAL field
    // and the reset value must be legal
    // and every legal value must fit within the field's width
    if (access == CsrFieldAccess.readWriteLegal) {
      if (legalValues.isEmpty) {
        throw CsrValidationException(
            'Field $name has no legal values but has access READ_WRITE_LEGAL.');
      } else if (!legalValues.contains(resetValue)) {
        throw CsrValidationException(
            'Field $name reset value is not a legal value.');
      }

      for (final lv in legalValues) {
        if (lv.bitLength > width) {
          throw CsrValidationException(
              'Field $name legal value $lv does not fit within the field.');
        }
      }
    }
  }

  /// Clone the field configuration with optional overrides.
  CsrFieldConfig clone(
          {int? start,
          int? width,
          String? name,
          CsrFieldAccess? access,
          int? resetValue,
          List<int>? legalValues}) =>
      CsrFieldConfig(
        start: start ?? this.start,
        width: width ?? this.width,
        name: name ?? this.name,
        access: access ?? this.access,
        resetValue: resetValue ?? this.resetValue,
        legalValues: legalValues ?? this.legalValues,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrFieldConfig &&
        other.start == start &&
        other.width == width &&
        other.name == name &&
        other.access == access &&
        other.resetValue == resetValue &&
        const ListEquality<int>().equals(other.legalValues, legalValues);
  }

  @override
  int get hashCode =>
      start.hashCode ^
      width.hashCode ^
      name.hashCode ^
      access.hashCode ^
      resetValue.hashCode ^
      const ListEquality<int>().hash(legalValues);
}
