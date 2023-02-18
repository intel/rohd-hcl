//
// rotate_left_test.dart
// Tests for left-rotate
//
// Author: Max Korbel
// 2023 February 17
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('Logic', () {
    test('Rotate left by int', () {
      final orig = Logic(width: 8)..put(0xf0);
      expect(orig.rotateLeft(4).value.toInt(), equals(0xf0));
      expect(orig.rotateLeft(1).value.toInt(), equals(0xe1));
    });
    test('Rotate left by Logic', () {});
  });
}
