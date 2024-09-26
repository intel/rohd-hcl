import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class GatedCounter extends Counter {
  final bool gateToggles;

  final bool sameCycleClockGate;

  ClockGateControlInterface? _clockGateControlInterface;

  @override
  @protected
  List<SumInterface> get interfaces => _interfaces;
  late final _interfaces = gateToggles
      ? super.interfaces.map((e) {
          final intf = SumInterface.clone(e);

          intf.enable?.gets(e.enable!);

          if (intf.hasEnable && intf.fixedAmount == null) {
            // only need to ungate if enable is high
            final gateEnable = intf.enable!;

            final intfGatedClk = sameCycleClockGate
                ? ClockGate(clk,
                        enable: gateEnable,
                        reset: reset,
                        controlIntf: _clockGateControlInterface)
                    .gatedClk
                : clk;

            intf.amount <=
                ToggleGate(
                        enable: gateEnable,
                        data: intf.amount,
                        clk: intfGatedClk)
                    .gatedData;
          } else if (intf.fixedAmount == null) {
            intf.amount <= e.amount;
          }

          return intf;
        }).toList()
      : super.interfaces;

  final int clkGatePartitionIndex;

  GatedCounter(
    super.interfaces, {
    required super.clk,
    required super.reset,
    super.restart,
    super.resetValue,
    super.maxValue,
    super.minValue,
    super.width,
    super.saturates,
    this.gateToggles = true,
    ClockGateControlInterface? clockGateControlInterface,
    this.sameCycleClockGate = true,
    int? clkGatePartitionIndex,
    super.name,
  }) : clkGatePartitionIndex =
            clkGatePartitionIndex ?? _minPartitionIndex(interfaces) {
    if (clockGateControlInterface != null) {
      clockGateControlInterface =
          ClockGateControlInterface.clone(clockGateControlInterface)
            ..pairConnectIO(this, clockGateControlInterface, PairRole.consumer);
    } else {
      clockGateControlInterface = ClockGateControlInterface(isPresent: false);
    }
  }

  Logic _calculateLowerEnable() {
    Logic lowerEnable = Const(0); // default, not enabled

    // if any interface is enabled and has any 1's in the lower bits, enable
    for (final intf in interfaces) {
      var intfHasLowerBits = intf.amount
          .getRange(0, min(clkGatePartitionIndex, intf.amount.width))
          .or();

      if (intf.hasEnable) {
        intfHasLowerBits &= intf.enable!;
      }

      lowerEnable |= intfHasLowerBits;
    }

    if (restart != null) {
      lowerEnable |= restart!;
    }

    return lowerEnable;
  }

  Logic _calculateUpperEnable() {
    Logic upperEnable = Const(0); // default, not enabled

    // if any interface is enabled and has any 1's in the upper bits, enable
    for (final intf in interfaces) {
      var intfHasUpperBits = intf.amount
          .getRange(min(clkGatePartitionIndex, intf.amount.width))
          .or();

      if (intf.hasEnable) {
        intfHasUpperBits &= intf.enable!;
      }

      upperEnable |= intfHasUpperBits;
    }

    final incrementingInterfaces = interfaces.where((intf) => intf.increments);

    // the first bit of the total count that's "dangerous" for enabling clock
    final dangerZoneStart = max(
      0,
      clkGatePartitionIndex - log2Ceil(incrementingInterfaces.length + 1),
    );

    final currentCountInDangerZone =
        count.getRange(dangerZoneStart, clkGatePartitionIndex).or();

    Logic anyIntfInDangerZone = Const(0);
    // for increments...
    for (final intf in incrementingInterfaces) {
      // if we're in the danger zone, and interface is enabled, and the amount
      // also reaches into the danger range, then enable the upper gate

      var intfInDangerZone = intf.amount
          .getRange(
            min(dangerZoneStart, intf.width - 1),
            min(clkGatePartitionIndex, intf.amount.width),
          )
          .or();

      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
      }

      anyIntfInDangerZone |= intfInDangerZone;
    }
    upperEnable |= (anyIntfInDangerZone & currentCountInDangerZone);

    // for decrements...

    if (restart != null) {
      upperEnable |= restart!;
    }

    return upperEnable;
  }

  @protected
  @override
  void buildFlops(Logic sum) {
    // TODO: if we can do same-cycle clock gating, then we have the chance to
    //  compare the size of the increment... otherwise, we need to assume it
    //  could be maximum

    //TODO: what about UNDERFLOW???
    // initial value?
    // saturation? --> maybe it never can hit certain bits, always gate them?

    //if nothing *above* the partition in the increment bus is high, then we dont need to enable the upper gate

    // we could gate LOWER bits also, if we're only incrementing by a large amount!

    //some cases:
    // - no clkGateIndex provided -> infer a good one
    // - index provided and samecycle is ok -> use it
    // - index provided and no samecycle and index less than inferred min -> exception

    final lowerClkGate = ClockGate(clk,
        enable: _calculateLowerEnable(),
        reset: reset,
        controlIntf: _clockGateControlInterface);

    final upperClkGate = ClockGate(clk,
        enable: _calculateUpperEnable(),
        reset: reset,
        controlIntf: _clockGateControlInterface);

    final lowerCount = flop(
      lowerClkGate.gatedClk,
      sum.getRange(0, clkGatePartitionIndex),
      reset: reset,
      resetValue: initialValueLogic.getRange(0, clkGatePartitionIndex),
    );

    final upperCount = flop(
      upperClkGate.gatedClk,
      sum.getRange(clkGatePartitionIndex),
      reset: reset,
      resetValue: initialValueLogic.getRange(clkGatePartitionIndex),
    );

    count <= [upperCount, lowerCount].swizzle();
  }

  static int _minPartitionIndex(List<SumInterface> interfaces) {
    final maxIncr = interfaces
        .where((e) => e.increments)
        .map((e) => e.maxIncrementMagnitude)
        .reduce((a, b) => a + b);

    return LogicValue.ofInferWidth(maxIncr + BigInt.one).clog2().toInt();
  }
}
