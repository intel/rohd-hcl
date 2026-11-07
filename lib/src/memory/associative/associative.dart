// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative.dart
// Exports associative components.
//
// 2026 October 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

export 'associative_match_selector.dart';
export 'associative_matcher.dart';
export 'associative_memory.dart';
export 'associative_memory_contract.dart';
export 'cam.dart';
export 'parallel_associative_memory.dart'
    hide
        ParallelAssociativeLookupSignals,
        ParallelAssociativeUpdateSignals,
        buildParallelAssociativeMemoryLogic;
