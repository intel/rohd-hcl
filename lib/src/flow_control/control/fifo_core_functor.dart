// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_core_functor.dart
// Typed construction seam for the synchronous FIFO core.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/control/hardware_core_functor.dart';
import 'package:rohd_hcl/src/flow_control/storage/fifo.dart';

/// Action semantics and configured shape of a [FifoCoreFunctor].
/// {@category Flow Control}
class FifoCoreCapabilities implements HardwareCoreCapabilities {
  /// Number of retained entries.
  final int depth;

  /// Whether a dequeue can make room for an enqueue while already full.
  final bool supportsFullReplacement;

  /// Whether an empty simultaneous enqueue/dequeue bypasses storage.
  final bool supportsEmptyBypass;

  /// Whether slot release excludes an empty bypass transfer.
  final bool slotReleaseRequiresStoredEntry;

  /// Whether the core generates an occupancy output.
  final bool generatesOccupancy;

  /// Whether the core generates an action-error output.
  final bool generatesError;

  /// Creates FIFO capability metadata.
  const FifoCoreCapabilities({
    required this.depth,
    required this.supportsEmptyBypass,
    required this.generatesOccupancy,
    required this.generatesError,
    this.supportsFullReplacement = true,
    this.slotReleaseRequiresStoredEntry = true,
  });

  @override
  String get configurationIdentity => 'D${depth}_'
      'R${supportsFullReplacement ? 1 : 0}_'
      'B${supportsEmptyBypass ? 1 : 0}_'
      'S${slotReleaseRequiresStoredEntry ? 1 : 0}_'
      'O${generatesOccupancy ? 1 : 0}_'
      'E${generatesError ? 1 : 0}';
}

/// Capabilities required by a FIFO construction request.
/// {@category Flow Control}
class FifoCoreRequirements {
  /// Require legal replacement on a full-cycle dequeue.
  final bool fullReplacement;

  /// Require direct enqueue/dequeue bypass while empty.
  final bool emptyBypass;

  /// Require slot-release pulses to represent stored entries only.
  final bool storedSlotRelease;

  /// Creates FIFO capability requirements.
  const FifoCoreRequirements({
    this.fullReplacement = false,
    this.emptyBypass = false,
    this.storedSlotRelease = true,
  });

  void _validate(FifoCoreCapabilities capabilities) {
    if (fullReplacement && !capabilities.supportsFullReplacement) {
      throw ArgumentError(
        'The FIFO functor does not support same-cycle full replacement.',
      );
    }
    if (emptyBypass && !capabilities.supportsEmptyBypass) {
      throw ArgumentError(
        'The FIFO functor does not support empty enqueue/dequeue bypass.',
      );
    }
    if (storedSlotRelease && !capabilities.slotReleaseRequiresStoredEntry) {
      throw ArgumentError(
        'The FIFO functor does not distinguish stored slot release.',
      );
    }
  }
}

/// Wrapper-owned actions and payload used to construct a [Fifo].
/// {@category Flow Control}
class FifoCoreRequest<LogicType extends Logic> {
  /// Core clock.
  final Logic clk;

  /// Synchronous core reset.
  final Logic reset;

  /// Enqueue action.
  final Logic enqueue;

  /// Payload sampled by [enqueue].
  final LogicType payload;

  /// Dequeue action.
  final Logic dequeue;

  /// Action semantics required by the caller.
  final FifoCoreRequirements requirements;

  /// Creates a typed FIFO construction request.
  const FifoCoreRequest({
    required this.clk,
    required this.reset,
    required this.enqueue,
    required this.payload,
    required this.dequeue,
    this.requirements = const FifoCoreRequirements(),
  });
}

/// Constructed FIFO and its output-only protocol-neutral binding.
/// {@category Flow Control}
class FifoCoreBinding<LogicType extends Logic> implements HardwareCoreBinding {
  @override
  final Fifo<LogicType> module;

  /// Capabilities validated for this construction.
  final FifoCoreCapabilities capabilities;

  /// Creates a FIFO binding.
  const FifoCoreBinding(this.module, this.capabilities);

  /// High when an enqueue action is currently legal.
  Logic get canEnqueue => module.canEnqueue;

  /// High when [output] is a legal dequeue payload.
  Logic get outputValid => module.outputValid;

  /// High when a dequeue action is currently legal.
  Logic get canDequeue => module.outputValid;

  /// Current FIFO head or bypass payload.
  LogicType get output => module.readData;

  /// Pulse for a dequeue that releases a retained storage slot.
  Logic get slotReleased => module.slotReleased;

  /// High when every retained entry is occupied.
  Logic get full => module.full;

  /// High when no entry is retained.
  Logic get empty => module.empty;

  /// Number of retained entries when occupancy generation is enabled.
  Logic? get occupancy => module.occupancy;

  /// FIFO action violation when error generation is enabled.
  Logic? get error => module.error;
}

/// Constructs typed synchronous [Fifo] cores.
/// {@category Flow Control}
class FifoCoreFunctor<LogicType extends Logic> extends HardwareCoreFunctor<
    FifoCoreRequest<LogicType>, FifoCoreBinding<LogicType>> {
  /// Generate the optional occupancy output.
  final bool generateOccupancy;

  /// Generate the optional action-error output.
  final bool generateError;

  @override
  final FifoCoreCapabilities capabilities;

  /// Creates a configured FIFO construction functor.
  FifoCoreFunctor({
    required int depth,
    this.generateOccupancy = false,
    this.generateError = false,
    bool generateBypass = false,
  }) : capabilities = FifoCoreCapabilities(
          depth: depth,
          supportsEmptyBypass: generateBypass,
          generatesOccupancy: generateOccupancy,
          generatesError: generateError,
        ) {
    if (depth < 1) {
      throw ArgumentError.value(depth, 'depth', 'Must be at least one.');
    }
  }

  @override
  String get identity => 'fifo_core';

  @override
  FifoCoreBinding<LogicType> construct(
    FifoCoreRequest<LogicType> request, {
    required String name,
  }) {
    for (final control in {
      'clk': request.clk,
      'reset': request.reset,
      'enqueue': request.enqueue,
      'dequeue': request.dequeue,
    }.entries) {
      if (control.value.width != 1) {
        throw ArgumentError.value(
          control.value,
          control.key,
          'FIFO controls must be one bit.',
        );
      }
    }
    request.requirements._validate(capabilities);
    final payloadShapeIdentity = _payloadShapeIdentity(request.payload);
    final fifo = Fifo<LogicType>(
      request.clk,
      request.reset,
      writeEnable: request.enqueue,
      writeData: request.payload,
      readEnable: request.dequeue,
      depth: capabilities.depth,
      generateError: generateError,
      generateOccupancy: generateOccupancy,
      generateBypass: capabilities.supportsEmptyBypass,
      definitionName: 'FifoCore_${definitionIdentity}_'
          '${capabilities.configurationIdentity}_'
          'P${payloadShapeIdentity}_W${request.payload.width}',
      name: name,
    );
    return FifoCoreBinding<LogicType>(fifo, capabilities);
  }
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
