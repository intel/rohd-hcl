// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// layout_dock_icon.dart
// Dock-layout icon for the component configuration pane.
//
// 2026 July 31
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// A compact layout icon representing a dockable left pane.
class LayoutDockIcon extends StatelessWidget {
  /// Creates a dock-layout icon.
  const LayoutDockIcon({
    required this.locked,
    required this.color,
    this.size = 18,
    super.key,
  });

  /// Whether the represented pane is locked into the layout.
  final bool locked;

  /// The icon stroke and fill color.
  final Color color;

  /// The square icon size.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size),
      painter: _LayoutDockPainter(locked: locked, color: color));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<bool>('locked', locked))
      ..add(ColorProperty('color', color))
      ..add(DoubleProperty('size', size));
  }
}

class _LayoutDockPainter extends CustomPainter {
  _LayoutDockPainter({required this.locked, required this.color});

  final bool locked;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width / 16 * 1.4).clamp(1.0, 2.0);
    final rect = Rect.fromLTWH(
        stroke, stroke, size.width - stroke * 2, size.height - stroke * 2);
    final outline =
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.14));
    final panelWidth = rect.width * 0.38;

    if (locked) {
      canvas
        ..save()
        ..clipRRect(outline)
        ..drawRect(
            Rect.fromLTWH(rect.left, rect.top, panelWidth, rect.height),
            Paint()
              ..style = PaintingStyle.fill
              ..color = color.withValues(alpha: 0.9))
        ..restore();
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..isAntiAlias = true;
    canvas
      ..drawRRect(outline, line)
      ..drawLine(Offset(rect.left + panelWidth, rect.top),
          Offset(rect.left + panelWidth, rect.bottom), line);
  }

  @override
  bool shouldRepaint(_LayoutDockPainter oldDelegate) =>
      oldDelegate.locked != locked || oldDelegate.color != color;
}
