// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dock_lock_icon.dart
// A two-box dock glyph used as the pin/lock toggle of auto-hiding panels
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The edge of the window a panel docks against.
enum DockEdge {
  /// A panel docked on the left, such as the component menu.
  left,

  /// A bar docked on the top, such as the app bar.
  top,
}

/// A two-box layout glyph whose leading strip is shaded when [locked],
/// matching the dock icon used by the ROHD wave viewer.
class DockLockIcon extends StatelessWidget {
  /// Creates a dock glyph for [edge], shaded when [locked].
  const DockLockIcon({
    required this.locked,
    required this.color,
    this.edge = DockEdge.left,
    this.size = 18,
    super.key,
  });

  /// Whether the panel is locked into the layout.
  final bool locked;

  /// The stroke and fill color of the glyph.
  final Color color;

  /// Which edge the panel docks against.
  final DockEdge edge;

  /// The width and height of the glyph in logical pixels.
  final double size;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('locked', value: locked, ifTrue: 'locked'))
      ..add(ColorProperty('color', color))
      ..add(EnumProperty<DockEdge>('edge', edge))
      ..add(DoubleProperty('size', size));
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _DockLockPainter(locked: locked, color: color, edge: edge),
      );
}

class _DockLockPainter extends CustomPainter {
  _DockLockPainter({
    required this.locked,
    required this.color,
    required this.edge,
  });

  final bool locked;
  final Color color;
  final DockEdge edge;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width / 16 * 1.4).clamp(1.0, 2.0);
    final rect = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height - stroke * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.14),
    );
    final isTop = edge == DockEdge.top;
    final extent = (isTop ? rect.height : rect.width) * 0.38;

    final Rect strip;
    final Offset dividerStart;
    final Offset dividerEnd;
    if (isTop) {
      strip = Rect.fromLTWH(rect.left, rect.top, rect.width, extent);
      dividerStart = Offset(rect.left, rect.top + extent);
      dividerEnd = Offset(rect.right, rect.top + extent);
    } else {
      strip = Rect.fromLTWH(rect.left, rect.top, extent, rect.height);
      dividerStart = Offset(rect.left + extent, rect.top);
      dividerEnd = Offset(rect.left + extent, rect.bottom);
    }

    if (locked) {
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawRect(
          strip,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: 0.9),
        )
        ..restore();
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..isAntiAlias = true;
    canvas
      ..drawRRect(rrect, line)
      ..drawLine(dividerStart, dividerEnd, line);
  }

  @override
  bool shouldRepaint(_DockLockPainter oldDelegate) =>
      oldDelegate.locked != locked ||
      oldDelegate.color != color ||
      oldDelegate.edge != edge;
}
