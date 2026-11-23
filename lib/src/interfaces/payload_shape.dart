// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// payload_shape.dart
// Shared payload layout validation and synthesis identities.
//
// 2026 October 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

export 'package:rohd/rohd.dart' show PayloadShapeMetadata;

// See DEPRECATION_PLAN.md for the prerequisites for replacing these helpers.

/// Whether two payloads have identical declared shapes.
bool samePayloadShape(Logic first, Logic second,
        {bool ignoreConstantNames = false}) =>
    sameRohdPayloadShape(first, second,
        ignoreConstantNames: ignoreConstantNames);

/// Whether two interface payloads can connect, allowing a packed bridge.
// TODO(rohd): Replace with rohdPayloadsCompatible when it is released.
bool compatiblePayloadConnection(Logic target, Logic source,
    {bool ignoreConstantNames = false}) {
  if (target.width != source.width) {
    return false;
  }
  return !hasDeclaredPayloadShape(target) ||
      !hasDeclaredPayloadShape(source) ||
      samePayloadShape(target, source,
          ignoreConstantNames: ignoreConstantNames);
}

/// Whether all payloads are pairwise compatible, allowing packed bridges.
///
/// [allowRenamedClones] also permits parent-renamed typed clones and ignores
/// generated constant names.
// TODO(rohd): Replace with rohdPayloadsCompatible once the released API also
// supports allowRenamedClones, or retain that behavior separately.
bool compatiblePayloadSet(Iterable<Logic> payloads,
    {bool ignoreConstantNames = false, bool allowRenamedClones = false}) {
  final values = payloads.toList();
  for (var i = 0; i < values.length; i++) {
    for (var j = i + 1; j < values.length; j++) {
      final compatible = allowRenamedClones
          ? compatiblePayloadConnectionAllowingRenamedClone(
              values[i], values[j])
          : compatiblePayloadConnection(values[i], values[j],
              ignoreConstantNames: ignoreConstantNames);
      if (!compatible) {
        return false;
      }
    }
  }
  return true;
}

/// Whether corresponding payloads have identical declared shapes.
bool samePayloadSchemas(List<Logic> expected, List<Logic> actual) =>
    expected.length == actual.length &&
    expected.indexed
        .every((entry) => samePayloadShape(entry.$2, actual[entry.$1]));

/// Whether payload formats match, allowing renamed fields in typed clones.
// TODO(rohd): Remove when ROHD provides an equivalent renamed-clone check.
bool samePayloadShapeAllowingRenamedClone(Logic source, Logic other) =>
    samePayloadShape(source, other, ignoreConstantNames: true) ||
    (source.width == other.width &&
        hasDeclaredPayloadShape(source) &&
        hasDeclaredPayloadShape(other) &&
        sameTypedCloneShape(source, other));

/// Whether payloads connect through a packed bridge or a renamed typed clone.
// TODO(rohd): Remove when ROHD supports packed bridges and renamed clones.
bool compatiblePayloadConnectionAllowingRenamedClone(
        Logic target, Logic source) =>
    compatiblePayloadConnection(target, source, ignoreConstantNames: true) ||
    samePayloadShapeAllowingRenamedClone(target, source);

/// Clones a payload and checks its width and declared shape.
// TODO(rohd): Remove when ROHD validates width and shape for every typed clone.
T cloneTypedPayload<T extends Logic>(T source, {String? name}) {
  final clone = source.cloneTyped(name: name);
  _validatePayloadClone(source, clone, name ?? source.name);
  return clone;
}

/// Unambiguous ordered identity for a collection of payload shapes.
String payloadShapesIdentity(Iterable<Logic> payloads) => payloads.map((value) {
      final shape = payloadShapeIdentity(value);
      return '${shape.length}_$shape';
    }).join('_');

/// Clones an interface payload, making a widened scalar constant driveable.
// TODO(rohd): Remove when ROHD interface registration handles this constant
// normalization and enforces the same clone checks.
T cloneInterfacePayload<T extends Logic>(T source) {
  if (T == Logic && source is Const) {
    return Logic(name: source.name, width: source.width) as T;
  }
  return cloneTypedPayload(source);
}

/// Registers an output and validates its width and declared shape against
/// [schema].
///
/// [generator] may provide a driveable representation of [schema].
// TODO(rohd): Remove when ROHD validates outputs against a supplied schema,
// including custom generators and constant-containing structures.
T addTypedPayloadOutput<T extends Logic>(Module module, String name, T schema,
    {T Function({String? name})? generator}) {
  T clone({String? name}) => schema.cloneTyped(name: name);
  final output = module.addTypedOutput<T>(name, generator ?? clone);
  _validatePayloadClone(schema, output, name);
  return output;
}

/// Registers and connects a payload whose compatibility was already checked.
// TODO(rohd): Replace with ROHD schema-aware interface registration when
// released and it covers HCL's renamed clones, width checks, and directions.
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
    throw RohdHclException(
        'Typed payload "$name" requires a clone with the same width, '
        'payload type and format.');
  }
}

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

String _payloadLayoutIdentity(Logic logic) {
  if (logic is TypedLogicArray) {
    final shape = 'A${logic.dimensions.join('x')}_'
        'E${logic.elementWidth}_U${logic.numUnpackedDimensions}';
    if (logic is LogicArray || logic.arrayElements.isEmpty) {
      return shape;
    }
    final elements = logic.arrayElements.map(payloadShapeIdentity).toList();
    if (elements.every((element) => element == elements.first)) {
      return '${shape}_T${elements.first}';
    }
    final signatures =
        elements.map((element) => '${element.length}_$element').join('_');
    return '${shape}_H$signatures';
  }
  if (logic is LogicEnum) {
    return 'E${logic.width}_'
        '${logic.mapping.entries.map((e) => 'N${_encodeName(e.key.name)}_'
            'V${e.value.toBigInt().toRadixString(16)}').join('_')}';
  }
  if (logic is LogicStructure) {
    final fields = logic.elements
        .map((element) =>
            'N${_encodeName(element.name)}_${payloadShapeIdentity(element)}')
        .join('_');
    return 'S${logic.elements.length}_$fields';
  }
  return 'L${logic.width}';
}

String _encodeName(String name) => name.codeUnits
    .map((codeUnit) => codeUnit.toRadixString(16).padLeft(4, '0'))
    .join();
