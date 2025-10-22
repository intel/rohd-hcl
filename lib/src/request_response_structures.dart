// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_structures.dart
// LogicStructures for request and response in RequestResponseChannel.
//
// 2025 October 19
// Author: Assistant

import 'package:rohd/rohd.dart';

/// A LogicStructure representing a request with an ID and address.
class RequestStructure extends LogicStructure {
  /// The unique identifier for this request.
  Logic get id => elements[0];

  /// The address for this request.
  Logic get address => elements[1];

  /// Creates a new [RequestStructure] with the specified [idWidth] and
  //[addressWidth].
  RequestStructure({
    required int idWidth,
    required int addressWidth,
  }) : super([
          Logic(name: 'id', width: idWidth),
          Logic(name: 'address', width: addressWidth),
        ], name: 'request');

  /// Creates a new [RequestStructure] from an existing structure for cloning.
  RequestStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  RequestStructure clone({String? name}) =>
      RequestStructure._fromStructure(this, name: name);
}

/// A LogicStructure representing a response with an ID and data.
class ResponseStructure extends LogicStructure {
  /// The unique identifier for this response, matching the request ID.
  Logic get id => elements[0];

  /// The data payload for this response.
  Logic get data => elements[1];

  /// Creates a new [ResponseStructure] with the specified [idWidth] and
  /// [dataWidth].
  ResponseStructure({
    required int idWidth,
    required int dataWidth,
  }) : super([
          Logic(name: 'id', width: idWidth),
          Logic(name: 'data', width: dataWidth),
        ], name: 'response');

  /// Creates a new [ResponseStructure] from an existing structure for cloning.
  ResponseStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  ResponseStructure clone({String? name}) =>
      ResponseStructure._fromStructure(this, name: name);
}
