// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_format_control.dart
// Compact, labeled fixed-point format editor.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/integer_knob_control.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A labeled pair of validated width and fractional-precision controls.
class FixedPointFormatControl extends StatelessWidget {
  /// Creates a compact editor for [knob].
  const FixedPointFormatControl({
    required this.label,
    required this.knob,
    required this.onChanged,
    super.key,
  });

  /// The arithmetic role or definition being edited.
  final String label;

  /// The shared numeric format.
  final InferenceFixedPointFormatKnob knob;

  /// Called after a valid edit changes the format.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >=
                          240 * MediaQuery.textScalerOf(context).scale(1)
                      ? (constraints.maxWidth - 8) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in {
                        'Width': knob.widthKnob,
                        'Fraction Bits': knob.fractionBitsKnob,
                      }.entries)
                        SizedBox(
                          width: width,
                          child: IntegerKnobControl(
                            key: ValueKey(entry.key),
                            label: entry.key,
                            knob: entry.value,
                            compact: true,
                            onChanged: onChanged,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(DiagnosticsProperty<InferenceFixedPointFormatKnob>('knob', knob))
      ..add(ObjectFlagProperty<VoidCallback>.has('onChanged', onChanged));
  }
}
