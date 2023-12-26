// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// component_registry.dart
// Registy of configurators.
//
// 2023 December 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/config_round_robin_arbiter.dart';

/// A list of [Configurator]s for ROHD-HCL components.
List<Configurator> get componentRegistry => [
      RotateConfigurator(),
      FifoConfigurator(),
      PriorityArbiterConfigurator(),
      RoundRobinArbiterConfigurator(),
      RippleCarryAdderConfigurator(),
      CarrySaveMultiplierConfigurator(),
      BitonicSortConfigurator(),
      OneHotConfigurator(),
      RegisterFileConfigurator(),
    ];
