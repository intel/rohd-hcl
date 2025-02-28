// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_exceptions.dart
// Exceptions for floating point values.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// An exception thrown when a [FloatingPointValue] does not support infinity
/// values.
class InfinityNotSupportedException extends RohdHclException {
  /// Creates an [InfinityNotSupportedException] with a message.
  InfinityNotSupportedException([super.message = 'Infinity is not supported']);
}
