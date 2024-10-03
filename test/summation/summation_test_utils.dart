// ignore_for_file: invalid_use_of_protected_member

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

int goldenSumOfLogics(
  List<Logic> logics, {
  required int width,
  bool saturates = false,
  int? maxVal,
  int minVal = 0,
}) =>
    goldenSum(
      logics.map((e) => SumInterface(width: e.width)..amount.gets(e)).toList(),
      width: width,
      saturates: saturates,
      minVal: minVal,
      maxVal: maxVal,
    );

int goldenSum(
  List<SumInterface> interfaces, {
  required int width,
  bool saturates = false,
  int? maxVal,
  int? minVal,
  int initialValue = 0,
  bool debug = false,
}) {
  void log(String message) {
    if (debug) {
      // ignore: avoid_print
      print(message);
    }
  }

  log('width: $width');

  var sum = initialValue;

  log('min $minVal  ->  max $maxVal');

  maxVal ??= (1 << width) - 1;
  if (maxVal > (1 << width) - 1) {
    // ignore: parameter_assignments
    maxVal = (1 << width) - 1;
  }
  minVal ??= 0;

  log('min $minVal  ->  max $maxVal  [adjusted]');

  if (minVal > maxVal) {
    throw Exception('minVal must be less than or equal to maxVal');
  }

  log('init: $initialValue');

  for (final intf in interfaces) {
    final amount = intf.amount.value.toInt();
    final enabled = !intf.hasEnable || intf.enable!.value.toBool();

    log('${intf.increments ? '+' : '-'}'
        '$amount${enabled ? '' : '  [disabled]'}');

    if (enabled) {
      if (intf.increments) {
        sum += amount;
      } else {
        sum -= amount;
      }
    }
  }

  log('=$sum');

  if (saturates) {
    if (sum > maxVal) {
      sum = maxVal;
    } else if (sum < minVal) {
      sum = minVal;
    }
    log('saturates to $sum');
  } else {
    final range = maxVal - minVal + 1;
    if (sum > maxVal) {
      sum = (sum - maxVal - 1) % range + minVal;
    } else if (sum < minVal) {
      sum = maxVal - (minVal - sum - 1) % range;
    }
    log('rolls-over to $sum');
  }

  return sum;
}

SumInterface genRandomInterface(Random rand) {
  final isFixed = rand.nextBool();
  return SumInterface(
    fixedAmount: isFixed ? rand.nextInt(100) : null,
    width: isFixed ? null : rand.nextInt(8),
    increments: rand.nextBool(),
    hasEnable: rand.nextBool(),
  );
}

List<SumInterface> genRandomInterfaces(Random rand) {
  final numInterfaces = rand.nextInt(8) + 1;
  return List.generate(numInterfaces, (_) => genRandomInterface(rand));
}

void checkCounter(Counter counter) {
  final sub = counter.clk.posedge.listen((_) async {
    final expected = counter.reset.previousValue!.toBool()
        ? 0
        : goldenSum(
            counter.interfaces,
            width: counter.width,
            saturates: counter.saturates,
            minVal: counter.minValueLogic.value.toInt(),
            maxVal: counter.maxValueLogic.value.toInt(),
            initialValue: (counter.restart?.previousValue!.toBool() ?? false)
                ? counter.initialValueLogic.value.toInt()
                : counter.count.previousValue!.toInt(),
          );

    if (!counter.reset.previousValue!.toBool()) {
      final actual = counter.count.value.toInt();

      // print('$expected -- $actual');
      expect(actual, expected);
    }
  });

  Simulator.registerEndOfSimulationAction(() async {
    await sub.cancel();
  });
}

({
  List<SumInterface> interfaces,
  int? width,
  bool saturates,
  int? minVal,
  int? maxVal,
  int initialVal,
  dynamic minValue,
  dynamic maxValue,
  dynamic initialValue,
}) genRandomSummationConfiguration(Random rand) {
  final interfaces = genRandomInterfaces(rand);

  final width = rand.nextBool() ? null : rand.nextInt(10) + 1;

  final saturates = rand.nextBool();
  var minVal = rand.nextBool() ? rand.nextInt(30) : 0;
  var maxVal = rand.nextBool()
      ? rand.nextInt(width == null ? 70 : ((1 << width) - 1)) + minVal + 1
      : null;
  var initialVal = rand.nextBool() ? rand.nextInt(maxVal ?? 100) : 0;

  if (maxVal != null && width != null) {
    // truncate to width
    maxVal = max(1, LogicValue.ofInt(maxVal, width).toInt());
  }

  if (width != null) {
    // truncate to width
    initialVal = LogicValue.ofInt(initialVal, width).toInt();
  }

  if (maxVal == null || minVal >= maxVal) {
    if (maxVal == null && width == null) {
      minVal = 0;
    } else {
      minVal = rand.nextInt(maxVal ?? (width == null ? 0 : (1 << width) - 1));
    }
  }

  int safeWidthFor(int val) {
    final lv = LogicValue.ofInferWidth(val);
    final inferredWidth = lv.width;

    return min(max(inferredWidth, 1), width ?? inferredWidth);
  }

  final maxValue = maxVal != null && rand.nextBool()
      ? Const(LogicValue.ofInferWidth(maxVal), width: safeWidthFor(maxVal))
      : maxVal;
  final minValue = rand.nextBool()
      ? Const(LogicValue.ofInferWidth(minVal), width: safeWidthFor(minVal))
      : minVal;
  final initialValue = rand.nextBool()
      ? Const(LogicValue.ofInferWidth(initialVal),
          width: safeWidthFor(initialVal))
      : initialVal;

  return (
    interfaces: interfaces,
    width: width,
    saturates: saturates,
    minVal: minVal,
    maxVal: maxVal,
    initialVal: initialVal,
    minValue: minValue,
    maxValue: maxValue,
    initialValue: initialValue,
  );
}
