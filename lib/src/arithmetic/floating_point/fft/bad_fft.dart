// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';

// class FFT extends Module {
//   LogicArray get out => output('out') as LogicArray;
//
//   FFT(Logic en, Logic clk, Logic reset, LogicArray input, {super.name = 'fft'})
//       : assert(input.dimensions.length == 1) {
//     final int length = input.dimensions[0];
//     if ((length & (~(length - 1))) != length) {
//       assert(false);
//     }
//     final int log2Length = log2Ceil(length);
//
//     input = addInputArray(
//       'input_array',
//       input,
//       dimensions: input.dimensions, // it seems like these are needed
//       elementWidth: input.elementWidth,
//       numUnpackedDimensions: input.numUnpackedDimensions,
//     );
//
//     List<LogicArray> stageArrays = List.generate(
//       log2Length + 1,
//       (stage) => LogicArray(
//         input.dimensions,
//         input.elementWidth,
//         name: 'stage${stage}Array',
//         numUnpackedDimensions: input.numUnpackedDimensions,
//       ),
//     );
//
//     LogicArray out = addOutputArray(
//       'out',
//       dimensions: input.dimensions,
//       elementWidth: input.elementWidth,
//       numUnpackedDimensions: input.numUnpackedDimensions,
//     );
//     out <= stageArrays[log2Length];
//
//     List<List<Conditional> Function(PipelineStageInfo)> fftStages = [];
//
//     fftStages.add((p) => [stageArrays[0] < BitReverse(input).out]);
//
//     for (var s = 1; s <= log2Length; s++) {
//       final m = 1 << s;
//       final mShift = log2Ceil(m);
//
//       Counter i = Counter(en, reset, clk, width: log2Length - 1);
//
//       Logic k = (i.val >> (mShift - 1)) << mShift;
//       Logic j = (i.val & Const((m >> 1) - 1, width: i.width));
//     }
//
//     // ReadyValidPipeline()
//
//     // for s = 1 to log(n) do
//     //     m ← 2s
//     //     ωm ← exp(−2πi/m)
//     //     for k = 0 to n-1 by m do
//     //         ω ← 1
//     //         for j = 0 to m/2 – 1 do
//     //             t ← ω A[k + j + m/2]
//     //             u ← A[k + j]
//     //             A[k + j] ← u + t
//     //             A[k + j + m/2] ← u – t
//     //             ω ← ω ωm
//   }
// }
