// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compression_delay_knob.dart
// Configurator controls for compression-tree timing estimates.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// Per-input delay tables for configurable compression trees.
class CompressionDelayKnob extends GroupOfKnobs {
  /// Creates editable, comma-separated delay tables.
  CompressionDelayKnob()
      : super({
          '2:1 Sum': StringConfigKnob(value: '1, 1'),
          '2:1 Carry': StringConfigKnob(value: '0.75, 0.75'),
          '3:2 Sum': StringConfigKnob(value: '1, 1, 1'),
          '3:2 Carry': StringConfigKnob(value: '0.75, 0.75, 0.75'),
          '4:2 Sum': StringConfigKnob(value: '2, 2, 2, 1, 1'),
          '4:2 Carry': StringConfigKnob(value: '1.75, 1.75, 1.75, 0.75, 0.75'),
          '4:2 Cout': StringConfigKnob(value: '0.75, 0.75, 0.75, x, x'),
        }, name: 'Compression Delay Tables');

  String _text(String key) => (subKnobs[key]! as StringConfigKnob).value;

  List<double> _delays(String key) => _text(key).split(',').map((part) {
        final value = double.tryParse(part.trim());
        if (value == null) {
          throw FormatException('Invalid $key delay: ${part.trim()}');
        }
        return value;
      }).toList();

  /// Returns the validated timing configuration.
  CompressionTreeDelayConfig resolve() {
    final cout = _text('4:2 Cout').split(',').map((part) {
      final text = part.trim();
      if (text.toLowerCase() == 'x') {
        return null;
      }
      final value = double.tryParse(text);
      if (value == null) {
        throw FormatException('Invalid 4:2 Cout delay: $text');
      }
      return value;
    }).toList();
    return CompressionTreeDelayConfig(
      compressor2: CompressorDelayTable(
          sum: _delays('2:1 Sum'), carry: _delays('2:1 Carry')),
      compressor3: CompressorDelayTable(
          sum: _delays('3:2 Sum'), carry: _delays('3:2 Carry')),
      compressor4: CompressorDelayTable(
          sum: _delays('4:2 Sum'), carry: _delays('4:2 Carry'), cout: cout),
    );
  }
}
