// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// payload_shape.dart
// Shared payload layout validation and synthesis identities.
//
// 2026 October 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

export 'package:rohd/rohd.dart' show PayloadShapeMetadata;

// See DEPRECATION_PLAN.md for the state of each helper in this file.

/// Whether two payloads have identical declared shapes.
@Deprecated('Use sameRohdPayloadShape from ROHD.')
bool samePayloadShape(Logic first, Logic second,
        {bool ignoreConstantNames = false}) =>
    sameRohdPayloadShape(first, second,
        ignoreConstantNames: ignoreConstantNames);

/// Whether two interface payloads can connect, allowing a packed bridge.
@Deprecated('Use rohdPayloadsCompatible([target, source]) from ROHD.')
bool compatiblePayloadConnection(Logic target, Logic source,
        {bool ignoreConstantNames = false}) =>
    rohdPayloadsCompatible([target, source],
        ignoreConstantNames: ignoreConstantNames);

/// Whether all payloads are pairwise compatible, allowing packed bridges.
///
/// [allowRenamedClones] also permits parent-renamed typed clones and ignores
/// generated constant names.
@Deprecated('Use rohdPayloadsCompatible from ROHD.')
bool compatiblePayloadSet(Iterable<Logic> payloads,
        {bool ignoreConstantNames = false, bool allowRenamedClones = false}) =>
    rohdPayloadsCompatible(payloads,
        ignoreConstantNames: ignoreConstantNames,
        allowRenamedClones: allowRenamedClones);

/// Whether corresponding payloads have identical declared shapes.
///
/// The length and order of the lists are the caller's contract, so this
/// remains here.
bool samePayloadSchemas(List<Logic> expected, List<Logic> actual) =>
    expected.length == actual.length &&
    expected.indexed
        .every((entry) => sameRohdPayloadShape(entry.$2, actual[entry.$1]));

/// Whether payload formats match, allowing renamed fields in typed clones.
@Deprecated(
    'Use sameRohdPayloadShape(source, other, allowRenamedClones: true) from '
    'ROHD.')
bool samePayloadShapeAllowingRenamedClone(Logic source, Logic other) =>
    sameRohdPayloadShape(source, other, allowRenamedClones: true);

/// Whether payloads connect through a packed bridge or a renamed typed clone.
@Deprecated(
    'Use rohdPayloadsCompatible([target, source], allowRenamedClones: true) '
    'from ROHD.')
bool compatiblePayloadConnectionAllowingRenamedClone(
        Logic target, Logic source) =>
    rohdPayloadsCompatible([target, source], allowRenamedClones: true);

/// Clones a payload, rejecting a clone that changes its width or declared
/// shape.
///
/// This is ROHD's `cloneTyped`, which makes those checks. It remains because
/// a clone that changes width is reported with this library's exception.
T cloneTypedPayload<T extends Logic>(T source, {String? name}) =>
    _reportingWidthChange(source, name, () => source.cloneTyped(name: name));

/// Runs [clone], reporting a clone of [source] that changes width as this
/// library does rather than as ROHD does.
T _reportingWidthChange<T extends Logic>(
    T source, String? name, T Function() clone) {
  try {
    return clone();
  } on LogicConstructionException {
    if (source.clone(name: name).width != source.width) {
      throw _invalidPayloadClone(name ?? source.name);
    }
    rethrow;
  }
}

/// Unambiguous ordered identity for a collection of payload shapes.
String payloadShapesIdentity(Iterable<Logic> payloads) => payloads.map((value) {
      final shape = payloadShapeIdentity(value);
      return '${shape.length}_$shape';
    }).join('_');

/// Readable shape parameters, with a digest fallback for long complex schemas.
///
/// [readableIdentity] may summarize a known canonical schema without omitting
/// distinctions; callers must verify that schema before supplying a summary.
/// Otherwise, field names and metadata use lossless readable escaping.
/// Only names exceeding 80 characters including [definitionPrefix] require
/// a SHA-256 fallback, and only when it shortens the schema. Explicit module
/// parameters are never hashed.
String compactPayloadShapesIdentity(
  Iterable<Logic> payloads, {
  String definitionPrefix = '',
  String? readableIdentity,
}) {
  final values = payloads.toList();
  final readable = readableIdentity ??
      values.map((value) {
        final shape = _readablePayloadShapeIdentity(value);
        return values.length == 1 ? shape : '${shape.length}_$shape';
      }).join('_');
  if (definitionPrefix.length + readable.length <= 80 ||
      readable.length <= 65) {
    return readable;
  }
  return 'H${sha256.convert(utf8.encode(payloadShapesIdentity(values)))}';
}

/// Appends a readable schema or a long-schema digest to module parameters.
String schemaQualifiedDefinitionName(
  String prefix,
  Iterable<Logic> payloads, {
  String suffix = '',
}) =>
    '$prefix${compactPayloadShapesIdentity(
      payloads,
      definitionPrefix: '$prefix$suffix',
    )}$suffix';

String _readablePayloadShapeIdentity(Logic logic) {
  final domain = logic is PayloadShapeMetadata
      ? 'D${readableSchemaName(
          (logic as PayloadShapeMetadata).payloadShapeMetadata,
        )}_'
      : '';
  return '$domain${_payloadLayoutIdentity(logic, readable: true)}';
}

/// Losslessly escapes a schema name into a length-delimited RTL identifier.
String readableSchemaName(String name) {
  final escaped = name.codeUnits.map((unit) {
    if ((unit >= 65 && unit <= 90) ||
        (unit >= 97 && unit <= 122) ||
        (unit >= 48 && unit <= 57)) {
      return String.fromCharCode(unit);
    }
    return '_${unit.toRadixString(16).padLeft(4, '0')}';
  }).join();
  return '${escaped.length}_$escaped';
}

/// Clones an interface payload, making a widened scalar constant driveable.
///
/// This is ROHD's `cloneInterfacePort`. It remains for the same reason as
/// [cloneTypedPayload].
T cloneInterfacePayload<T extends Logic>(T source) =>
    _reportingWidthChange(source, null, source.cloneInterfacePort);

/// Registers an output and validates its width and declared shape against
/// [schema].
///
/// [generator] may provide a driveable representation of [schema].
///
/// ROHD's `addTypedOutput` makes the same check when given `schema:`, and
/// reports a mismatch as a `PortTypeException`. This remains because a
/// mismatch here is reported with this library's exception.
T addTypedPayloadOutput<T extends Logic>(Module module, String name, T schema,
    {T Function({String? name})? generator}) {
  T clone({String? name}) => cloneTypedPayload(schema, name: name);
  final output = module.addTypedOutput<T>(name, generator ?? clone);
  _validatePayloadClone(schema, output, name);
  return output;
}

/// Registers and connects a payload whose compatibility was already checked.
///
/// ROHD's `Interface.typedPayloadPorts` registers typed ports for an
/// interface that declares them. This remains for the interfaces here that
/// check their payloads under their own protocol's rules first.
void connectTypedPayloadPorts<T extends Logic>(
  Module module, {
  required String name,
  required T local,
  required Logic source,
  bool input = false,
  bool output = false,
  bool inOut = false,
}) {
  if (input) {
    final bridge = cloneTypedPayload(local, name: '${local.name}_input_bridge')
      ..gets(source);
    local <= module.addTypedInput<T>(name, bridge);
  }
  if (output) {
    final registered = addTypedPayloadOutput<T>(module, name, local);
    registered <= local;
    source <= registered;
  }
  if (inOut) {
    final bridge = cloneTypedPayload(local, name: '${local.name}_inout_bridge')
      ..gets(source);
    local <= module.addTypedInOut<T>(name, bridge);
  }
}

void _validatePayloadClone(Logic source, Logic clone, String name) {
  if (source.width != clone.width || !sameTypedCloneShape(source, clone)) {
    throw _invalidPayloadClone(name);
  }
}

RohdHclException _invalidPayloadClone(String name) => RohdHclException(
    'Typed payload "$name" requires a clone with the same width, '
    'payload type and format.');

/// Drives packed bits through a payload's leaves without semantic conversion.
void putPackedLogicValue(Logic data, LogicValue value) {
  if (data is LogicStructure) {
    final bits = LogicValue.of(value, width: data.width);
    var offset = 0;
    for (final leaf in data.leafElements) {
      leaf.put(bits.getRange(offset, offset + leaf.width));
      offset += leaf.width;
    }
  } else {
    data.put(value);
  }
}

/// Drives packed bits into a payload's leaves without semantic conversion.
void connectPackedPayload(Logic destination, Logic packed) {
  if (destination.width != packed.width) {
    throw ArgumentError('Packed payload widths must match.');
  }
  if (destination is LogicStructure) {
    var offset = 0;
    for (final leaf in destination.leafElements) {
      leaf <= packed.getRange(offset, offset + leaf.width);
      offset += leaf.width;
    }
  } else {
    destination <= packed;
  }
}

/// A deterministic recursive hardware-layout identity for generated modules.
String payloadShapeIdentity(Logic logic) {
  final domain = logic is PayloadShapeMetadata
      ? 'D${_encodeName((logic as PayloadShapeMetadata).payloadShapeMetadata)}_'
      : '';
  return '$domain${_payloadLayoutIdentity(logic)}';
}

String _payloadLayoutIdentity(Logic logic, {bool readable = false}) {
  final identity =
      readable ? _readablePayloadShapeIdentity : payloadShapeIdentity;
  final encodeName = readable ? readableSchemaName : _encodeName;
  if (logic is TypedLogicArray) {
    final shape = 'A${logic.dimensions.join('x')}_'
        'E${logic.elementWidth}_U${logic.numUnpackedDimensions}';
    if (logic is LogicArray || logic.arrayElements.isEmpty) {
      return shape;
    }
    final elements = logic.arrayElements.map(identity).toList();
    if (elements.every((element) => element == elements.first)) {
      return '${shape}_T${elements.first}';
    }
    final signatures =
        elements.map((element) => '${element.length}_$element').join('_');
    return '${shape}_H$signatures';
  }
  if (logic is LogicEnum) {
    return 'E${logic.width}_'
        '${logic.mapping.entries.map((e) => 'N${encodeName(e.key.name)}_'
            'V${e.value.toBigInt().toRadixString(16)}').join('_')}';
  }
  if (logic is LogicStructure) {
    final fields = logic.elements
        .map((element) => 'N${encodeName(element.name)}_${identity(element)}')
        .join('_');
    return 'S${logic.elements.length}_$fields';
  }
  return 'L${logic.width}';
}

String _encodeName(String name) => name.codeUnits
    .map((codeUnit) => codeUnit.toRadixString(16).padLeft(4, '0'))
    .join();
