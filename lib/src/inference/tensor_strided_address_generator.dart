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
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/tensor_strided_address.dart';
import 'package:rohd_hcl/src/inference/tensor_tile_iterator.dart';

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

/// Generates a retained ready/valid stream of strided M/N/K addresses.
///
/// K is the innermost traversal dimension. A downstream stall retains the
/// address and all coordinates. Runtime command fields are captured on
/// acceptance and remain independent of later upstream changes.
/// {@category Inference}
class TensorStridedAddressGenerator extends Module {
  late final ReadyValidInterface<TensorAddressCommand> _upstream;
  late final IrrevocableReadyValidInterface<TensorAddressBeat> _downstream;

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
  TensorStridedAddressGenerator({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<TensorAddressCommand> upstream,
    required ReadyValidInterface<TensorAddressBeat> downstream,
    Logic? clearCounters,
    this.counterWidth = 32,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    super.name = 'tensor_strided_address_generator',
  }) : super(
          definitionName: 'TensorStridedAddressGenerator_'
              'A${upstream.data.addressWidth}_'
              'M${upstream.data.mWidth}_N${upstream.data.nWidth}_'
              'K${upstream.data.kWidth}_ID${upstream.data.commandIdWidth}_'
              'C${counterWidth}_${multiplierImplementation.identity}',
        ) {
    _validateInterfaces(upstream, downstream);
    if (counterWidth < 1) {
      throw ArgumentError.value(
          counterWidth, 'counterWidth', 'Must be positive.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    _upstream = addPairInterfacePorts(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    _downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<TensorAddressBeat>(
        downstream.data.clone(),
      ),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final commandAccepted = _upstream.accepted;
    final outputAccepted = _downstream.accepted;
    final iterator = TensorTileIterator(
      clk: localClk,
      reset: localReset,
      start: commandAccepted,
      advance: outputAccepted,
      mTiles: _upstream.data.mExtent,
      nTiles: _upstream.data.nExtent,
      kTiles: _upstream.data.kExtent,
      name: '${name}_iterator',
    );
    final retainedBase = Logic(
      name: '${name}_base',
      width: _upstream.data.addressWidth,
    );
    final retainedMStride = Logic(
      name: '${name}_m_stride',
      width: _upstream.data.addressWidth,
    );
    final retainedNStride = Logic(
      name: '${name}_n_stride',
      width: _upstream.data.addressWidth,
    );
    final retainedKStride = Logic(
      name: '${name}_k_stride',
      width: _upstream.data.addressWidth,
    );
    final retainedId = Logic(
      name: '${name}_command_id',
      width: _upstream.data.commandIdWidth,
    );
    final address = TensorStridedAddress(
      baseAddress: retainedBase,
      indices: [
        iterator.mIndex,
        iterator.nIndex,
        iterator.kIndex,
      ],
      strides: [retainedMStride, retainedNStride, retainedKStride],
      addressWidth: _upstream.data.addressWidth,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_address',
    );
    final addressOverflow = address.overflow;

    _upstream.ready <= iterator.startReady;
    _downstream.valid <= iterator.busy;
    _downstream.data.address <= address.address;
    _downstream.data.mIndex <= iterator.mIndex;
    _downstream.data.nIndex <= iterator.nIndex;
    _downstream.data.kIndex <= iterator.kIndex;
    _downstream.data.last <= iterator.last;
    _downstream.data.overflow <= addressOverflow;
    _downstream.data.commandId <= retainedId;
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
        retainedBase < _upstream.data.baseAddress,
        retainedMStride < _upstream.data.mStride,
        retainedNStride < _upstream.data.nStride,
        retainedKStride < _upstream.data.kStride,
        retainedId < _upstream.data.commandId,
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
          enable: _downstream.valid & ~_downstream.ready,
        );
  }

  void _validateInterfaces(
    ReadyValidInterface<TensorAddressCommand> upstream,
    ReadyValidInterface<TensorAddressBeat> downstream,
  ) {
    if (downstream.data.addressWidth != upstream.data.addressWidth ||
        downstream.data.mWidth != upstream.data.mWidth ||
        downstream.data.nWidth != upstream.data.nWidth ||
        downstream.data.kWidth != upstream.data.kWidth ||
        downstream.data.commandIdWidth != upstream.data.commandIdWidth) {
      throw ArgumentError(
          'Tensor command and address stream shapes must match.');
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
