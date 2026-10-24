// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// integer_knob_control.dart
// Stepper control for integer configuration knobs.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An editable integer parameter with validation and unit-step buttons.
class IntegerKnobControl extends StatefulWidget {
  /// Creates a control for an integer or optional integer [knob].
  const IntegerKnobControl({
    required this.label,
    required this.knob,
    required this.onChanged,
    super.key,
  }) : assert(knob is IntConfigKnob || knob is IntOptionalConfigKnob,
            'An integer control requires an integer knob.');

  /// The parameter's display label.
  final String label;

  /// The parameter and its existing default value.
  final TextConfigKnob<int?> knob;

  /// Called only when a valid edit changes the parameter value.
  final VoidCallback onChanged;

  @override
  State<IntegerKnobControl> createState() => _IntegerKnobControlState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(DiagnosticsProperty<TextConfigKnob<int?>>('knob', knob))
      ..add(ObjectFlagProperty<VoidCallback>.has('onChanged', onChanged));
  }
}

class _IntegerKnobControlState extends State<IntegerKnobControl> {
  late TextEditingController _controller;
  int? _lastValue;

  int? get _minimum {
    final knob = widget.knob;
    return knob is IntConfigKnob ? knob.minValue : null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.knob.valueString);
    _lastValue = widget.knob.value;
  }

  @override
  void didUpdateWidget(IntegerKnobControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.knob, widget.knob) ||
        _lastValue != widget.knob.value) {
      final previous = _controller;
      _controller = TextEditingController(text: widget.knob.valueString);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _lastValue = widget.knob.value;
    }
  }

  String? _validate(String? text) {
    final input = text?.trim() ?? '';
    if (input.isEmpty && widget.knob.allowEmpty) {
      return null;
    }
    final value = int.tryParse(input);
    if (value == null) {
      return 'Enter a valid integer';
    }
    if (_minimum != null && value < _minimum!) {
      return 'Must be at least $_minimum';
    }
    return null;
  }

  void _commit(String text) {
    setState(() {});
    if (_validate(text) != null) {
      return;
    }
    final value = text.trim().isEmpty ? null : int.parse(text.trim());
    if (value == widget.knob.value) {
      return;
    }
    widget.knob.setValueFromString(text.trim());
    _lastValue = widget.knob.value;
    widget.onChanged();
  }

  bool _canStep(int direction) {
    if (_validate(_controller.text) != null) {
      return false;
    }
    final current = widget.knob.value ?? 0;
    final next = current + direction;
    // Respect the platform integer representation without a configured maximum.
    return (direction > 0 ? next > current : next < current) &&
        (_minimum == null || next >= _minimum!);
  }

  void _step(int direction) {
    if (!_canStep(direction)) {
      return;
    }
    _controller.text = ((widget.knob.value ?? 0) + direction).toString();
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _commit(_controller.text);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        key: ObjectKey(widget.knob),
        controller: _controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: widget.label,
          hintText: widget.knob.allowEmpty ? 'Automatic' : null,
          isDense: true,
          prefixIcon: IconButton(
            tooltip: 'Decrease ${widget.label}',
            onPressed: _canStep(-1) ? () => _step(-1) : null,
            icon: const Icon(Icons.remove),
          ),
          suffixIcon: IconButton(
            tooltip: 'Increase ${widget.label}',
            onPressed: _canStep(1) ? () => _step(1) : null,
            icon: const Icon(Icons.add),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: _validate,
        onChanged: _commit,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
