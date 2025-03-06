import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// FindPattern functionality
///
/// Takes in a [Logic] to find location of a fixed-width pattern.
/// Outputs pin `index` contains position.
class FindPattern extends Module {
  /// [index] is a getter for output of FindPattern
  Logic get index => output('index');

  /// [error] is a getter for error in FindPattern
  /// When your pattern is not found it will result in error `1`
  Logic? get error => tryOutput('error');

  /// If `true`, then the [error] output will be generated.
  final bool generateError;

  /// Find a position for a fixed-width pattern
  ///
  /// Takes in search pattern [pattern] and a boolean [start] to determine the
  ///  search direction.
  /// If [start] is `true`, the search starts from the beginning of the bus.
  /// If [start] is `false`, the search starts from the end of the bus.
  ///
  /// By default, [FindPattern] will look for the first occurrence
  /// of the pattern.
  /// If [n] is given, [FindPattern] will find the N'th occurrence
  /// of the pattern.
  /// [n] starts from `1` as the first occurrence.
  ///
  /// Outputs pin `index` contains the position. Position starts from `0` based.
  FindPattern(Logic bus, Logic pattern,
      {bool start = true, int n = 1, this.generateError = false})
      : super(definitionName: 'FindPattern_W${bus.width}_P${pattern.width}') {
    bus = addInput('bus', bus, width: bus.width);
    pattern = addInput('pattern', pattern, width: pattern.width);
    addOutput('index', width: bus.width);

    print('bus: ${bus.value.toInt()}');
    print('pattern: ${pattern.value.toInt()}');

    // Initialize counter pattern occurrence to 0
    var count = 0;

    print('=======================');

    if (start) {
      print('check from start');
      for (var i = 0; i <= bus.width - pattern.width; i = i + 1) {
        // Read from start of bus
        final minBit = i;
        final maxBit = i + pattern.width;
        print('minBit: $minBit, maxBit: $maxBit');
        final busVal = bus.getRange(minBit, maxBit);
        // Check if pattern matches
        final valCheck = busVal.eq(pattern);
        print('i: $i, busVal: ${busVal.value}, valCheck: ${valCheck.value}');

        // Check if pattern matches, count if found
        count += (valCheck.value.toInt() == 1) ? 1 : 0;
        print('count: $count');

        // If count matches n, break and return index
        if (n == count) {
          print('n == count');
          index <= Const(i, width: bus.width);
          print('index: ${index.value}');
          break;
        }
        print('=======================');
      }
    } else {
      print('check from end');
      for (var i = 0; i <= bus.width - pattern.width; i = i + 1) {
        // Read from end of bus
        final minBit = bus.width - i - pattern.width;
        final maxBit = bus.width - i;
        print('minBit: $minBit, maxBit: $maxBit');
        final busVal = bus.getRange(minBit, maxBit);
        print('busVal: ${busVal.value}');
        // Check if pattern matches
        final valCheck = busVal.eq(pattern);
        print('i: $i, busVal: ${busVal.value}, valCheck: ${valCheck.value}');
        print('count: $count');

        // Check if pattern matches, count if found
        count += (valCheck.value.toInt() == 1) ? 1 : 0;
        print('count: $count');

        // If count matches n, break and return index
        if (n == count) {
          print('n == count');
          index <= Const(i, width: bus.width);
          print('index: ${index.value}');
          break;
        }
        print('=======================');
      }
    }

    if (generateError) {
      // If pattern is not found, return error
      var isError = (count < n || count == 0) ? 1 : 0;
      addOutput('error');
      error! <= Const(isError, width: 1);
      print('error: ${error!.value}');
      // If error is generated, return index as 255
      index <= Const(255, width: bus.width);
      print('index: ${index.value}');
    }
  }
}
