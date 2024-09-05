import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:meta/meta.dart';

abstract class SummationBase extends Module {
  final int width;

  @protected
  late final Logic initialValueLogic;

  @protected
  late final Logic minValueLogic;

  @protected
  late final Logic maxValueLogic;

  @protected
  late final List<SumInterface> interfaces;

  /// If `true`, will saturate at the `maxValue` and `minValue`. If `false`,
  /// will wrap around (overflow/underflow) at the `maxValue` and `minValue`.
  final bool saturates;

  //TODO: review doc comments!
  /// Indicates whether the sum has reached the maximum value.
  ///
  /// If it [saturates], then the result will be equal to the maximum value.
  /// Otherwise, the value may have overflowed to any value, but the net sum
  /// before overflow will have been greater than the maximum value.
  // Logic get reachedMax => output('reachedMax');

  /// Indicates whether the sum has reached the minimum value.
  ///
  /// If it [saturates], then the result will be equal to the minimum value.
  /// Otherwise, the value may have underflowed to any value, but the net sum
  /// before underflow will have been less than the minimum value.
  // Logic get reachedMin => output('reachedMin');
/** 
 * 
*/

  Logic get overflowed => output('overflowed');
  Logic get underflowed => output('underflowed');
  Logic get equalsMax => output('equalsMax');
  Logic get equalsMin => output('equalsMin');

  SummationBase(
    List<SumInterface> interfaces, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    this.saturates = false,
    int? width,
    super.name,
  }) : width =
            _inferWidth([initialValue, maxValue, minValue], width, interfaces) {
    if (interfaces.isEmpty) {
      throw RohdHclException('At least one interface must be provided.');
    }

    this.interfaces = interfaces
        .mapIndexed((i, e) => SumInterface.clone(e)
          ..pairConnectIO(this, e, PairRole.consumer,
              uniquify: (original) => '${original}_$i'))
        .toList();

    initialValueLogic = _dynamicInputToLogic('initialValue', initialValue);
    minValueLogic = _dynamicInputToLogic('minValue', minValue);
    maxValueLogic =
        _dynamicInputToLogic('maxValue', maxValue ?? biggestVal(this.width));

    addOutput('overflowed');
    addOutput('underflowed');
    addOutput('equalsMax');
    addOutput('equalsMin');
  }

  /// TODO doc
  Logic _dynamicInputToLogic(String name, dynamic value) {
    if (value is Logic) {
      return addInput(name, value.zeroExtend(width), width: width);
    } else {
      if (LogicValue.ofInferWidth(value).width > width) {
        throw RohdHclException(
            'Value $value for $name is too large for width $width');
      }

      return Logic(name: name, width: width)..gets(Const(value, width: width));
    }
  }

  @protected
  static int biggestVal(int width) => (1 << width) - 1;

  //TODO doc
  static int _inferWidth(
      List<dynamic> values, int? width, List<SumInterface> interfaces) {
    if (width != null) {
      if (width <= 0) {
        throw RohdHclException('Width must be greater than 0.');
      }

      if (values.any((v) => v is Logic && v.width > width)) {
        throw RohdHclException(
            'Width must be at least as large as the largest value.');
      }

      return width;
    }

    int? maxWidthFound;

    for (final value in values) {
      int? inferredValWidth;
      if (value is Logic) {
        inferredValWidth = value.width;
      } else if (value != null) {
        inferredValWidth = LogicValue.ofInferWidth(value).width;
      }

      if (inferredValWidth != null &&
          (maxWidthFound == null || inferredValWidth > maxWidthFound)) {
        maxWidthFound = inferredValWidth;
      }
    }

    for (final interface in interfaces) {
      if (interface.width > maxWidthFound!) {
        maxWidthFound = interface.width;
      }
    }

    if (maxWidthFound == null) {
      throw RohdHclException('Unabled to infer width.');
    }

    return max(1, maxWidthFound);
  }
}
