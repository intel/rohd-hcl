// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_container_config.dart
// Configuration for a container of control and status registers (CSRs).
//
// 2025 May
// Author: Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/memory/csr/csr_container.dart';

/// A base class for configs for [CsrContainer]s.
@immutable
abstract class CsrContainerConfig {
  /// Creates a clone of the configuration.
  CsrContainerConfig clone();

  /// Determines the minimum number of address bits needed to address all
  /// registers.
  int minAddrBits();

  /// Determines the maximum register size.
  int maxRegWidth();

  /// Name of the configuration.
  final String name;

  /// Creates a config for containers.
  const CsrContainerConfig({required this.name});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrContainerConfig && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}
