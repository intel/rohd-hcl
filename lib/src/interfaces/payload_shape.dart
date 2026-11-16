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

/// Whether two interface payloads can connect, allowing a packed bridge.
bool compatiblePayloadConnection(Logic target, Logic source,
    {bool ignoreConstantNames = false}) {
  if (target.width != source.width) {
    return false;
  }
  return !hasDeclaredPayloadShape(target) ||
      !hasDeclaredPayloadShape(source) ||
      sameDeclaredPayloadShape(target, source,
          ignoreConstantNames: ignoreConstantNames);
}

/// Clones an interface payload, making a widened scalar constant driveable.
T cloneInterfacePayload<T extends Logic>(T source) {
  if (T == Logic && source is Const) {
    return Logic(name: source.name, width: source.width) as T;
  }
  return source.cloneTyped();
}

/// Registers an output with a validated clone of [schema].
T addTypedPayloadOutput<T extends Logic>(Module module, String name, T schema) {
  T generator({String? name}) => schema.cloneTyped(name: name);
  final output = module.addTypedOutput<T>(name, generator);
  _validatePayloadClone(schema, output, name);
  return output;
}

void _validatePayloadClone(Logic source, Logic clone, String name) {
  if (!sameTypedCloneShape(source, clone)) {
    throw RohdHclException(
        'Typed payload "$name" requires a clone with the same payload type '
        'and format.');
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

/// Whether two payloads declare matching recursive hardware layouts.
bool sameHclPayloadShape(Logic template, Logic source) {
  if (template.width != source.width) {
    return false;
  }
  if (template is TypedLogicArray || source is TypedLogicArray) {
    if (template is! TypedLogicArray || source is! TypedLogicArray) {
      return false;
    }
    return template.dimensions.length == source.dimensions.length &&
        template.dimensions.indexed
            .every((d) => d.$2 == source.dimensions[d.$1]) &&
        template.elementWidth == source.elementWidth &&
        template.numUnpackedDimensions == source.numUnpackedDimensions &&
        identical(template.valueCodec, source.valueCodec) &&
        (template.arrayElements.isEmpty ||
            sameHclPayloadShape(
                template.arrayElements.first, source.arrayElements.first));
  }
  if (template is LogicEnum || source is LogicEnum) {
    return template is LogicEnum &&
        source is LogicEnum &&
        template.mapping.length == source.mapping.length &&
        template.mapping.entries.every((e) => source.mapping[e.key] == e.value);
  }
  if (template is! LogicStructure || source is! LogicStructure) {
    return template is! LogicStructure && source is! LogicStructure;
  }
  return template.elements.length == source.elements.length &&
      template.elements.indexed.every((entry) {
        final other = source.elements[entry.$1];
        return entry.$2.name == other.name &&
            sameHclPayloadShape(entry.$2, other);
      });
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
