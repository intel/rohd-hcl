// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialized_worker_request_queue_test.dart
// Tests serialized worker request and response pairing.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/view/screen/serialized_worker_request_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispatches only one request until its response arrives', () async {
    final dispatched = <String>[];
    final queue = SerializedWorkerRequestQueue<String>();

    final first = queue.add(() => dispatched.add('first'));
    final second = queue.add(() => dispatched.add('second'));

    expect(dispatched, ['first']);

    queue.complete('first response');
    expect(await first, 'first response');
    expect(dispatched, ['first', 'second']);

    queue.complete('second response');
    expect(await second, 'second response');
  });

  test('continues with the next request after an error', () async {
    final dispatched = <String>[];
    final queue = SerializedWorkerRequestQueue<String>();

    final first = queue.add(() => dispatched.add('first'));
    final second = queue.add(() => dispatched.add('second'));

    queue.completeError(StateError('failed'));
    await expectLater(first, throwsStateError);
    expect(dispatched, ['first', 'second']);

    queue.complete('second response');
    expect(await second, 'second response');
  });
}
