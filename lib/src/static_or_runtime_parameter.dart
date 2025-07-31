// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_parameter.dart
// Configuration classes for managing parameters that can be set statically or
// at runtime.
//
// 2025 June 27
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A general configuration class for specifying parameters that are
/// for both static or runtime configurations of a component feature.
class StaticOrRuntimeParameter {
  /// The runtime configuration logic that can be used to configure the
  /// component at runtime
  final Logic? runtimeConfig;

  /// The static configuration flag that indicates whether the
  /// feature is statically configured or not.
  late final bool staticConfig;

  /// The name of the configuration, especially needed for runtime to add as
  /// a module input.
  final String name;

  /// Creates a new [StaticOrRuntimeParameter] instance. Note that
  /// [runtimeConfig] overrides [staticConfig].  Also, it is presumed that
  /// [staticConfig] has a default value of `false` if not provided.
  StaticOrRuntimeParameter(
      {required this.name, this.runtimeConfig, bool? staticConfig = false}) {
    if (runtimeConfig == null && staticConfig != null) {
      this.staticConfig = staticConfig;
    } else {
      this.staticConfig = false;
    }
  }

  /// Factory constructor to create a [StaticOrRuntimeParameter] instance from a
  /// dynamic.
  factory StaticOrRuntimeParameter.ofDynamic(dynamic config) {
    if (config is StaticOrRuntimeParameter) {
      return config;
    } else if (config is bool) {
      return BooleanConfig(staticConfig: config);
    } else if (config == null) {
      return BooleanConfig(staticConfig: null);
    } else if (config is Logic) {
      return RuntimeConfig(config, name: config.name);
    } else {
      throw RohdHclException(
          'Unsupported configuration type: ${config.runtimeType}');
    }
  }

  /// Return a string representation of the configuration, including its name.
  @override
  String toString() => 'StaticOrRuntimeParameter_${name}_static_$staticConfig'
      '_runtime_${runtimeConfig?.name ?? 'null'}';

  /// Return a `bool` representing the value of the configuration.
  @visibleForTesting
  bool get value =>
      staticConfig ||
      (runtimeConfig != null && runtimeConfig!.value == LogicValue.one);

  /// Return the internal [Logic] signal that represents the configuration,
  /// either static or runtime.
  Logic getLogic(Module module) =>
      staticConfig ? Const(1) : (getRuntimeInput(module) ?? Const(0));

  /// Construct and return a [Logic]? that is a `true` input to the [module]
  /// if this is a runtime configuration signal.
  Logic? getRuntimeInput(Module module) => (runtimeConfig != null)
      ? tryRuntimeInput(module) ?? module.addInput(name, runtimeConfig!)
      : null;

  /// Returns a [Logic]? that represents the module internalruntime input.
  Logic? tryRuntimeInput(Module module) =>
      runtimeConfig != null ? module.tryInput(name) : null;
}

/// A configuration class for boolean configurations, which can be used to
/// statically enable or disable features in a component.
class BooleanConfig extends StaticOrRuntimeParameter {
  /// Creates a new [BooleanConfig] instance.
  BooleanConfig({super.staticConfig}) : super(name: 'boolean_config');
}

/// A configuration class for runtime configurations, which can be used to
/// dynamically configure a component at runtime.
class RuntimeConfig extends StaticOrRuntimeParameter {
  /// Creates a new [RuntimeConfig] instance.
  RuntimeConfig(Logic runtimeConfig, {required super.name})
      : super(runtimeConfig: runtimeConfig, staticConfig: null);
}
