// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_binary_gray.dart
// Configurators for binary and Gray-code converters.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Shared configuration for a fixed-width binary/Gray-code converter.
abstract class _BinaryGrayConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.encodings;

  @override
  String get subcategory => 'gray';

  /// Width of the encoded value.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs =
      UnmodifiableMapView({'Width': widthKnob});
}

/// A [Configurator] for [BinaryToGrayConverter].
class BinaryToGrayConfigurator extends _BinaryGrayConfigurator {
  @override
  Module createModule() => BinaryToGrayConverter(Logic(width: widthKnob.value));

  @override
  String get name => 'Binary to Gray Converter';
}

/// A [Configurator] for [GrayToBinaryConverter].
class GrayToBinaryConfigurator extends _BinaryGrayConfigurator {
  @override
  Module createModule() => GrayToBinaryConverter(Logic(width: widthKnob.value));

  @override
  String get name => 'Gray to Binary Converter';
}
