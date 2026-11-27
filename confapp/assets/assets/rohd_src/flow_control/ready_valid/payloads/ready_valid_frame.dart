// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_frame.dart
// Protocol-neutral typed payload framing.
//
// 2026 August 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// A typed payload with an explicit end-of-frame marker.
///
/// [last] marks the final item of a frame. The surrounding schedule or
/// transport determines when that item is consumed.
/// {@category Flow Control}
class Frame<LogicType extends Logic> extends LogicStructure {
  /// Frame payload.
  LogicType get data => elements[0] as LogicType;

  /// High on the final item of a frame.
  Logic get last => elements[1];

  /// Creates a framed payload with [data] and [last].
  Frame(LogicType data, {String? name})
      : super([data, Logic(name: 'last')], name: name ?? '${data.name}_frame');

  Frame._clone(LogicStructure original, {String? name})
      : super(original.elements.map((element) => element.cloneTyped()).toList(),
            name: name ?? original.name);

  @override
  Frame<LogicType> clone({String? name}) =>
      Frame<LogicType>._clone(this, name: name);
}

/// A framed payload whose final beat declares its valid sub-element count.
///
/// [validElements] applies to the current beat and is typically the full lane
/// count except on the final padded beat of a width conversion. It describes
/// payload content accepted by this beat, not receiver capacity or a credit
/// return count.
/// {@category Flow Control}
class CountedFrame<LogicType extends Logic> extends LogicStructure {
  /// Payload containing one or more equally sized lanes.
  LogicType get data => elements[0] as LogicType;

  /// High on the final beat of a frame.
  Logic get last => elements[1];

  /// Number of valid leading lanes in [data].
  Logic get validElements => elements[2];

  /// Width of [validElements].
  final int countWidth;

  /// Creates a counted frame.
  CountedFrame(LogicType data, {required this.countWidth, String? name})
      : super([
          data,
          Logic(name: 'last'),
          Logic(name: 'validElements', width: countWidth)
        ], name: name ?? '${data.name}_counted_frame');

  CountedFrame._clone(LogicStructure original,
      {required this.countWidth, String? name})
      : super(original.elements.map((element) => element.cloneTyped()).toList(),
            name: name ?? original.name);

  @override
  CountedFrame<LogicType> clone({String? name}) =>
      CountedFrame<LogicType>._clone(this, countWidth: countWidth, name: name);
}
