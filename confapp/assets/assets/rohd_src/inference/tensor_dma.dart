// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_dma.dart
// Ready/valid strided tensor copy engine.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/tensor_scratchpad.dart';
import 'package:rohd_hcl/src/inference/tensor_strided_address_generator.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// One strided tensor-copy command.
///
/// Source and destination addresses share the same M/N/K extents but have
/// independent bases and strides.
/// {@category Inference}
class TensorDmaCommand extends LogicStructure {
  /// First source address.
  late final Logic sourceBaseAddress;

  /// First destination address.
  late final Logic destinationBaseAddress;

  /// Number of M coordinates.
  late final Logic mExtent;

  /// Number of N coordinates.
  late final Logic nExtent;

  /// Number of K coordinates.
  late final Logic kExtent;

  /// Source-address increment for one M step.
  late final Logic sourceMStride;

  /// Source-address increment for one N step.
  late final Logic sourceNStride;

  /// Source-address increment for one K step.
  late final Logic sourceKStride;

  /// Destination-address increment for one M step.
  late final Logic destinationMStride;

  /// Destination-address increment for one N step.
  late final Logic destinationNStride;

  /// Destination-address increment for one K step.
  late final Logic destinationKStride;

  /// Caller-selected command identity.
  late final Logic commandId;

  /// Width of source addresses and strides.
  final int sourceAddressWidth;

  /// Width of destination addresses and strides.
  final int destinationAddressWidth;

  /// Width of M extents and indices.
  final int mWidth;

  /// Width of N extents and indices.
  final int nWidth;

  /// Width of K extents and indices.
  final int kWidth;

  /// Width of [commandId].
  final int commandIdWidth;

  /// Creates a tensor DMA command shape.
  TensorDmaCommand({
    required this.sourceAddressWidth,
    required this.destinationAddressWidth,
    required this.mWidth,
    required this.nWidth,
    required this.kWidth,
    this.commandIdWidth = 8,
    String name = 'tensorDmaCommand',
  }) : super(
          [
            Logic(name: 'sourceBaseAddress', width: sourceAddressWidth),
            Logic(
              name: 'destinationBaseAddress',
              width: destinationAddressWidth,
            ),
            Logic(name: 'mExtent', width: mWidth),
            Logic(name: 'nExtent', width: nWidth),
            Logic(name: 'kExtent', width: kWidth),
            Logic(name: 'sourceMStride', width: sourceAddressWidth),
            Logic(name: 'sourceNStride', width: sourceAddressWidth),
            Logic(name: 'sourceKStride', width: sourceAddressWidth),
            Logic(
              name: 'destinationMStride',
              width: destinationAddressWidth,
            ),
            Logic(
              name: 'destinationNStride',
              width: destinationAddressWidth,
            ),
            Logic(
              name: 'destinationKStride',
              width: destinationAddressWidth,
            ),
            Logic(name: 'commandId', width: commandIdWidth),
          ],
          name: name,
        ) {
    if (sourceAddressWidth < 1 ||
        destinationAddressWidth < 1 ||
        mWidth < 1 ||
        nWidth < 1 ||
        kWidth < 1 ||
        commandIdWidth < 1) {
      throw ArgumentError('Tensor DMA command widths must be positive.');
    }
    sourceBaseAddress = elements[0];
    destinationBaseAddress = elements[1];
    mExtent = elements[2];
    nExtent = elements[3];
    kExtent = elements[4];
    sourceMStride = elements[5];
    sourceNStride = elements[6];
    sourceKStride = elements[7];
    destinationMStride = elements[8];
    destinationNStride = elements[9];
    destinationKStride = elements[10];
    commandId = elements[11];
  }

  TensorDmaCommand._clone(
    List<Logic> elements, {
    required this.sourceAddressWidth,
    required this.destinationAddressWidth,
    required this.mWidth,
    required this.nWidth,
    required this.kWidth,
    required this.commandIdWidth,
    required String name,
  }) : super(elements, name: name) {
    sourceBaseAddress = elements[0];
    destinationBaseAddress = elements[1];
    mExtent = elements[2];
    nExtent = elements[3];
    kExtent = elements[4];
    sourceMStride = elements[5];
    sourceNStride = elements[6];
    sourceKStride = elements[7];
    destinationMStride = elements[8];
    destinationNStride = elements[9];
    destinationKStride = elements[10];
    commandId = elements[11];
  }

  @override
  TensorDmaCommand clone({String? name}) => TensorDmaCommand._clone(
        elements.map((element) => element.clone(name: element.name)).toList(),
        sourceAddressWidth: sourceAddressWidth,
        destinationAddressWidth: destinationAddressWidth,
        mWidth: mWidth,
        nWidth: nWidth,
        kWidth: kWidth,
        commandIdWidth: commandIdWidth,
        name: name ?? this.name,
      );
}

/// Completion and aggregate error status for one tensor DMA command.
/// {@category Inference}
class TensorDmaCompletion extends LogicStructure {
  /// Identity copied from the accepted command.
  late final Logic commandId;

  /// Number of destination writes accepted.
  late final Logic transferredCount;

  /// High when any command or transfer error occurred.
  late final Logic error;

  /// High when any runtime extent was zero.
  late final Logic invalidCommand;

  /// High when any source response reported an error.
  late final Logic sourceError;

  /// High when any source or destination address was invalid.
  late final Logic addressError;

  /// High when a source response tag did not match the issued request.
  late final Logic protocolError;

  /// Width of [commandId].
  final int commandIdWidth;

  /// Width of [transferredCount].
  final int countWidth;

  /// Creates a tensor DMA completion shape.
  TensorDmaCompletion({
    required this.commandIdWidth,
    required this.countWidth,
    String name = 'tensorDmaCompletion',
  }) : super(
          [
            Logic(name: 'commandId', width: commandIdWidth),
            Logic(name: 'transferredCount', width: countWidth),
            Logic(name: 'error'),
            Logic(name: 'invalidCommand'),
            Logic(name: 'sourceError'),
            Logic(name: 'addressError'),
            Logic(name: 'protocolError'),
          ],
          name: name,
        ) {
    if (commandIdWidth < 1 || countWidth < 1) {
      throw ArgumentError('Tensor DMA completion widths must be positive.');
    }
    commandId = elements[0];
    transferredCount = elements[1];
    error = elements[2];
    invalidCommand = elements[3];
    sourceError = elements[4];
    addressError = elements[5];
    protocolError = elements[6];
  }

  TensorDmaCompletion._clone(
    List<Logic> elements, {
    required this.commandIdWidth,
    required this.countWidth,
    required String name,
  }) : super(elements, name: name) {
    commandId = elements[0];
    transferredCount = elements[1];
    error = elements[2];
    invalidCommand = elements[3];
    sourceError = elements[4];
    addressError = elements[5];
    protocolError = elements[6];
  }

  @override
  TensorDmaCompletion clone({String? name}) => TensorDmaCompletion._clone(
        elements.map((element) => element.clone(name: element.name)).toList(),
        commandIdWidth: commandIdWidth,
        countWidth: countWidth,
        name: name ?? this.name,
      );
}

/// Returns the lossless width for a DMA command's transferred-beat count.
int tensorDmaCountWidth({
  required int mWidth,
  required int nWidth,
  required int kWidth,
}) {
  if (mWidth < 1 || nWidth < 1 || kWidth < 1) {
    throw ArgumentError('Tensor DMA extent widths must be positive.');
  }
  return max(1, mWidth + nWidth + kWidth);
}

/// Copies a strided tensor through tagged ready/valid memory transactions.
///
/// This reference engine allows one source read to be outstanding and retains
/// one destination write. A source read response completes before the next
/// address is issued. Source-response errors and tag mismatches suppress the
/// corresponding destination write while the engine drains the full command.
/// Address overflow or an optional depth violation likewise skips that beat.
///
/// Destination acceptance is the write-completion point; destinations that
/// require a later error response should adapt that protocol before this
/// engine.
///
/// Source and destination words share a compatible declared schema [T].
/// The retained write buffer preserves that schema; no numeric conversion
/// occurs when copying a word.
/// {@category Inference}
class TensorDmaEngine<T extends Logic> extends Module {
  /// Optional number of valid source addresses.
  final int? sourceDepth;

  /// Optional number of valid destination addresses.
  final int? destinationDepth;

  /// Width of telemetry counters.
  final int counterWidth;

  /// Multiplier implementation used by both address generators.
  final InferenceMultiplierFunctor multiplierImplementation;

  late final ReadyValidInterface<TensorDmaCommand> _command;
  late final IrrevocableReadyValidInterface<TensorScratchpadReadRequest>
      _sourceReadRequest;
  late final ReadyValidInterface<TensorScratchpadReadResponse<T>>
      _sourceReadResponse;
  late final IrrevocableReadyValidInterface<TensorScratchpadWriteRequest<T>>
      _destinationWriteRequest;
  late final IrrevocableReadyValidInterface<TensorDmaCompletion> _completion;

  /// High from command acceptance through completion acceptance.
  Logic get busy => output('busy');

  /// Number of accepted commands.
  Logic get commandsAccepted => output('commandsAccepted');

  /// Number of accepted source read requests.
  Logic get readRequestsIssued => output('readRequestsIssued');

  /// Number of accepted destination writes.
  Logic get writesCompleted => output('writesCompleted');

  /// Number of accepted completions carrying an error.
  Logic get failedCommands => output('failedCommands');

  /// Cycles for which a source read request was stalled.
  Logic get readStallCycles => output('readStallCycles');

  /// Cycles for which a destination write request was stalled.
  Logic get writeStallCycles => output('writeStallCycles');

  /// Cycles for which a completion was stalled.
  Logic get completionStallCycles => output('completionStallCycles');

  /// Creates a single-outstanding strided tensor DMA engine.
  TensorDmaEngine({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<TensorDmaCommand> command,
    required ReadyValidInterface<TensorScratchpadReadRequest> sourceReadRequest,
    required ReadyValidInterface<TensorScratchpadReadResponse<T>>
        sourceReadResponse,
    required ReadyValidInterface<TensorScratchpadWriteRequest<T>>
        destinationWriteRequest,
    required ReadyValidInterface<TensorDmaCompletion> completion,
    this.sourceDepth,
    this.destinationDepth,
    Logic? clearCounters,
    this.counterWidth = 32,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    super.name = 'tensor_dma_engine',
  }) : super(
          definitionName: schemaQualifiedDefinitionName(
              'TensorDmaEngine_'
              'SA${command.data.sourceAddressWidth}_'
              'DA${command.data.destinationAddressWidth}_'
              'M${command.data.mWidth}_N${command.data.nWidth}_'
              'K${command.data.kWidth}_ID${command.data.commandIdWidth}_'
              'D${sourceReadResponse.data.dataWidth}_'
              'T${sourceReadRequest.data.tagWidth}_'
              'SD${sourceDepth ?? 0}_DD${destinationDepth ?? 0}_'
              'C${counterWidth}_${multiplierImplementation.identity}_',
              [
                sourceReadResponse.data.data,
              ]),
        ) {
    final countWidth = tensorDmaCountWidth(
      mWidth: command.data.mWidth,
      nWidth: command.data.nWidth,
      kWidth: command.data.kWidth,
    );
    _validateInterfaces(
      command,
      sourceReadRequest,
      sourceReadResponse,
      destinationWriteRequest,
      completion,
      countWidth,
    );
    if (!rohdPayloadsCompatible([
      sourceReadResponse.data.data,
      destinationWriteRequest.data.data,
    ], allowRenamedClones: true)) {
      throw ArgumentError('Tensor DMA word schemas do not match.');
    }
    _validateDepth(sourceDepth, command.data.sourceAddressWidth, 'sourceDepth');
    _validateDepth(
      destinationDepth,
      command.data.destinationAddressWidth,
      'destinationDepth',
    );
    if (counterWidth < 1) {
      throw ArgumentError.value(
        counterWidth,
        'counterWidth',
        'Must be positive.',
      );
    }

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    _command = addPairInterface(
      command,
      PairRole.consumer,
      uniquify: (original) => 'command_$original',
    );
    _sourceReadRequest = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(sourceReadRequest.data.clone()),
      sourceReadRequest,
      PairRole.provider,
      uniquify: (original) => 'source_read_request_$original',
    );
    _sourceReadResponse = addPairInterface(
      sourceReadResponse,
      PairRole.consumer,
      uniquify: (original) => 'source_read_response_$original',
    );
    _destinationWriteRequest = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(destinationWriteRequest.data.clone()),
      destinationWriteRequest,
      PairRole.provider,
      uniquify: (original) => 'destination_write_request_$original',
    );
    _completion = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(completion.data.clone()),
      completion,
      PairRole.provider,
      uniquify: (original) => 'completion_$original',
    );

    final active = Logic(name: '${name}_active');
    final readOutstanding = Logic(name: '${name}_read_outstanding');
    final writePending = Logic(name: '${name}_write_pending');
    final completionPending = Logic(name: '${name}_completion_pending');
    final pendingDestination = Logic(
      name: '${name}_pending_destination',
      width: command.data.destinationAddressWidth,
    );
    final pendingLast = Logic(name: '${name}_pending_last');
    final pendingReadTag = Logic(
      name: '${name}_pending_read_tag',
      width: sourceReadRequest.data.tagWidth,
    );
    final nextReadTag = Logic(
      name: '${name}_next_read_tag',
      width: sourceReadRequest.data.tagWidth,
    );
    final bufferedWriteData = cloneTypedPayload<T>(
        _sourceReadResponse.data.data,
        name: '${name}_buffered_write_data');
    final transferredCount =
        Logic(name: '${name}_transferred_count', width: countWidth);
    final completionCount =
        Logic(name: '${name}_completion_count', width: countWidth);
    final completionCommandId = Logic(
      name: '${name}_completion_command_id',
      width: command.data.commandIdWidth,
    );
    final invalidCommandSeen = Logic(name: '${name}_invalid_command_seen');
    final sourceErrorSeen = Logic(name: '${name}_source_error_seen');
    final addressErrorSeen = Logic(name: '${name}_address_error_seen');
    final protocolErrorSeen = Logic(name: '${name}_protocol_error_seen');

    final sourceAddressCommand = TensorAddressCommand(
      addressWidth: command.data.sourceAddressWidth,
      mWidth: command.data.mWidth,
      nWidth: command.data.nWidth,
      kWidth: command.data.kWidth,
      commandIdWidth: command.data.commandIdWidth,
      name: '${name}_source_address_command',
    );
    final destinationAddressCommand = TensorAddressCommand(
      addressWidth: command.data.destinationAddressWidth,
      mWidth: command.data.mWidth,
      nWidth: command.data.nWidth,
      kWidth: command.data.kWidth,
      commandIdWidth: command.data.commandIdWidth,
      name: '${name}_destination_address_command',
    );
    final sourceAddressSchema = TensorAddressBeat(
      addressWidth: command.data.sourceAddressWidth,
      mWidth: command.data.mWidth,
      nWidth: command.data.nWidth,
      kWidth: command.data.kWidth,
      commandIdWidth: command.data.commandIdWidth,
      name: '${name}_source_address',
    );
    final destinationAddressSchema = TensorAddressBeat(
      addressWidth: command.data.destinationAddressWidth,
      mWidth: command.data.mWidth,
      nWidth: command.data.nWidth,
      kWidth: command.data.kWidth,
      commandIdWidth: command.data.commandIdWidth,
      name: '${name}_destination_address',
    );
    final loadAddresses = Logic(name: '${name}_load_addresses');
    final advanceAddresses = Logic(name: '${name}_advance_addresses');
    _driveAddressCommand(
      sourceAddressCommand,
      _command.data,
      source: true,
    );
    _driveAddressCommand(
      destinationAddressCommand,
      _command.data,
      source: false,
    );
    final sourceAddresses = TensorStridedAddressGeneratorCore(
      clk: localClk,
      reset: localReset,
      command: sourceAddressCommand,
      resultSchema: sourceAddressSchema,
      load: loadAddresses,
      advance: advanceAddresses,
      clearCounters: localClear,
      counterWidth: counterWidth,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_source_addresses',
    );
    final destinationAddresses = TensorStridedAddressGeneratorCore(
      clk: localClk,
      reset: localReset,
      command: destinationAddressCommand,
      resultSchema: destinationAddressSchema,
      load: loadAddresses,
      advance: advanceAddresses,
      clearCounters: localClear,
      counterWidth: counterWidth,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_destination_addresses',
    );

    final sourceAddressBeat = sourceAddresses.result;
    final destinationAddressBeat = destinationAddresses.result;
    final idle =
        ~active & ~readOutstanding & ~writePending & ~completionPending;
    _command.ready <=
        idle & sourceAddresses.canLoad & destinationAddresses.canLoad;
    final commandAccepted = _command.accepted;
    loadAddresses <= commandAccepted;
    final invalidExtent = _command.data.mExtent.eq(0) |
        _command.data.nExtent.eq(0) |
        _command.data.kExtent.eq(0);

    final canIssueAddress = active & ~readOutstanding & ~writePending;
    final addressPairValid = sourceAddresses.busy & destinationAddresses.busy;
    final sourceInRange = _addressInRange(
      sourceAddressBeat.address,
      sourceDepth,
    );
    final destinationInRange = _addressInRange(
      destinationAddressBeat.address,
      destinationDepth,
    );
    final currentAddressError = sourceAddressBeat.overflow |
        destinationAddressBeat.overflow |
        ~sourceInRange |
        ~destinationInRange;
    final skipAddress =
        addressPairValid & canIssueAddress & currentAddressError;

    _sourceReadRequest.valid <=
        addressPairValid & canIssueAddress & ~currentAddressError;
    _sourceReadRequest.data.address <= sourceAddressBeat.address;
    _sourceReadRequest.data.tag <= nextReadTag;
    final readRequestAccepted = _sourceReadRequest.accepted;
    final addressPairAccepted = skipAddress | readRequestAccepted;
    advanceAddresses <= addressPairAccepted;

    _sourceReadResponse.ready <= readOutstanding & ~writePending;
    final readResponseAccepted = _sourceReadResponse.accepted;
    final responseTagMismatch =
        _sourceReadResponse.data.tag.neq(pendingReadTag);
    final responseFailed = _sourceReadResponse.data.error | responseTagMismatch;

    _destinationWriteRequest.valid <= writePending;
    _destinationWriteRequest.data.address <= pendingDestination;
    _destinationWriteRequest.data.data <= bufferedWriteData;
    final writeAccepted = _destinationWriteRequest.accepted;

    _completion.valid <= completionPending;
    _completion.data.commandId <= completionCommandId;
    _completion.data.transferredCount <= completionCount;
    _completion.data.invalidCommand <= invalidCommandSeen;
    _completion.data.sourceError <= sourceErrorSeen;
    _completion.data.addressError <= addressErrorSeen;
    _completion.data.protocolError <= protocolErrorSeen;
    _completion.data.error <=
        invalidCommandSeen |
            sourceErrorSeen |
            addressErrorSeen |
            protocolErrorSeen;
    final completionAccepted = _completion.accepted;
    addOutput('busy') <= ~idle;

    Sequential(localClk, reset: localReset, resetValues: {
      active: 0,
      readOutstanding: 0,
      writePending: 0,
      completionPending: 0,
      pendingDestination: 0,
      pendingLast: 0,
      pendingReadTag: 0,
      nextReadTag: 0,
      bufferedWriteData: 0,
      transferredCount: 0,
      completionCount: 0,
      completionCommandId: 0,
      invalidCommandSeen: 0,
      sourceErrorSeen: 0,
      addressErrorSeen: 0,
      protocolErrorSeen: 0,
    }, [
      If(completionAccepted, then: [completionPending < 0]),
      If(commandAccepted, then: [
        active < ~invalidExtent,
        completionPending < invalidExtent,
        transferredCount < 0,
        completionCount < 0,
        completionCommandId < _command.data.commandId,
        invalidCommandSeen < invalidExtent,
        sourceErrorSeen < 0,
        addressErrorSeen < 0,
        protocolErrorSeen < 0,
      ]),
      If(skipAddress, then: [
        addressErrorSeen < 1,
        If(sourceAddressBeat.last, then: [
          active < 0,
          completionPending < 1,
          completionCount < transferredCount,
        ]),
      ]),
      If(readRequestAccepted, then: [
        readOutstanding < 1,
        pendingDestination < destinationAddressBeat.address,
        pendingLast < sourceAddressBeat.last,
        pendingReadTag < nextReadTag,
        nextReadTag < nextReadTag + 1,
      ]),
      If(readResponseAccepted, then: [
        readOutstanding < 0,
        If(responseFailed, then: [
          sourceErrorSeen < sourceErrorSeen | _sourceReadResponse.data.error,
          protocolErrorSeen < protocolErrorSeen | responseTagMismatch,
          If(pendingLast, then: [
            active < 0,
            completionPending < 1,
            completionCount < transferredCount,
          ]),
        ], orElse: [
          writePending < 1,
          bufferedWriteData < _sourceReadResponse.data.data,
        ]),
      ]),
      If(writeAccepted, then: [
        writePending < 0,
        transferredCount < transferredCount + 1,
        If(pendingLast, then: [
          active < 0,
          completionPending < 1,
          completionCount < transferredCount + 1,
        ]),
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
    addOutput('readRequestsIssued', width: counterWidth) <=
        counter('read_requests_issued', enable: readRequestAccepted);
    addOutput('writesCompleted', width: counterWidth) <=
        counter('writes_completed', enable: writeAccepted);
    addOutput('failedCommands', width: counterWidth) <=
        counter(
          'failed_commands',
          enable: completionAccepted & _completion.data.error,
        );
    addOutput('readStallCycles', width: counterWidth) <=
        counter(
          'read_stall_cycles',
          enable: _sourceReadRequest.valid & ~_sourceReadRequest.ready,
        );
    addOutput('writeStallCycles', width: counterWidth) <=
        counter(
          'write_stall_cycles',
          enable:
              _destinationWriteRequest.valid & ~_destinationWriteRequest.ready,
        );
    addOutput('completionStallCycles', width: counterWidth) <=
        counter(
          'completion_stall_cycles',
          enable: _completion.valid & ~_completion.ready,
        );
  }

  static void _driveAddressCommand(
    TensorAddressCommand addressCommand,
    TensorDmaCommand command, {
    required bool source,
  }) {
    addressCommand.baseAddress <=
        (source ? command.sourceBaseAddress : command.destinationBaseAddress);
    addressCommand.mExtent <= command.mExtent;
    addressCommand.nExtent <= command.nExtent;
    addressCommand.kExtent <= command.kExtent;
    addressCommand.mStride <=
        (source ? command.sourceMStride : command.destinationMStride);
    addressCommand.nStride <=
        (source ? command.sourceNStride : command.destinationNStride);
    addressCommand.kStride <=
        (source ? command.sourceKStride : command.destinationKStride);
    addressCommand.commandId <= command.commandId;
  }

  static Logic _addressInRange(Logic address, int? depth) {
    if (depth == null || BigInt.from(depth) == (BigInt.one << address.width)) {
      return Const(1);
    }
    return address.lt(Const(depth, width: address.width));
  }

  static void _validateDepth(int? depth, int addressWidth, String name) {
    if (depth == null) {
      return;
    }
    final maximumDepth = BigInt.one << addressWidth;
    if (depth < 1 || BigInt.from(depth) > maximumDepth) {
      throw ArgumentError.value(
        depth,
        name,
        'Must fit the configured address width.',
      );
    }
  }

  void _validateInterfaces(
    ReadyValidInterface<TensorDmaCommand> command,
    ReadyValidInterface<TensorScratchpadReadRequest> sourceReadRequest,
    ReadyValidInterface<TensorScratchpadReadResponse<T>> sourceReadResponse,
    ReadyValidInterface<TensorScratchpadWriteRequest<T>>
        destinationWriteRequest,
    ReadyValidInterface<TensorDmaCompletion> completion,
    int countWidth,
  ) {
    if (sourceReadRequest.data.addressWidth !=
            command.data.sourceAddressWidth ||
        destinationWriteRequest.data.addressWidth !=
            command.data.destinationAddressWidth ||
        sourceReadRequest.data.tagWidth != sourceReadResponse.data.tagWidth ||
        sourceReadResponse.data.dataWidth !=
            destinationWriteRequest.data.dataWidth ||
        completion.data.commandIdWidth != command.data.commandIdWidth ||
        completion.data.countWidth != countWidth) {
      throw ArgumentError('Tensor DMA interface payload shapes do not match.');
    }
  }
}
