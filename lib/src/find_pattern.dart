import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// FindPattern functionality
///
/// Takes in a [Logic] to find location of a fixed-width pattern.
/// Outputs pin `index` contains position.
class FindPattern extends Module {
  /// [index] is a getter for output of FindPattern
  Logic get index => output('index');

  /// Find a fixed-width pattern
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
  FindPattern(Logic bus, Logic pattern, {bool start = true, int n = 1})
      : super(definitionName: 'FindPattern_W${bus.width}_P${pattern.width}') {
    bus = addInput('bus', bus, width: bus.width);
    pattern = addInput('pattern', pattern, width: pattern.width);
    addOutput('index', width: bus.width);

    print('bus: ${bus.value.toInt()}');
    print('pattern: ${pattern.value.toInt()}');

    // Initialize countPatternOccurence to 0
    int count = 0;

    print('=======================');

    if (start) {
      print('check from start');
      for (var i = 0; i <= bus.width - pattern.width; i = i + 1) {
        // determines if it is what we are looking for?
        final busVal = bus.getRange(i, i + pattern.width);
        final valCheck = bus.getRange(i, i + pattern.width).eq(pattern);
        print('i: $i, busVal: ${busVal.value}, valCheck: ${valCheck.value}');

        // Check if pattern matches, count if found
        if (valCheck.value.toInt() == 1) {
          count = count + 1;
          print('count: $count');
          // If pattern is found and n is equal to 1, set index to
          //current position
          if (n == 1) {
            index <= Const(i, width: bus.width);
            break;
          }
          // If pattern is found and count == n, set index to
          //current position
          else if (n == count) {
            print('n == count');
            index <= Const(i, width: bus.width);
            break;
          }
        }
        print('count: $count');
        print('=======================');
      }
      print('index: ${index.value}');
    } else {
      print('check from end');
      for (var i = bus.width; i >= bus.width - pattern.width; i = i - 1) {
        // determines if it is what we are looking for?
        final busVal = bus.getRange(i - pattern.width, i);
        final valCheck = bus.getRange(i - pattern.width, i).eq(pattern);
        print('i: $i, busVal: ${busVal.value}, valCheck: ${valCheck.value}');
        print('count: $count');

        // Check if pattern matches, count if found
        if (valCheck.value.toInt() == 1) {
          count = count + 1;
          print('count: $count');
          // If pattern is found and n is equal to 1, set index to
          //current position
          if (n == 1) {
            index <= Const(i - 1, width: bus.width);
            break;
          }
          // If pattern is found and count == n, set index to
          //current position
          else if (n == count) {
            print('n == count');
            index <= Const(i - 1, width: bus.width);
            break;
          }
        }
        print('=======================');
      }
      print('index: ${index.value}');
    }
  }
}
