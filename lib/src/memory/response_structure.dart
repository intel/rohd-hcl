// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// response_structure.dart
// Response structure for request/response channel components.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:rohd/rohd.dart';

/// A [LogicStructure] representing a response with id and data fields.
class ResponseStructure extends LogicStructure {
  /// The transaction ID field.
  Logic get id => elements[0];

  /// The data field.
  Logic get data => elements[1];

  /// Creates a [ResponseStructure] with the specified [idWidth] and
  /// [dataWidth].
  ResponseStructure({required int idWidth, required int dataWidth})
      : super([
          Logic(width: idWidth, name: 'id', naming: Naming.mergeable),
          Logic(width: dataWidth, name: 'data', naming: Naming.mergeable),
        ], name: 'responseStructure');

  /// Private constructor for cloning.
  ResponseStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  ResponseStructure clone({String? name}) =>
      ResponseStructure._fromStructure(this, name: name);
}
