// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// valid_only_interface.dart
// Valid-only flow-control interface.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// A payload channel whose provider marks available data with valid.
///
/// A valid-only consumer has no backpressure signal and therefore accepts
/// every cycle for which valid is asserted.
/// {@category Flow Control}
class ValidOnlyInterface<LogicType extends Logic> extends PairInterface {
  /// Payload carried alongside valid.
  final LogicType data;

  /// Indicates that [data] is available in this cycle.
  Logic get valid => port('valid');

  /// Creates a valid-only interface with the given payload shape.
  ValidOnlyInterface(this.data)
      : super(portsFromProvider: [data, Logic.port('valid')]);

  bool _suppressPayload = false;

  @override
  Map<String, Logic> getPorts([Iterable<PairDirection>? tags]) {
    final ports = super.getPorts(tags);
    if (!_suppressPayload) {
      return ports;
    }
    return Map<String, Logic>.of(ports)..remove(data.name);
  }

  @override
  void connectIO(
    Module module,
    Interface<dynamic> srcInterface, {
    Iterable<PairDirection>? inputTags,
    Iterable<PairDirection>? outputTags,
    Iterable<PairDirection>? inOutTags,
    String Function(String original)? uniquify,
  }) {
    final inputTagSet = inputTags?.toSet();
    final outputTagSet = outputTags?.toSet();
    final inOutTagSet = inOutTags?.toSet();
    final input = inputTagSet?.contains(PairDirection.fromProvider) ?? false;
    final output = outputTagSet?.contains(PairDirection.fromProvider) ?? false;
    if ((input || output) &&
        (inOutTagSet?.contains(PairDirection.fromProvider) ?? false)) {
      throw PortTypeException.forIntendedName(
          data.name, 'Valid-only provider ports cannot also be inOut ports.');
    }
    if (input || output) {
      final source = srcInterface.port(data.name);
      if (!compatiblePayloadConnection(data, source,
          ignoreConstantNames: true)) {
        throw PortTypeException.forIntendedName(
            data.name, 'Valid-only payload shape does not match.');
      }
      final name = uniquify?.call(data.name) ?? data.name;
      if (input) {
        final bridge = data.cloneTyped(name: '${data.name}_input_bridge')
          ..gets(source);
        data <= module.addTypedInput(name, bridge);
      }
      if (output) {
        final registered = addTypedPayloadOutput(module, name, data);
        registered <= data;
        source <= registered;
      }
    }
    _suppressPayload = input || output;
    try {
      super.connectIO(module, srcInterface,
          inputTags: inputTagSet,
          outputTags: outputTagSet,
          inOutTags: inOutTagSet,
          uniquify: uniquify);
    } finally {
      _suppressPayload = false;
    }
  }

  @override
  ValidOnlyInterface<LogicType> clone() =>
      ValidOnlyInterface(cloneInterfacePayload<LogicType>(data));
}
