import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_utils.dart';
import 'package:meta/meta.dart';

class SummationBase extends Module with DynamicInputToLogicForSummation {
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

  /// Indicates whether the sum has reached the maximum value.
  ///
  /// If it [saturates], then the result will be equal to the maximum value.
  /// Otherwise, the value may have overflowed to any value, but the net sum
  /// before overflow will have been greater than the maximum value.
  Logic get reachedMax => output('reachedMax');

  /// Indicates whether the sum has reached the minimum value.
  ///
  /// If it [saturates], then the result will be equal to the minimum value.
  /// Otherwise, the value may have underflowed to any value, but the net sum
  /// before underflow will have been less than the minimum value.
  Logic get reachedMin => output('reachedMin');

  SummationBase(
    List<SumInterface> interfaces, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    this.saturates = false,
    int? width,
    super.name,
  }) : width =
            inferWidth([initialValue, maxValue, minValue], width, interfaces) {
    if (interfaces.isEmpty) {
      throw RohdHclException('At least one interface must be provided.');
    }

    this.interfaces = interfaces
        .mapIndexed((i, e) => SumInterface.clone(e)
          ..pairConnectIO(this, e, PairRole.consumer,
              uniquify: (original) => '${original}_$i'))
        .toList();

    initialValueLogic = dynamicInputToLogic('initialValue', initialValue);
    minValueLogic = dynamicInputToLogic('minValue', minValue);
    maxValueLogic =
        dynamicInputToLogic('maxValue', maxValue ?? biggestVal(this.width));

    addOutput('reachedMax');
    addOutput('reachedMin');
  }
}
