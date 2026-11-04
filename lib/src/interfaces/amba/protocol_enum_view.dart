// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// protocol_enum_view.dart
// Read-only enum views of raw protocol signals.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Creates an isolated enum view without constraining the raw protocol signal.
LogicEnum<T>? protocolEnumView<T extends Enum>(
    Logic? signal, Iterable<T> values, int Function(T) encoding) {
  if (signal == null) {
    return null;
  }
  final mapping = <T, int>{
    for (final value in values)
      if (encoding(value).bitLength <= signal.width) value: encoding(value),
  };
  final view = LogicEnum<T>.withMapping(mapping,
      width: signal.width, name: '${signal.name}_enum');
  view <= signal | Const(0, width: signal.width);
  return view;
}
