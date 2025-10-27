// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_structure.dart
// Request structure for request/response channel components.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:rohd/rohd.dart';

/// A [LogicStructure] representing a request with id and address fields.
class RequestStructure extends LogicStructure {
  /// The transaction ID field.
  Logic get id => elements[0];

  /// The address field.
  Logic get addr => elements[1];

  /// Creates a [RequestStructure] with the specified [idWidth] and [addrWidth].
  RequestStructure({required int idWidth, required int addrWidth})
      : super([
          Logic(width: idWidth, name: 'id', naming: Naming.mergeable),
          Logic(width: addrWidth, name: 'addr', naming: Naming.mergeable),
        ], name: 'requestStructure');

  /// Private constructor for cloning.
  RequestStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  RequestStructure clone({String? name}) =>
      RequestStructure._fromStructure(this, name: name);
}
