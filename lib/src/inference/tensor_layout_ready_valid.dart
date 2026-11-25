// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_layout_ready_valid.dart
// Ready/valid attachments around action-driven tensor layout cores.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/payloads/ready_valid_frame.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_tensor_tile.dart';
import 'package:rohd_hcl/src/inference/tensor_layout_transform.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Adds ready/valid transport to [TensorTileUntiler].
///
/// The core retains the accepted tile and advances only on output transfers.
/// A stalled element is irrevocable. The final transfer can accept a new tile
/// on the same edge, preserving the core's no-bubble replacement schedule.
/// {@category Inference}
class ReadyValidTensorTileUntiler<TLogic extends Logic, TValue> extends Module {
  /// Index of the element currently offered downstream.
  Logic get index => output('index');

  /// High while an accepted tile is being emitted.
  Logic get active => output('active');

  /// Wraps an action-driven untiler with ready/valid attachments.
  ReadyValidTensorTileUntiler({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> upstream,
    required ReadyValidInterface<Frame<InferenceTensorStreamElement<TLogic>>>
        downstream,
    super.name = 'ready_valid_tensor_tile_untiler',
  }) : super(
          definitionName: 'ReadyValidTensorTileUntiler_'
              '${tensorTileStreamShapeIdentity(
            upstream.data,
            downstream.data.data,
            definitionPrefix: 'ReadyValidTensorTileUntiler_',
            frame: downstream.data,
          )}',
        ) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final input = addPairInterface(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    final output = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final load = Logic(name: '${name}_load');
    final advance = Logic(name: '${name}_advance');
    final payload = cloneTypedPayload(input.data, name: '${name}_payload');
    final core = TensorTileUntiler<TLogic, TValue>(
      clk: localClk,
      reset: localReset,
      inputTile: payload,
      elementSchema: output.data.data,
      load: load,
      advance: advance,
      name: '${name}_core',
    );
    ReadyValidIngressAttachmentPolicy<InferenceTensorTile<TLogic, TValue>>(
      supportsSameCycleReplacement: true,
    ).attach(
      upstream: input,
      canAccept: ~core.active | (advance & core.result.last),
      accept: load,
      payload: payload,
    );
    ReadyValidEgressAttachmentPolicy<
            Frame<InferenceTensorStreamElement<TLogic>>>()
        .attach(
      downstream: output,
      offerValid: core.active,
      payload: core.result,
      transfer: advance,
    );
    addOutput('index', width: core.index.width) <= core.index;
    addOutput('active') <= core.active;
  }
}

/// Adds ready/valid transport and completion retention to [TensorTileTiler].
///
/// The shell admits writes only while no completed tile is pending or its
/// consumer transfers it on the same edge. It retains the core's completion
/// pulse as an irrevocable offer, without duplicating storage or mapping.
/// Malformed frames still transfer with cleared masks and diagnostic flags.
/// {@category Inference}
class ReadyValidTensorTileTiler<TLogic extends Logic, TValue> extends Module {
  /// High alongside a valid output when the frame length or marker is wrong.
  Logic get framingError => output('framingError');

  /// High alongside a valid output when repeated mask bits differ.
  Logic get maskInconsistent => output('maskInconsistent');

  /// Number of elements collected in the current output frame.
  Logic get collectedElements => output('collectedElements');

  /// Wraps an action-driven tiler with ready/valid attachments.
  ReadyValidTensorTileTiler({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<Frame<InferenceTensorStreamElement<TLogic>>>
        upstream,
    required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>>
        downstream,
    super.name = 'ready_valid_tensor_tile_tiler',
  }) : super(
          definitionName: 'ReadyValidTensorTileTiler_'
              '${tensorTileStreamShapeIdentity(
            downstream.data,
            upstream.data.data,
            definitionPrefix: 'ReadyValidTensorTileTiler_',
            frame: upstream.data,
          )}',
        ) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final input = addPairInterface(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    final output = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final write = Logic(name: '${name}_write');
    final consume = Logic(name: '${name}_consume');
    final retained = Logic(name: '${name}_retained');
    final occupied = Logic(name: '${name}_occupied');
    final payload = cloneTypedPayload(input.data, name: '${name}_payload');
    final core = TensorTileTiler<TLogic, TValue>(
      clk: localClk,
      reset: localReset,
      element: payload,
      write: write,
      tileSchema: output.data,
      name: '${name}_core',
    );
    occupied <= retained | core.complete;
    Sequential(localClk, reset: localReset, resetValues: {
      retained: 0
    }, [
      If(consume, then: [
        retained < 0,
      ], orElse: [
        If(core.complete, then: [retained < 1]),
      ]),
    ]);
    ReadyValidIngressAttachmentPolicy<
        Frame<InferenceTensorStreamElement<TLogic>>>(
      supportsSameCycleReplacement: true,
    ).attach(
      upstream: input,
      canAccept: ~occupied | consume,
      accept: write,
      payload: payload,
    );
    ReadyValidEgressAttachmentPolicy<InferenceTensorTile<TLogic, TValue>>()
        .attach(
      downstream: output,
      offerValid: occupied,
      payload: core.result,
      transfer: consume,
    );
    addOutput('framingError') <= occupied & core.framingError;
    addOutput('maskInconsistent') <= occupied & core.maskInconsistent;
    addOutput('collectedElements', width: core.collectedElements.width) <=
        core.collectedElements;
  }
}
