//
// utils.dart
// Various utilities helpful for working with the component library
//

import 'dart:math';

/// Compute the bit width needed to store w addresses
int log2Ceil(int w) => (log(w) / log(2)).ceil();
