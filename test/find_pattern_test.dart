import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
import 'package:rohd_hcl/src/find_pattern.dart';

void main() {
  group('FindPattern', () {
    test('Find pattern from start', () async {
      final bus = Const(bin('10101010'), width: 8);
      final pattern = Const(bin('101'), width: 3);
      final findPattern = FindPattern(bus, pattern);
      expect(findPattern.index.value.toInt(), equals(1));
    });

    test('Find pattern from end', () async {
      final bus = Const(bin('10101010'), width: 8);
      final pattern = Const(bin('101'), width: 3);
      final findPattern = FindPattern(bus, pattern, start:false);
      expect(findPattern.index.value.toInt(), equals(7));
    });
  });
}