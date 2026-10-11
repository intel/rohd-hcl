// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_interface.dart
// Ready/valid interface implementation.
//
// 2025 October 20
// Author: Max Korbel <max.korbel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Static behavioral promises and dependency permissions for a ready/valid
/// channel.
@immutable
class ReadyValidContract {
  /// Whether valid is permitted to depend combinationally on ready.
  final bool validMayDependOnReady;

  /// Whether ready is permitted to depend combinationally on valid.
  final bool readyMayDependOnValid;

  /// Whether valid must remain asserted until a stalled offer is accepted.
  final bool validMustRemainAssertedWhileStalled;

  /// Whether payload must remain stable until a stalled offer is accepted.
  final bool payloadMustRemainStableWhileStalled;

  /// A contract with no dependency restrictions or stall guarantees.
  static const unconstrained = ReadyValidContract(
    validMayDependOnReady: true,
    readyMayDependOnValid: true,
  );

  /// A contract in which ready and valid are computed independently.
  static const readyAndValid = ReadyValidContract(
    validMayDependOnReady: false,
    readyMayDependOnValid: false,
  );

  /// A contract in which valid may wait for ready.
  static const readyThenValid = ReadyValidContract(
    validMayDependOnReady: true,
    readyMayDependOnValid: false,
  );

  /// A contract in which ready may wait for valid.
  static const validThenReady = ReadyValidContract(
    validMayDependOnReady: false,
    readyMayDependOnValid: true,
  );

  /// A valid-first contract with stable valid and payload while stalled.
  static const irrevocable = ReadyValidContract(
    validMayDependOnReady: false,
    readyMayDependOnValid: true,
    validMustRemainAssertedWhileStalled: true,
    payloadMustRemainStableWhileStalled: true,
  );

  /// Creates ready/valid behavioral metadata.
  const ReadyValidContract({
    required this.validMayDependOnReady,
    required this.readyMayDependOnValid,
    this.validMustRemainAssertedWhileStalled = false,
    this.payloadMustRemainStableWhileStalled = false,
  });

  /// Returns a copy with selected axes replaced.
  ReadyValidContract copyWith({
    bool? validMayDependOnReady,
    bool? readyMayDependOnValid,
    bool? validMustRemainAssertedWhileStalled,
    bool? payloadMustRemainStableWhileStalled,
  }) =>
      ReadyValidContract(
        validMayDependOnReady:
            validMayDependOnReady ?? this.validMayDependOnReady,
        readyMayDependOnValid:
            readyMayDependOnValid ?? this.readyMayDependOnValid,
        validMustRemainAssertedWhileStalled:
            validMustRemainAssertedWhileStalled ??
                this.validMustRemainAssertedWhileStalled,
        payloadMustRemainStableWhileStalled:
            payloadMustRemainStableWhileStalled ??
                this.payloadMustRemainStableWhileStalled,
      );

  /// Whether this actual contract satisfies all [required] restrictions and
  /// guarantees.
  bool satisfies(ReadyValidContract required) =>
      !(validMayDependOnReady && !required.validMayDependOnReady) &&
      !(readyMayDependOnValid && !required.readyMayDependOnValid) &&
      (!required.validMustRemainAssertedWhileStalled ||
          validMustRemainAssertedWhileStalled) &&
      (!required.payloadMustRemainStableWhileStalled ||
          payloadMustRemainStableWhileStalled);

  /// Whether this provider may wait for ready while [peer] may wait for valid.
  bool mayFormDependencyCycleWith(ReadyValidContract peer) =>
      validMayDependOnReady && peer.readyMayDependOnValid;

  /// Rejects a direct provider-to-consumer composition that can form a
  /// combinational valid/ready cycle.
  ///
  /// This is a construction-time check rather than a Dart type-system check:
  /// interface contracts are values carried by generic interface instances.
  /// [provider] describes the valid behavior at the boundary and [consumer]
  /// describes the ready behavior at that same boundary.
  static void requireComposable({
    required ReadyValidContract provider,
    required ReadyValidContract consumer,
    required String providerName,
    required String consumerName,
  }) {
    if (provider.mayFormDependencyCycleWith(consumer)) {
      throw ArgumentError(
        'Ready/valid composition from $providerName to '
        '$consumerName can form a combinational dependency cycle: provider '
        'valid may depend on ready while consumer ready may depend on valid. '
        'Insert a storage stage or use independent boundary contracts.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReadyValidContract &&
      validMayDependOnReady == other.validMayDependOnReady &&
      readyMayDependOnValid == other.readyMayDependOnValid &&
      validMustRemainAssertedWhileStalled ==
          other.validMustRemainAssertedWhileStalled &&
      payloadMustRemainStableWhileStalled ==
          other.payloadMustRemainStableWhileStalled;

  @override
  int get hashCode => Object.hash(
        validMayDependOnReady,
        readyMayDependOnValid,
        validMustRemainAssertedWhileStalled,
        payloadMustRemainStableWhileStalled,
      );
}

/// A ready/valid interface with associated data of type [LogicType].
/// {@category Flow Control}
class ReadyValidInterface<LogicType extends Logic> extends PairInterface {
  /// The data associated with the ready/valid handshake.
  final LogicType data;

  /// The behavioral metadata associated with this interface.
  final ReadyValidContract contract;

  bool _suppressHandledProviderPorts = false;

  /// Indicates that the consumer is ready to accept data.
  Logic get ready => port('ready');

  /// Indicates that the provider has valid data.
  Logic get valid => port('valid');

  /// Indicates that a transaction has been accepted (both valid and ready).
  /// Use the underlying data's name for a stable port name instead of
  /// interpolating the object itself.
  late final Logic accepted = (ready & valid).named('${data.name}_accepted');

  /// Indicates that valid data is waiting for the consumer to become ready.
  late final Logic stalled = (valid & ~ready).named('${data.name}_stalled');

  /// Creates a [ReadyValidInterface] with the given [data].
  ReadyValidInterface(
    this.data, {
    this.contract = ReadyValidContract.unconstrained,
  }) : super(
          portsFromProvider: [data, Logic.port('valid')],
          portsFromConsumer: [Logic.port('ready')],
        );

  /// Verifies that this provider can connect to [consumerContract].
  void requireProviderComposableWith(
    ReadyValidContract consumerContract, {
    required String consumerName,
  }) =>
      ReadyValidContract.requireComposable(
        provider: contract,
        consumer: consumerContract,
        providerName: data.name,
        consumerName: consumerName,
      );

  /// Verifies that [providerContract] can connect to this consumer.
  void requireConsumerComposableWith(
    ReadyValidContract providerContract, {
    required String providerName,
  }) =>
      ReadyValidContract.requireComposable(
        provider: providerContract,
        consumer: contract,
        providerName: providerName,
        consumerName: data.name,
      );

  /// Connects this channel while retaining the payload's concrete logic type.
  ///
  /// Generic [Interface.connectIO] registers every non-array port with scalar
  /// `addInput` and `addOutput`. Ready/valid payloads may be [LogicStructure]s,
  /// so this override uses typed module ports for [data], bridges compatible
  /// packed sources, and leaves sidebands, nested interfaces, and the
  /// single-bit controls on the standard recursive connection path.
  @override
  void connectIO(
    Module module,
    Interface<dynamic> srcInterface, {
    Iterable<PairDirection>? inputTags,
    Iterable<PairDirection>? outputTags,
    Iterable<PairDirection>? inOutTags,
    String Function(String original)? uniquify,
  }) {
    final dataName = data.name;
    final inputTagSet = inputTags?.toSet();
    final outputTagSet = outputTags?.toSet();
    final inputIncludesProvider =
        inputTagSet?.contains(PairDirection.fromProvider) ?? false;
    final outputIncludesProvider =
        outputTagSet?.contains(PairDirection.fromProvider) ?? false;
    final portName = (uniquify ?? (original) => original)(dataName);
    final validPortName = (uniquify ?? (original) => original)('valid');

    if (inputIncludesProvider) {
      final sourcePayload = _validatePayloadCompatibility(
        srcInterface.port(dataName),
      );
      final typedSource =
          data.clone(name: '${data.name}_input_bridge') as LogicType;
      typedSource <= sourcePayload;
      data <=
          module.addTypedInput(
            portName,
            typedSource,
          );
      valid <= module.addInput(validPortName, srcInterface.port('valid'));
    }
    if (outputIncludesProvider) {
      final sourcePayload = _validatePayloadCompatibility(
        srcInterface.port(dataName),
      );
      final output = module.addTypedOutput(
        portName,
        data.clone as LogicType Function({String? name}),
      );
      output <= data;
      sourcePayload <= output;
      final validOutput = module.addOutput(validPortName);
      validOutput <= valid;
      srcInterface.port('valid') <= validOutput;
    }

    _suppressHandledProviderPorts = true;
    try {
      super.connectIO(
        module,
        srcInterface,
        inputTags: inputTags,
        outputTags: outputTags,
        inOutTags: inOutTags,
        uniquify: uniquify,
      );
    } finally {
      _suppressHandledProviderPorts = false;
    }
  }

  Logic _validatePayloadCompatibility(Logic sourcePayload) {
    if (sourcePayload.width != data.width) {
      throw PortTypeException.forIntendedName(
        data.name,
        'Expected ready/valid payload width ${data.width}, '
        'but found ${sourcePayload.width}.',
      );
    }
    if (sourcePayload is LogicStructure &&
        data is LogicStructure &&
        !_sameDeclaredPayloadShape(data, sourcePayload)) {
      throw PortTypeException.forIntendedName(
        data.name,
        'Expected ready/valid payload shape '
        '${_payloadShapeIdentity(data)}, but found '
        '${_payloadShapeIdentity(sourcePayload)}.',
      );
    }
    return sourcePayload;
  }

  @override
  Map<String, Logic> getPorts([Iterable<PairDirection>? tags]) {
    final selectedPorts = super.getPorts(tags);
    final includesProvider =
        tags == null || tags.any((tag) => tag == PairDirection.fromProvider);
    if (!_suppressHandledProviderPorts || !includesProvider) {
      return selectedPorts;
    }
    return Map<String, Logic>.of(selectedPorts)
      ..remove(data.name)
      ..remove('valid');
  }

  @override
  ReadyValidInterface<LogicType> clone() =>
      ReadyValidInterface(data.clone() as LogicType, contract: contract);
}

bool _sameDeclaredPayloadShape(Logic template, Logic source) {
  if (template is! LogicStructure || source is! LogicStructure) {
    return template is! LogicStructure && source is! LogicStructure;
  }
  final templateStructure = template;
  final sourceStructure = source;
  if (templateStructure is LogicArray || sourceStructure is LogicArray) {
    return templateStructure is LogicArray &&
        sourceStructure is LogicArray &&
        _sameIntList(
          templateStructure.dimensions,
          sourceStructure.dimensions,
        ) &&
        templateStructure.elementWidth == sourceStructure.elementWidth &&
        templateStructure.numUnpackedDimensions ==
            sourceStructure.numUnpackedDimensions;
  }
  if (templateStructure.elements.length != sourceStructure.elements.length) {
    return false;
  }
  for (var index = 0; index < templateStructure.elements.length; index++) {
    final templateElement = templateStructure.elements[index];
    final sourceElement = sourceStructure.elements[index];
    if (templateElement.name != sourceElement.name ||
        templateElement.width != sourceElement.width ||
        !_sameDeclaredPayloadShape(templateElement, sourceElement)) {
      return false;
    }
  }
  return true;
}

bool _sameIntList(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

String _payloadShapeIdentity(Logic logic) {
  if (logic is LogicArray) {
    return 'A${logic.dimensions.join('x')}_'
        'E${logic.elementWidth}_U${logic.numUnpackedDimensions}';
  }
  if (logic is LogicStructure) {
    final fields = logic.elements
        .map(
          (element) => 'N${_encodePayloadFieldName(element.name)}_'
              '${_payloadShapeIdentity(element)}',
        )
        .join('_');
    return 'S${logic.elements.length}_$fields';
  }
  return 'L${logic.width}';
}

String _encodePayloadFieldName(String name) => name.codeUnits
    .map((codeUnit) => codeUnit.toRadixString(16).padLeft(4, '0'))
    .join();

/// A ready/valid interface where ready and valid assert independently.
/// {@category Flow Control}
class ReadyAndValidInterface<LogicType extends Logic>
    extends ReadyValidInterface<LogicType> {
  /// Creates a [ReadyAndValidInterface].
  ReadyAndValidInterface(super.data)
      : super(contract: ReadyValidContract.readyAndValid);

  @override
  ReadyAndValidInterface<LogicType> clone() =>
      ReadyAndValidInterface(data.clone() as LogicType);
}

/// A ready/valid interface where ready must be asserted before valid can be
/// computed.
/// {@category Flow Control}
class ReadyThenValidInterface<LogicType extends Logic>
    extends ReadyValidInterface<LogicType> {
  /// Creates a [ReadyThenValidInterface].
  ReadyThenValidInterface(super.data)
      : super(contract: ReadyValidContract.readyThenValid);

  /// Converts this [ReadyThenValidInterface] to a [ReadyAndValidInterface] by
  /// adding a small FIFO to buffer data.
  ReadyAndValidInterface<LogicType> toDownstreamReadyAndValid(
    Logic clk,
    Logic reset,
  ) {
    final downstream = ReadyAndValidInterface<LogicType>(
      data.clone() as LogicType,
    );

    final readEnable = Logic();
    final fifo = Fifo(
      clk,
      reset,
      depth: 2,
      writeEnable: valid,
      writeData: data,
      readEnable: readEnable,
      name: 'ready_then_valid_to_ready_and_valid_fifo_${data.name}',
    );

    readEnable <= downstream.ready & downstream.valid;
    ready <= ~fifo.full;
    downstream.data <= fifo.readData;
    downstream.valid <= ~fifo.empty;

    return downstream;
  }

  @override
  ReadyThenValidInterface<LogicType> clone() =>
      ReadyThenValidInterface(data.clone() as LogicType);
}

/// A ready/valid interface where ready may be computed after valid.
/// {@category Flow Control}
class ValidThenReadyInterface<LogicType extends Logic>
    extends ReadyValidInterface<LogicType> {
  /// Creates a [ValidThenReadyInterface].
  ValidThenReadyInterface(super.data)
      : super(contract: ReadyValidContract.validThenReady);

  @override
  ValidThenReadyInterface<LogicType> clone() =>
      ValidThenReadyInterface(data.clone() as LogicType);
}

/// A valid-first ready/valid interface that holds an offer stable until it is
/// accepted.
/// {@category Flow Control}
class IrrevocableReadyValidInterface<LogicType extends Logic>
    extends ReadyValidInterface<LogicType> {
  /// Creates an [IrrevocableReadyValidInterface].
  IrrevocableReadyValidInterface(super.data)
      : super(contract: ReadyValidContract.irrevocable);

  @override
  IrrevocableReadyValidInterface<LogicType> clone() =>
      IrrevocableReadyValidInterface(data.clone() as LogicType);
}
