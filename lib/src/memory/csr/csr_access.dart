// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_access.dart
// Access enums and exceptions for CSRs.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

/// Targeted Exception type for control status register validation.
class CsrValidationException implements Exception {
  /// Message associated with the Exception.
  final String message;

  /// Public constructor.
  CsrValidationException(this.message);

  @override
  String toString() => message;
}

/// Definitions for various register field access patterns.
enum CsrFieldAccess {
  /// Register field is read only.
  readOnly,

  /// Register field can be read and written.
  readWrite,

  /// Writing 1's to the field triggers some other action,
  /// but the field itself is read only.
  writeOnesClear,

  /// Only legal values can be written
  readWriteLegal,
}

/// Definitions for various register access patterns.
enum CsrAccess {
  /// Register is read only.
  readOnly,

  /// Register can be read and written.
  readWrite,
}
