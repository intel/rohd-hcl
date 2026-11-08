// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_control.dart
// Configuration classes for managing parameters that can be set statically or
// at runtime.
//
// 2025 June 27
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// Deprecated wrapper types remain for source compatibility.
// ignore_for_file: remove_deprecations_in_breaking_versions

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A component control that is configured statically or supplied by [Logic] at
/// runtime.
///
/// [T] is the type of the static value. Use [resolve] to obtain this module's
/// internal runtime input or to convert the static value into [Logic].
class StaticOrRuntimeControl<T> {
  static final Expando<Map<String, Logic>> _runtimeSources = Expando();

  /// The runtime configuration signal, if this value is runtime-configurable.
  final Logic? runtimeConfig;

  /// The static value used when [runtimeConfig] is null.
  final T staticConfig;

  /// The module input name used for [runtimeConfig].
  final String name;

  /// Creates a statically or runtime-configured control.
  ///
  /// When [runtimeConfig] is provided, it takes precedence over [staticConfig].
  const StaticOrRuntimeControl(
      {required this.name, required this.staticConfig, this.runtimeConfig});

  /// Creates a control from either a runtime [Logic] or a static value.
  ///
  /// A null [config] selects [defaultValue]. An existing
  /// [StaticOrRuntimeControl] retains its configuration under [name]. Other
  /// static inputs are converted to [T] with [convertStatic].
  factory StaticOrRuntimeControl.ofDynamic(dynamic config,
      {required String name,
      required T defaultValue,
      required T Function(dynamic value) convertStatic}) {
    if (config is StaticOrRuntimeControl<T>) {
      return StaticOrRuntimeControl(
          name: name,
          staticConfig: config.staticConfig,
          runtimeConfig: config.runtimeConfig);
    } else if (config is Logic) {
      return StaticOrRuntimeControl(
          name: name, staticConfig: defaultValue, runtimeConfig: config);
    }
    return StaticOrRuntimeControl(
        name: name,
        staticConfig: config == null ? defaultValue : convertStatic(config));
  }

  /// Whether this value is supplied at runtime.
  bool get isRuntime => runtimeConfig != null;

  /// Constructs and returns the internal input when runtime-configured.
  Logic? getRuntimeInput(Module module) {
    final config = runtimeConfig;
    if (config == null) {
      return null;
    }
    final existing = tryRuntimeInput(module);
    if (existing != null) {
      return existing;
    }
    final input = module.addInput(name, config, width: config.width);
    (_runtimeSources[module] ??= {})[name] = config;
    return input;
  }

  /// Returns the existing internal runtime input on [module], if any.
  ///
  /// An input with the same name but a different source is rejected.
  Logic? tryRuntimeInput(Module module) {
    final config = runtimeConfig;
    if (config == null) {
      return null;
    }
    final input = module.tryInput(name);
    if (input != null && !identical(input, config)) {
      final registeredSource = _runtimeSources[module]?[name];
      final matches = registeredSource != null
          ? identical(registeredSource, config)
          : identical(module.inputSource(name),
              config is LogicStructure ? config.packed : config);
      if (!matches) {
        throw RohdHclException(
            'Runtime control "$name" conflicts with an existing module input.');
      }
    }
    return input;
  }

  /// Returns a control for a child of [module], using its internal input.
  ///
  /// Static controls remain static. Runtime controls create the parent input
  /// if necessary, so the child does not connect directly to an external
  /// signal.
  StaticOrRuntimeControl<T> forChild(Module module, {String? name}) =>
      StaticOrRuntimeControl<T>(
          name: name ?? this.name,
          staticConfig: staticConfig,
          runtimeConfig: getRuntimeInput(module));

  /// Resolves this value to [Logic] within [module].
  ///
  /// Runtime values become module inputs. Static values are converted by
  /// [staticToLogic].
  Logic resolve(Module module,
          {required Logic Function(T value) staticToLogic}) =>
      getRuntimeInput(module) ?? staticToLogic(staticConfig);
}

/// A boolean configuration that can be selected statically or at runtime.
///
/// A runtime configuration must be a 1-bit [Logic] signal.
class StaticOrRuntimeParameter extends StaticOrRuntimeControl<bool> {
  /// Creates a new [StaticOrRuntimeParameter] instance.
  ///
  /// [runtimeConfig] overrides [staticConfig] and must be 1 bit wide. A missing
  /// static value defaults to `false`.
  StaticOrRuntimeParameter(
      {required super.name, super.runtimeConfig, bool? staticConfig = false})
      : super(staticConfig: runtimeConfig == null && (staticConfig ?? false)) {
    final runtimeBooleanConfig = runtimeConfig;
    if (runtimeBooleanConfig != null && runtimeBooleanConfig.width != 1) {
      throw RohdHclException(
          'Runtime boolean configuration "$name" must be 1 bit wide, '
          'got ${runtimeBooleanConfig.width}.');
    }
  }

  /// Creates a statically configured boolean.
  StaticOrRuntimeParameter.staticValue(
      {required bool value, String name = 'staticControl'})
      : this(name: name, staticConfig: value);

  /// Creates a runtime-configured boolean with an explicit input name.
  StaticOrRuntimeParameter.runtime(Logic value, {required String name})
      : this(name: name, runtimeConfig: value);

  /// Uses the signal's name, or [fallbackName] if it is unnamed.
  StaticOrRuntimeParameter.fromLogic(Logic value,
      {required String fallbackName})
      : this(
            name: value.naming == Naming.unnamed ? fallbackName : value.name,
            runtimeConfig: value);

  /// Factory constructor to create a [StaticOrRuntimeParameter] from a dynamic.
  factory StaticOrRuntimeParameter.ofDynamic(dynamic config, {String? name}) {
    if (config is StaticOrRuntimeParameter) {
      return config;
    } else if (config is StaticOrRuntimeControl<bool>) {
      return StaticOrRuntimeParameter(
          name: config.name,
          staticConfig: config.staticConfig,
          runtimeConfig: config.runtimeConfig);
    } else if (config is bool) {
      return StaticOrRuntimeParameter(
          name: 'boolean_config', staticConfig: config);
    } else if (config == null) {
      return StaticOrRuntimeParameter(name: 'boolean_config');
    } else if (config is Logic) {
      return StaticOrRuntimeParameter(
          name: config.naming == Naming.unnamed && name != null
              ? name
              : config.name,
          runtimeConfig: config);
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

  @override
  StaticOrRuntimeParameter forChild(Module module, {String? name}) =>
      StaticOrRuntimeParameter(
          name: name ?? this.name,
          staticConfig: staticConfig,
          runtimeConfig: getRuntimeInput(module));

  /// Selects between [whenTrue] and [whenFalse].
  ///
  /// A static control selects during generation. A runtime control uses a
  /// hardware mux; provide [module] when its input must be registered there.
  /// As with [mux], specify `<Logic>` for two scalar [Const] inputs when the
  /// control is runtime-configurable.
  LogicType select<LogicType extends Logic>(
      LogicType whenTrue, LogicType whenFalse,
      {Module? module}) {
    final config = runtimeConfig;
    final selector = config == null
        ? Const(staticConfig ? 1 : 0)
        : module == null
            ? config
            : getRuntimeInput(module)!;
    return mux<LogicType>(selector, whenTrue, whenFalse);
  }
}

/// A deprecated convenience wrapper for static boolean configurations.
///
/// Use [StaticOrRuntimeParameter] with [StaticOrRuntimeParameter.staticConfig]
/// instead.
@Deprecated('Use StaticOrRuntimeParameter instead.')
class BooleanConfig extends StaticOrRuntimeParameter {
  /// Creates a new [BooleanConfig] instance.
  @Deprecated('Use StaticOrRuntimeParameter instead.')
  BooleanConfig({super.staticConfig}) : super(name: 'boolean_config');
}

/// A deprecated convenience wrapper for 1-bit runtime boolean configurations.
///
/// Use [StaticOrRuntimeParameter] with
/// [StaticOrRuntimeParameter.runtimeConfig] instead.
@Deprecated('Use StaticOrRuntimeParameter instead.')
class RuntimeConfig extends StaticOrRuntimeParameter {
  /// Creates a new [RuntimeConfig] instance.
  @Deprecated('Use StaticOrRuntimeParameter instead.')
  RuntimeConfig(Logic runtimeConfig, {required super.name})
      : super(runtimeConfig: runtimeConfig, staticConfig: null);
}
