// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arithmetic_utils_test.dart
// Tests arithmetic_utils listString
//
// 2024 October 7
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/arithmetic_utils.dart';
import 'package:test/test.dart';

void main() {
  final val = LogicValue.ofInt(200, 8);
  final valL = Logic(width: val.width);
  // ignore: cascade_invocations
  valL.put(val);
  final bigVal = LogicValue.ofString('1010101001101010010111101' * 8);
  final bigValL = Logic(width: bigVal.width);
  // ignore: cascade_invocations
  bigValL.put(bigVal);

  test('listString alignment', () {
    {
      final buf = StringBuffer();

      for (var shift = -7; shift < 17; shift++) {
        // Alignment BEYOND the MSB but shorter alignLow
        final s = valL.elements.listString('shift $shift',
            prefix: 20,
            alignHigh: 15,
            alignLow: 2,
            header: shift == -7,
            shift: shift,
            intValue: true);
        buf.write('$s\n');
      }
      const es = '''
                     14 13 12 11 10  9  8  7  6  5  4  3  2
shift -7                                                      = 1 (1)
shift -6                                                      = 3 (3)
shift -5                                                  1   = 6 (6)
shift -4                                               1  1   = 12 (12)
shift -3                                            1  1  0   = 25 (25)
shift -2                                         1  1  0  0   = 50 (50)
shift -1                                      1  1  0  0  1   = 100 (100)
shift 0                                    1  1  0  0  1  0   = 200 (200)
shift 1                                 1  1  0  0  1  0  0   = 400 (400)
shift 2                              1  1  0  0  1  0  0  0   = 800 (800)
shift 3                           1  1  0  0  1  0  0  0      = 1600 (1600)
shift 4                        1  1  0  0  1  0  0  0         = 3200 (3200)
shift 5                     1  1  0  0  1  0  0  0            = 6400 (6400)
shift 6                  1  1  0  0  1  0  0  0               = 12800 (12800)
shift 7               1  1  0  0  1  0  0  0                  = 25600 (-7168)
shift 8               1  0  0  1  0  0  0                     = 18432 (-14336)
shift 9               0  0  1  0  0  0                        = 4096 (4096)
shift 10              0  1  0  0  0                           = 8192 (8192)
shift 11              1  0  0  0                              = 16384 (-16384)
shift 12              0  0  0                                 = 0 (0)
shift 13              0  0                                    = 0 (0)
shift 14              0                                       = 0 (0)
shift 15                                                      = 0 (0)
shift 16                                                      = 0 (0)
''';
      expect(buf.toString(), equals(es));
    }
    {
      final buf = StringBuffer();

      for (var shift = -7; shift < 7; shift++) {
        // Alignment BEYOND the MSB but shorter alignLow
        final s = valL.elements.listString('shift $shift',
            prefix: 20,
            alignHigh: 6,
            alignLow: 2,
            header: shift == -7,
            shift: shift,
            intValue: true);
        buf.write('$s\n');
      }
      const es = '''
                     5 4 3 2
shift -7                      = 1 (1)
shift -6                      = 3 (3)
shift -5                   1  = 6 (6)
shift -4                 1 1  = 12 (12)
shift -3               1 1 0  = 25 (25)
shift -2             1 1 0 0  = 50 (50)
shift -1             1 0 0 1  = 36 (36)
shift 0              0 0 1 0  = 8 (8)
shift 1              0 1 0 0  = 16 (16)
shift 2              1 0 0 0  = 32 (32)
shift 3              0 0 0    = 0 (0)
shift 4              0 0      = 0 (0)
shift 5              0        = 0 (0)
shift 6                       = 0 (0)
''';
      expect(buf.toString(), equals(es));
    }
  });
  test('listString spacing', () {
    {
      // increasing space between columns by 1
      final s =
          valL.elements.listString('space +1', header: true, extraSpace: 1);
      const es = '''
            7  6  5  4  3  2  1  0
space +1    1  1  0  0  1  0  0  0''';
      expect(s, equals(es));
    }
    {
      // increasing space between columns by 2

      final s =
          valL.elements.listString('space +2', header: true, extraSpace: 2);
      const es = '''
             7   6   5   4   3   2   1   0
space +2     1   1   0   0   1   0   0   0''';
      expect(s, equals(es));
    }
    {
      // increasing space between columns by when column width is set by
      // bigger alignment column

      final s = valL.elements.listString('2digit +2',
          header: true, alignHigh: 11, shift: 4, extraSpace: 2);
      const es = '''
             10    9    8    7    6    5    4    3    2    1    0
2digit +2     1    0    0    1    0    0    0                    ''';

      expect(s, equals(es));
    }
  });
  test('listString separator', () {
    {
      final buf = StringBuffer();
      for (var shift = -7; shift < 17; shift++) {
        // Alignment BEYOND the MSB but shorter alignLow
        final s = valL.elements.listString('sep $shift',
            alignHigh: 15,
            alignLow: 2,
            header: shift == -7,
            sepPos: shift,
            intValue: true);
        buf.write('$s\n');
      }
      const es = '''
           14 13 12 11 10  9  8  7  6  5  4  3  2
sep -7                           1  1  0  0  1  0   = 200 (200)
sep -6                           1  1  0  0  1  0   = 200 (200)
sep -5                           1  1  0  0  1  0   = 200 (200)
sep -4                           1  1  0  0  1  0   = 200 (200)
sep -3                           1  1  0  0  1  0   = 200 (200)
sep -2                           1  1  0  0  1  0   = 200 (200)
sep -1                           1  1  0  0  1  0   = 200 (200)
sep 0                            1  1  0  0  1  0   = 200 (200)
sep 1                            1  1  0  0  1  0   = 200 (200)
sep 2                            1  1  0  0  1  0*  = 200 (200)
sep 3                            1  1  0  0  1* 0   = 200 (200)
sep 4                            1  1  0  0* 1  0   = 200 (200)
sep 5                            1  1  0* 0  1  0   = 200 (200)
sep 6                            1  1* 0  0  1  0   = 200 (200)
sep 7                            1* 1  0  0  1  0   = 200 (200)
sep 8                          * 1  1  0  0  1  0   = 200 (200)
sep 9                            1  1  0  0  1  0   = 200 (200)
sep 10                           1  1  0  0  1  0   = 200 (200)
sep 11                           1  1  0  0  1  0   = 200 (200)
sep 12                           1  1  0  0  1  0   = 200 (200)
sep 13                           1  1  0  0  1  0   = 200 (200)
sep 14                           1  1  0  0  1  0   = 200 (200)
sep 15                           1  1  0  0  1  0   = 200 (200)
sep 16                           1  1  0  0  1  0   = 200 (200)
''';
      expect(buf.toString(), equals(es));
    }
  });
}
