// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_strided_address_generator.dart
// Ready/valid M/N/K strided tensor address generation.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/tensor_strided_address.dart';
import 'package:rohd_hcl/src/inference/tensor_tile_iterator.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// One runtime M/N/K strided address traversal command.
/// {@category Inference}
class TensorAddressCommand extends LogicStructure {
  /// Base byte or word address.
  late final Logic baseAddress;

  /// Number of M coordinates.
  late final Logic mExtent;

  /// Number of N coordinates.
  late final Logic nExtent;

  /// Number of K coordinates.
  late final Logic kExtent;

  /// Address increment for one M step.
  late final Logic mStride;

  /// Address increment for one N step.
  late final Logic nStride;

  /// Address increment for one K step.
  late final Logic kStride;

  /// Caller-selected command identity.
  late final Logic commandId;

  /// Width of addresses and strides.
  final int addressWidth;

  /// Width of M extent and index.
  final int mWidth;

  /// Width of N extent and index.
  final int nWidth;

  /// Width of K extent and index.
  final int kWidth;

  /// Width of [commandId].
  final int commandIdWidth;

  /// Creates a tensor address command shape.
  TensorAddressCommand({
    required this.addressWidth,
    required this.mWidth,
    required this.nWidth,
    required this.kWidth,
    this.commandIdWidth = 8,
    String name = 'tensorAddressCommand',
  }) : super(
          [
            Logic(name: 'baseAddress', width: addressWidth),
            Logic(name: 'mExtent', width: mWidth),
            Logic(name: 'nExtent', width: nWidth),
            Logic(name: 'kExtent', width: kWidth),
            Logic(name: 'mStride', width: addressWidth),
            Logic(name: 'nStride', width: addressWidth),
            Logic(name: 'kStride', width: addressWidth),
            Logic(name: 'commandId', width: commandIdWidth),
          ],
          name: name,
        ) {
    if (addressWidth < 1 ||
        mWidth < 1 ||
        nWidth < 1 ||
        kWidth < 1 ||
        commandIdWidth < 1) {
      throw ArgumentError('Tensor address command widths must be positive.');
    }
    baseAddress = elements[0];
    mExtent = elements[1];
    nExtent = elements[2];
    kExtent = elements[3];
    mStride = elements[4];
    nStride = elements[5];
    kStride = elements[6];
    commandId = elements[7];
  }

  TensorAddressCommand._clone(
    List<Logic> elements, {
    required this.addressWidth,
    required this.mWidth,
    required this.nWidth,
    required this.kWidth,
    required this.commandIdWidth,
    required String name,
  }) : super(elements, name: name) {
    baseAddress = elements[0];
    mExtent = elements[1];
    nExtent = elements[2];
    kExtent = elements[3];
    mStride = elements[4];
    nStride = elements[5];
    kStride = elements[6];
    commandId = elements[7];
  }

  @override
  TensorAddressCommand clone({String? name}) => TensorAddressCommand._clone(
        elements.map((element) => element.clone(name: element.name)).toList(),
        addressWidth: addressWidth,
        mWidth: mWidth,
        nWidth: nWidth,
        kWidth: kWidth,
        commandIdWidth: commandIdWidth,
        name: name ?? this.name,
      );
}

/// One generated tensor address and its M/N/K coordinate.
/// {@category Inference}
class TensorAddressBeat extends LogicStructure {
  /// Generated address.
  late final Logic address;

  /// M coordinate.
  late final Logic mIndex;

  /// N coordinate.
  late final Logic nIndex;

  /// K coordinate.
  late final Logic kIndex;

  /// High for the final coordinate in the command.
  late final Logic last;

  /// High when the full address does not fit [address].
  late final Logic overflow;

  /// Identity copied from the accepted command.
  late final Logic commandId;

  /// Width of [address].
  final int addressWidth;

  /// Width of [mIndex].
  final int mWidth;

  /// Width of [nIndex].
  final int nWidth;

  /// Width of [kIndex].
  final int kWidth;

  /// Width of [commandId].
  final int commandIdWidth;

  /// Creates a tensor-address output shape.
  TensorAddressBeat({
    required this.addressWidth,
    required this.mWidth,
    required this.nWidth,
    required this.kWidth,
    this.commandIdWidth = 8,
    String name = 'tensorAddressBeat',
  }) : super(
          [
            Logic(name: 'address', width: addressWidth),
            Logic(name: 'mIndex', width: mWidth),
            Logic(name: 'nIndex', width: nWidth),
            Logic(name: 'kIndex', width: kWidth),
            Logic(name: 'last'),
            Logic(name: 'overflow'),
            Logic(name: 'commandId', width: commandIdWidth),
          ],
          name: name,
        ) {
    address = elements[0];
    mIndex = elements[1];
    nIndex = elements[2];
    kIndex = elements[3];
    last = elements[4];
    overflow = elements[5];
    commandId = elements[6];
  }

  TensorAddressBeat._clone(
    List<Logic> elements, {
    required this.addressWidth,
    required this.mWidth,
    required this.nWidth,
    required this.kWidth,
    required this.commandIdWidth,
    required String name,
  }) : super(elements, name: name) {
    address = elements[0];
    mIndex = elements[1];
    nIndex = elements[2];
    kIndex = elements[3];
    last = elements[4];
    overflow = elements[5];
    commandId = elements[6];
  }

  @override
  TensorAddressBeat clone({String? name}) => TensorAddressBeat._clone(
        elements.map((element) => element.clone(name: element.name)).toList(),
        addressWidth: addressWidth,
        mWidth: mWidth,
        nWidth: nWidth,
        kWidth: kWidth,
        commandIdWidth: commandIdWidth,
        name: name ?? this.name,
      );
}

/// Generates strided M/N/K addresses under synchronous load/advance actions.
///
/// K is innermost. Load only when [canLoad] is high. With `advance` omitted,
/// one address is consumed every cycle while [busy]. An explicit scheduler may
/// hold an address by withholding advance. Runtime fields are captured on load.
/// Reset abandons the traversal. Zero extents pulse [invalidCommand] and do not
/// start traversal. The next load is legal on the edge after final advancement.
/// {@category Inference}
class TensorStridedAddressGeneratorCore extends Module {
  /// Currently offered address and traversal metadata.
  late final TensorAddressBeat result;

  /// Whether a new command can be loaded.
  Logic get canLoad => output('canLoad');

  /// Multiplier implementation used for index-by-stride products.
  final InferenceMultiplierFunctor multiplierImplementation;

  /// Width of telemetry counters.
  final int counterWidth;

  /// High while a traversal is active.
  Logic get busy => output('busy');

  /// Pulses when an accepted command contains a zero extent.
  Logic get invalidCommand => output('invalidCommand');

  /// Accepted command count.
  Logic get commandsAccepted => output('commandsAccepted');

  /// Accepted generated-address count.
  Logic get addressesAccepted => output('addressesAccepted');

  /// Accepted generated addresses that overflowed.
  Logic get overflowedAddresses => output('overflowedAddresses');

  /// Cycles for which a valid address was stalled.
  Logic get stallCycles => output('stallCycles');

  /// Creates a strided address generator.
  TensorStridedAddressGeneratorCore({
    required Logic clk,
    required Logic reset,
    required TensorAddressCommand command,
    required TensorAddressBeat resultSchema,
    required Logic load,
    Logic? advance,
    Logic? clearCounters,
    this.counterWidth = 32,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    super.name = 'tensor_strided_address_generator_core',
  }) : super(
          definitionName: 'TensorStridedAddressGeneratorCore_'
              'A${command.addressWidth}_'
              'M${command.mWidth}_N${command.nWidth}_'
              'K${command.kWidth}_ID${command.commandIdWidth}_'
              'C${counterWidth}_${multiplierImplementation.identity}',
        ) {
    _validateInterfaces(command, resultSchema);
    if (counterWidth < 1) {
      throw ArgumentError.value(
          counterWidth, 'counterWidth', 'Must be positive.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    command = addTypedInput<TensorAddressCommand>('command', command);
    result = addTypedPayloadOutput(this, 'result', resultSchema);
    final commandAccepted = addInput('load', load);
    final localAdvance = addInput('advance', advance ?? Const(1));
    final iterator = TensorTileIterator(
      clk: localClk,
      reset: localReset,
      start: commandAccepted,
      advance: localAdvance,
      mTiles: command.mExtent,
      nTiles: command.nExtent,
      kTiles: command.kExtent,
      name: '${name}_iterator',
    );
    final retainedBase = Logic(
      name: '${name}_base',
      width: command.addressWidth,
    );
    final retainedMStride = Logic(
      name: '${name}_m_stride',
      width: command.addressWidth,
    );
    final retainedNStride = Logic(
      name: '${name}_n_stride',
      width: command.addressWidth,
    );
    final retainedKStride = Logic(
      name: '${name}_k_stride',
      width: command.addressWidth,
    );
    final retainedId = Logic(
      name: '${name}_command_id',
      width: command.commandIdWidth,
    );
    final address = TensorStridedAddress(
      baseAddress: retainedBase,
      indices: [
        iterator.mIndex,
        iterator.nIndex,
        iterator.kIndex,
      ],
      strides: [retainedMStride, retainedNStride, retainedKStride],
      addressWidth: command.addressWidth,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_address',
    );
    final addressOverflow = address.overflow;

    final outputAccepted = iterator.busy & localAdvance;
    addOutput('canLoad') <= iterator.startReady;
    result.address <= address.address;
    result.mIndex <= iterator.mIndex;
    result.nIndex <= iterator.nIndex;
    result.kIndex <= iterator.kIndex;
    result.last <= iterator.last;
    result.overflow <= addressOverflow;
    result.commandId <= retainedId;
    addOutput('busy') <= iterator.busy;
    addOutput('invalidCommand') <= iterator.invalidExtent;

    Sequential(localClk, reset: localReset, resetValues: {
      retainedBase: 0,
      retainedMStride: 0,
      retainedNStride: 0,
      retainedKStride: 0,
      retainedId: 0,
    }, [
      If(commandAccepted, then: [
        retainedBase < command.baseAddress,
        retainedMStride < command.mStride,
        retainedNStride < command.nStride,
        retainedKStride < command.kStride,
        retainedId < command.commandId,
      ]),
    ]);

    Logic counter(
      String counterName, {
      required Logic enable,
    }) =>
        Accumulator(
          Const(1),
          clk: localClk,
          reset: localReset,
          clear: localClear,
          enable: enable,
          width: counterWidth,
          saturates: true,
          name: '${name}_$counterName',
        ).value;

    addOutput('commandsAccepted', width: counterWidth) <=
        counter('commands_accepted', enable: commandAccepted);
    addOutput('addressesAccepted', width: counterWidth) <=
        counter('addresses_accepted', enable: outputAccepted);
    addOutput('overflowedAddresses', width: counterWidth) <=
        counter(
          'overflowed_addresses',
          enable: outputAccepted & addressOverflow,
        );
    addOutput('stallCycles', width: counterWidth) <=
        counter(
          'stall_cycles',
          enable: iterator.busy & ~localAdvance,
        );
  }

  void _validateInterfaces(
    TensorAddressCommand command,
    TensorAddressBeat resultSchema,
  ) {
    if (resultSchema.addressWidth != command.addressWidth ||
        resultSchema.mWidth != command.mWidth ||
        resultSchema.nWidth != command.nWidth ||
        resultSchema.kWidth != command.kWidth ||
        resultSchema.commandIdWidth != command.commandIdWidth) {
      throw ArgumentError(
          'Tensor command and address stream shapes must match.');
    }
  }
}

/// Ready/valid adapter around [TensorStridedAddressGeneratorCore].
///
/// Ingress acceptance loads the core; egress transfer advances its traversal.
/// Stalled offers and the idle-only load boundary preserve the core's timing.
/// {@category Inference}
class TensorStridedAddressGenerator extends Module {
  late final TensorStridedAddressGeneratorCore _core;

  /// See [TensorStridedAddressGeneratorCore.multiplierImplementation].
  InferenceMultiplierFunctor get multiplierImplementation =>
      _core.multiplierImplementation;

  /// See [TensorStridedAddressGeneratorCore.counterWidth].
  int get counterWidth => _core.counterWidth;

  /// See [TensorStridedAddressGeneratorCore.busy].
  Logic get busy => output('busy');

  /// See [TensorStridedAddressGeneratorCore.invalidCommand].
  Logic get invalidCommand => output('invalidCommand');

  /// See [TensorStridedAddressGeneratorCore.commandsAccepted].
  Logic get commandsAccepted => output('commandsAccepted');

  /// See [TensorStridedAddressGeneratorCore.addressesAccepted].
  Logic get addressesAccepted => output('addressesAccepted');

  /// See [TensorStridedAddressGeneratorCore.overflowedAddresses].
  Logic get overflowedAddresses => output('overflowedAddresses');

  /// See [TensorStridedAddressGeneratorCore.stallCycles].
  Logic get stallCycles => output('stallCycles');

  /// Attaches ready/valid command and address boundaries to the action core.
  TensorStridedAddressGenerator({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<TensorAddressCommand> upstream,
    required ReadyValidInterface<TensorAddressBeat> downstream,
    Logic? clearCounters,
    int counterWidth = 32,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    super.name = 'tensor_strided_address_generator',
  }) : super(
          definitionName: 'TensorStridedAddressGenerator_'
              'A${upstream.data.addressWidth}_'
              'M${upstream.data.mWidth}_N${upstream.data.nWidth}_'
              'K${upstream.data.kWidth}_ID${upstream.data.commandIdWidth}_'
              'C${counterWidth}_${multiplierImplementation.identity}',
        ) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    final input = addPairInterfacePorts(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    final output = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final load = Logic(name: '${name}_load');
    final advance = Logic(name: '${name}_advance');
    final payload = cloneTypedPayload(input.data, name: '${name}_command');
    _core = TensorStridedAddressGeneratorCore(
      clk: localClk,
      reset: localReset,
      command: payload,
      resultSchema: output.data,
      load: load,
      advance: advance,
      clearCounters: localClear,
      counterWidth: counterWidth,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_core',
    );
    ReadyValidIngressAttachmentPolicy<TensorAddressCommand>(
      supportsSameCycleReplacement: true,
    ).attach(
      upstream: input,
      canAccept: _core.canLoad,
      accept: load,
      payload: payload,
    );
    ReadyValidEgressAttachmentPolicy<TensorAddressBeat>().attach(
      downstream: output,
      offerValid: _core.busy,
      payload: _core.result,
      transfer: advance,
    );
    for (final port in [
      'busy',
      'invalidCommand',
      'commandsAccepted',
      'addressesAccepted',
      'overflowedAddresses',
      'stallCycles',
    ]) {
      final signal = _core.output(port);
      addOutput(port, width: signal.width) <= signal;
    }
  }
}

/// Computes one tensor address in software.
BigInt tensorStridedAddress({
  required BigInt baseAddress,
  required int mIndex,
  required int nIndex,
  required int kIndex,
  required BigInt mStride,
  required BigInt nStride,
  required BigInt kStride,
}) =>
    baseAddress +
    BigInt.from(mIndex) * mStride +
    BigInt.from(nIndex) * nStride +
    BigInt.from(kIndex) * kStride;
