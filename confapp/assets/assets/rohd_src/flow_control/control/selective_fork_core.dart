// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// selective_fork_core.dart
// Protocol-neutral scheduled selective fan-out core.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/control/hardware_core_functor.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Action semantics and configured shape of a selective fork core.
/// {@category Flow Control}
class SelectiveForkCoreCapabilities implements HardwareCoreCapabilities {
  /// Number of independently completed fan-out destinations.
  final int outputCount;

  /// Whether an all-zero selection is consumed without retaining payload.
  final bool consumesEmptySelection;

  /// Whether each selected destination advances independently.
  final bool supportsIndependentAdvance;

  /// Whether final advance and a new load may occur on the same edge.
  final bool supportsFinalAdvanceReplacement;

  /// Creates selective-fork capability metadata.
  const SelectiveForkCoreCapabilities({
    required this.outputCount,
    this.consumesEmptySelection = true,
    this.supportsIndependentAdvance = true,
    this.supportsFinalAdvanceReplacement = true,
  });

  @override
  String get configurationIdentity => 'N${outputCount}_'
      'Z${consumesEmptySelection ? 1 : 0}_'
      'I${supportsIndependentAdvance ? 1 : 0}_'
      'R${supportsFinalAdvanceReplacement ? 1 : 0}';
}

/// Wrapper-owned actions and payload for a selective fork construction.
/// {@category Flow Control}
class SelectiveForkCoreRequest<LogicType extends Logic> {
  /// Core clock.
  final Logic clk;

  /// Synchronous core reset.
  final Logic reset;

  /// Typed payload sampled by [load].
  final LogicType payload;

  /// One destination bit sampled by [load].
  final Logic selection;

  /// Explicit payload-and-mask load action.
  final Logic load;

  /// One explicit completion action per destination.
  final Logic advance;

  /// Creates a typed selective-fork construction request.
  const SelectiveForkCoreRequest({
    required this.clk,
    required this.reset,
    required this.payload,
    required this.selection,
    required this.load,
    required this.advance,
  });
}

/// Scheduled selective fan-out with retained payload and completion mask.
/// {@category Flow Control}
class SelectiveForkCore<LogicType extends Logic> extends Module {
  /// Configured action and fan-out contract.
  final SelectiveForkCoreCapabilities capabilities;

  /// High when a new payload and selection mask may be loaded.
  ///
  /// This is also high when `advance` completes every remaining destination
  /// in the current cycle. Callers must derive `advance` only from completion
  /// of the currently presented outputs, not from [canLoad] or [loadAccepted],
  /// to avoid a combinational loop.
  Logic get canLoad => output('canLoad');

  /// High when at least one selected destination remains.
  Logic get occupied => output('occupied');

  /// High when a load action is accepted.
  Logic get loadAccepted => output('loadAccepted');

  /// Payload retained for all selected destinations.
  late final LogicType retainedPayload;

  /// Selected destinations that have not advanced.
  Logic get remaining => output('remaining');

  /// Per-destination valid mask.
  Logic get outputValidMask => output('outputValidMask');

  SelectiveForkCore._({
    required SelectiveForkCoreRequest<LogicType> request,
    required this.capabilities,
    required String definitionName,
    required String name,
  }) : super(definitionName: definitionName, name: name) {
    final localClk = addInput('clk', request.clk);
    final localReset = addInput('reset', request.reset);
    final localPayload = addTypedInput('payload', request.payload);
    final localSelection = addInput(
      'selection',
      request.selection,
      width: capabilities.outputCount,
    );
    final localLoad = addInput('load', request.load);
    final localAdvance = addInput(
      'advance',
      request.advance,
      width: capabilities.outputCount,
    );

    addOutput('canLoad');
    addOutput('occupied');
    addOutput('loadAccepted');
    retainedPayload =
        addTypedPayloadOutput(this, 'retainedPayload', request.payload);
    addOutput('remaining', width: capabilities.outputCount);
    addOutput('outputValidMask', width: capabilities.outputCount);

    final remainingAfterAdvance =
        (remaining & ~localAdvance).named('${name}_remaining_after_advance');
    final finalAdvance =
        (occupied & remaining.or() & ~remainingAfterAdvance.or())
            .named('${name}_final_advance');
    canLoad <= ~occupied | finalAdvance;
    loadAccepted <= localLoad & canLoad;
    outputValidMask <= remaining & occupied.replicate(capabilities.outputCount);
    final nextOccupied = mux(
      loadAccepted,
      localSelection.or(),
      occupied & remainingAfterAdvance.or(),
    ).named('${name}_next_occupied');

    Sequential(
      localClk,
      reset: localReset,
      resetValues: {
        occupied: 0,
        remaining: 0,
      },
      [
        If(
          loadAccepted,
          then: [
            retainedPayload < localPayload,
            remaining < localSelection,
          ],
          orElse: [
            If(
              occupied,
              then: [remaining < remainingAfterAdvance],
            ),
          ],
        ),
        occupied < nextOccupied,
      ],
    );
  }
}

/// Constructed selective fork and its output-only binding.
/// {@category Flow Control}
class SelectiveForkCoreBinding<LogicType extends Logic>
    implements HardwareCoreBinding {
  @override
  final SelectiveForkCore<LogicType> module;

  /// Capabilities validated for this construction.
  final SelectiveForkCoreCapabilities capabilities;

  /// Creates a selective-fork binding.
  const SelectiveForkCoreBinding(this.module, this.capabilities);

  /// High when the core can accept a load action.
  Logic get canLoad => module.canLoad;

  /// High while selected destinations remain.
  Logic get occupied => module.occupied;

  /// High when the load action is accepted.
  Logic get loadAccepted => module.loadAccepted;

  /// Retained typed payload.
  LogicType get retainedPayload => module.retainedPayload;

  /// Destinations that have not advanced.
  Logic get remaining => module.remaining;

  /// Per-destination valid mask.
  Logic get outputValidMask => module.outputValidMask;
}

/// Constructs protocol-neutral selective fork cores.
/// {@category Flow Control}
class SelectiveForkCoreFunctor<LogicType extends Logic>
    extends HardwareCoreFunctor<SelectiveForkCoreRequest<LogicType>,
        SelectiveForkCoreBinding<LogicType>> {
  @override
  final SelectiveForkCoreCapabilities capabilities;

  /// Creates a configured selective-fork construction functor.
  SelectiveForkCoreFunctor({required int outputCount})
      : capabilities = SelectiveForkCoreCapabilities(
          outputCount: outputCount,
        ) {
    if (outputCount < 1) {
      throw ArgumentError.value(
        outputCount,
        'outputCount',
        'Must be at least one.',
      );
    }
  }

  @override
  String get identity => 'selective_fork_core';

  @override
  SelectiveForkCoreBinding<LogicType> construct(
    SelectiveForkCoreRequest<LogicType> request, {
    required String name,
  }) {
    for (final control in {
      'clk': request.clk,
      'reset': request.reset,
      'load': request.load,
    }.entries) {
      if (control.value.width != 1) {
        throw ArgumentError.value(
          control.value,
          control.key,
          'Selective-fork controls must be one bit.',
        );
      }
    }
    if (request.selection.width != capabilities.outputCount) {
      throw ArgumentError.value(
        request.selection,
        'selection',
        'Must have one bit per configured output.',
      );
    }
    if (request.advance.width != capabilities.outputCount) {
      throw ArgumentError.value(
        request.advance,
        'advance',
        'Must have one bit per configured output.',
      );
    }
    final module = SelectiveForkCore<LogicType>._(
      request: request,
      capabilities: capabilities,
      definitionName: 'SelectiveForkCore_${definitionIdentity}_'
          '${capabilities.configurationIdentity}_'
          '${payloadShapeIdentity(request.payload)}',
      name: name,
    );
    return SelectiveForkCoreBinding<LogicType>(module, capabilities);
  }
}
