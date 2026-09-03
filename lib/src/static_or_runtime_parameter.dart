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

/// A value that can be configured statically or supplied by [Logic] at runtime.
///
/// [T] is the type of the static value. Use [resolve] to obtain this module's
/// internal runtime input or to convert the static value into [Logic].
class StaticOrRuntimeValue<T> {
  /// The runtime configuration signal, if this value is runtime-configurable.
  final Logic? runtimeConfig;

  /// The static value used when [runtimeConfig] is null.
  final T staticConfig;

  /// The module input name used for [runtimeConfig].
  final String name;

  /// Creates a static or runtime value.
  ///
  /// When [runtimeConfig] is provided, it takes precedence over [staticConfig].
  const StaticOrRuntimeValue(
      {required this.name, required this.staticConfig, this.runtimeConfig});

  /// Creates a value from either a runtime [Logic] or a static value.
  ///
  /// A null [config] selects [defaultValue]. Other static inputs are converted
  /// to [T] with [convertStatic].
  factory StaticOrRuntimeValue.ofDynamic(dynamic config,
      {required String name,
      required T defaultValue,
      required T Function(dynamic value) convertStatic}) {
    if (config is Logic) {
      return StaticOrRuntimeValue(
          name: name, staticConfig: defaultValue, runtimeConfig: config);
    }
    return StaticOrRuntimeValue(
        name: name,
        staticConfig: config == null ? defaultValue : convertStatic(config));
  }

  /// Whether this value is supplied at runtime.
  bool get isRuntime => runtimeConfig != null;

  /// Constructs and returns the internal input when runtime-configured.
  Logic? getRuntimeInput(Module module) => (runtimeConfig != null)
      ? tryRuntimeInput(module) ??
          module.addInput(name, runtimeConfig!, width: runtimeConfig!.width)
      : null;

  /// Returns the existing internal runtime input on [module], if any.
  Logic? tryRuntimeInput(Module module) =>
      runtimeConfig != null ? module.tryInput(name) : null;

  /// Resolves this value to [Logic] within [module].
  ///
  /// Runtime values become module inputs. Static values are converted by
  /// [staticToLogic].
  Logic resolve(Module module,
          {required Logic Function(T value) staticToLogic}) =>
      getRuntimeInput(module) ?? staticToLogic(staticConfig);
}

/// A boolean configuration that can be selected statically or at runtime.
class StaticOrRuntimeParameter extends StaticOrRuntimeValue<bool> {
  /// Creates a new [StaticOrRuntimeParameter] instance.
  ///
  /// [runtimeConfig] overrides [staticConfig]. A missing static value defaults
  /// to `false`.
  StaticOrRuntimeParameter(
      {required super.name, super.runtimeConfig, bool? staticConfig = false})
      : super(staticConfig: runtimeConfig == null && (staticConfig ?? false));

  /// Factory constructor to create a [StaticOrRuntimeParameter] from a dynamic.
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
      resolve(module, staticToLogic: (value) => Const(value ? 1 : 0));
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
