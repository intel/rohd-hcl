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
    test('Rotate left by int', () async {
      final orig = Logic(width: 8)..put(0xf0);

      print(orig.rotateLeft(0).value.toString(includeWidth: false));
      print(orig.rotateLeft(1).value.toString(includeWidth: false));
      print(orig.rotateLeft(2).value.toString(includeWidth: false));

      var mod = RotateLeft(orig, Logic(width: 8));
      await mod.build();
      print(mod.generateSynth());

      expect(orig.rotateLeft(4).value.toInt(), equals(0x0f));
      expect(orig.rotateLeft(1).value.toInt(), equals(0xe1));
    });
    test('Rotate left by Logic', () {});
  });
}
