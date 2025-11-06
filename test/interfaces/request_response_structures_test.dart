// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_structures_test.dart
// Tests for request/response data structures.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('RequestStructure', () {
    test('should create structure with correct fields', () {
      const idWidth = 4;
      const addrWidth = 32;

      final request = RequestStructure(idWidth: idWidth, addrWidth: addrWidth);

      expect(request.id.width, equals(idWidth));
      expect(request.addr.width, equals(addrWidth));
      expect(request.width, equals(idWidth + addrWidth));
    });

    test('should clone correctly', () {
      const idWidth = 8;
      const addrWidth = 64;

      final original = RequestStructure(idWidth: idWidth, addrWidth: addrWidth);
      final cloned = original.clone();

      expect(cloned.id.width, equals(idWidth));
      expect(cloned.addr.width, equals(addrWidth));
      expect(cloned.width, equals(original.width));
    });
  });

  group('ResponseStructure', () {
    test('should create structure with correct fields', () {
      const idWidth = 4;
      const dataWidth = 32;

      final response =
          ResponseStructure(idWidth: idWidth, dataWidth: dataWidth);

      expect(response.id.width, equals(idWidth));
      expect(response.data.width, equals(dataWidth));
      // +1 for nonCacheable bit which is always present.
      expect(response.nonCacheable.width, equals(1));
      expect(response.width, equals(idWidth + dataWidth + 1));
    });

    test('should clone correctly', () {
      const idWidth = 8;
      const dataWidth = 64;

      final original =
          ResponseStructure(idWidth: idWidth, dataWidth: dataWidth);
      final cloned = original.clone();

      expect(cloned.id.width, equals(idWidth));
      expect(cloned.data.width, equals(dataWidth));
      expect(cloned.width, equals(original.width));
      expect(cloned.nonCacheable.width, equals(1));
    });
  });
}
