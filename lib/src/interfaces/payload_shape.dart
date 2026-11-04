// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// payload_shape.dart
// Shared payload layout validation and synthesis identities.
//
// 2026 October 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Whether two payloads declare matching recursive hardware layouts.
bool sameDeclaredPayloadShape(Logic template, Logic source) {
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
            sameDeclaredPayloadShape(
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
            sameDeclaredPayloadShape(entry.$2, other);
      });
}

/// A deterministic recursive hardware-layout identity for generated modules.
String payloadShapeIdentity(Logic logic) {
  if (logic is TypedLogicArray) {
    final shape = 'A${logic.dimensions.join('x')}_'
        'E${logic.elementWidth}_U${logic.numUnpackedDimensions}';
    if (logic is LogicArray || logic.arrayElements.isEmpty) {
      return shape;
    }
    return '${shape}_T${payloadShapeIdentity(logic.arrayElements.first)}';
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
