// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// exceptions.dart
// Exceptions for the library
//
// 2023 February 21
// Author: Max Korbel <max.korbel@intel.com>

/// An [Exception] for the ROHD Hardware Component Library.
class RohdHclException implements Exception {
  /// A message explaining this [Exception].
  final String message;

  /// Creates an [Exception] for the ROHD Hardware Component Library.
  RohdHclException(this.message);
}
