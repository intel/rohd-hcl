// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// browser_interop_web_test.dart
// Browser tests for worker, download, and context-menu integrations.
//
// 2026 September 30
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:confapp/hcl/view/screen/browser_interop_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('Yosys worker pairs serialized requests with their responses', () async {
    const workerScript = '''
      let activeRequests = 0;
      onmessage = function(event) {
        activeRequests++;
        const request = event.data.verilog;
        const delay = request === 'first' ? 20 : 0;
        setTimeout(function() {
          postMessage(request + ':' + activeRequests);
          activeRequests--;
        }, delay);
      };
    ''';
    final workerBlob = web.Blob(
      <JSAny>[workerScript.toJS].toJS,
      web.BlobPropertyBag(type: 'text/javascript'),
    );
    final workerUrl = web.URL.createObjectURL(workerBlob);
    final worker = YosysWorker(workerUrl);
    addTearDown(() {
      worker.dispose();
      web.URL.revokeObjectURL(workerUrl);
    });

    final first = worker.synthesize({
      'module': 'FirstModule',
      'verilog': 'first',
    });
    final second = worker.synthesize({
      'module': 'SecondModule',
      'verilog': 'second',
    });

    expect(await first, 'first:1');
    expect(await second, 'second:1');
  });

  test('Yosys worker errors fail active and queued requests', () async {
    const workerScript = '''
      onmessage = function() {
        throw new Error('intentional worker failure');
      };
    ''';
    final workerBlob = web.Blob(
      <JSAny>[workerScript.toJS].toJS,
      web.BlobPropertyBag(type: 'text/javascript'),
    );
    final workerUrl = web.URL.createObjectURL(workerBlob);
    final worker = YosysWorker(workerUrl);
    addTearDown(() {
      worker.dispose();
      web.URL.revokeObjectURL(workerUrl);
    });

    final first = worker.synthesize({
      'module': 'FirstModule',
      'verilog': 'first',
    });
    final second = worker.synthesize({
      'module': 'SecondModule',
      'verilog': 'second',
    });
    final matcher = throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('intentional worker failure'),
      ),
    );

    await Future.wait([
      expectLater(first, matcher),
      expectLater(second, matcher),
    ]);
    await expectLater(
      worker.synthesize({
        'module': 'ThirdModule',
        'verilog': 'third',
      }),
      matcher,
    );
  });

  test('download uses the requested filename and UTF-8 bytes', () async {
    const content = 'ROHD π';
    const fileName = 'generated-π.sv';
    final clicked = Completer<({String fileName, String href})>();
    late final web.EventListener listener;
    listener = ((web.Event event) {
      event.preventDefault();
      final anchor = event.target! as web.HTMLAnchorElement;
      clicked.complete((fileName: anchor.download, href: anchor.href));
    }).toJS;
    web.document.addEventListener('click', listener, true.toJS);
    addTearDown(
      () => web.document.removeEventListener('click', listener, true.toJS),
    );

    downloadFile(content: content, fileName: fileName);

    final download = await clicked.future;
    expect(download.fileName, fileName);
    expect(
      Uri.parse(download.href).data!.contentAsBytes(),
      utf8.encode(content),
    );
  });

  test('context menu suppression is reference counted', () {
    final target = web.HTMLDivElement();
    web.document.body!.appendChild(target);
    // External JS interop methods cannot be passed as tear-offs.
    // ignore: unnecessary_lambdas
    addTearDown(() => target.remove());
    var attachedReferences = 0;
    addTearDown(() {
      while (attachedReferences > 0) {
        BrowserContextMenuSuppression.detach();
        attachedReferences--;
      }
    });

    BrowserContextMenuSuppression.attach();
    attachedReferences++;
    BrowserContextMenuSuppression.attach();
    attachedReferences++;

    final suppressed = web.Event(
      'contextmenu',
      web.EventInit(bubbles: true, cancelable: true),
    );
    expect(target.dispatchEvent(suppressed), isFalse);
    expect(suppressed.defaultPrevented, isTrue);

    BrowserContextMenuSuppression.detach();
    attachedReferences--;
    final stillSuppressed = web.Event(
      'contextmenu',
      web.EventInit(bubbles: true, cancelable: true),
    );
    expect(target.dispatchEvent(stillSuppressed), isFalse);
    expect(stillSuppressed.defaultPrevented, isTrue);

    BrowserContextMenuSuppression.detach();
    attachedReferences--;

    final allowed = web.Event(
      'contextmenu',
      web.EventInit(bubbles: true, cancelable: true),
    );
    expect(target.dispatchEvent(allowed), isTrue);
    expect(allowed.defaultPrevented, isFalse);
  });
}
