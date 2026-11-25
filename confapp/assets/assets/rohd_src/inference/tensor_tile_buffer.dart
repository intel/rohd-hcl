// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_tile_buffer.dart
// Ready/valid tensor-tile buffering compositions.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/queues/ready_valid_queue.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/inference_tensor_tile.dart';

/// Creates a two-entry registered tensor-tile queue.
///
/// The two queue entries form ping-pong ownership: the producer may fill one
/// retained tile while the consumer drains the other. This factory deliberately
/// reuses [ReadyValidQueue] rather than introducing another storage module.
ReadyValidQueue<InferenceTensorTile<TLogic, TValue>>
    tensorPingPongBuffer<TLogic extends Logic, TValue>({
  required Logic clk,
  required Logic reset,
  required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> upstream,
  required ReadyValidInterface<InferenceTensorTile<TLogic, TValue>> downstream,
  Logic? flush,
  String name = 'tensor_ping_pong_buffer',
}) =>
        ReadyValidQueue<InferenceTensorTile<TLogic, TValue>>(
          clk: clk,
          reset: reset,
          upstream: upstream,
          downstream: downstream,
          depth: 2,
          storage: ReadyValidQueueStorage.ring,
          flush: flush,
          name: name,
        );
