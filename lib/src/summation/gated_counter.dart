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

  //TODO: doc
  late final _incrementingInterfaces =
      interfaces.where((intf) => intf.increments);
  late final _decrementingInterfaces =
      interfaces.where((intf) => !intf.increments);

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

    // handle underflow case!
    // // if we're too small (i.e. )
    // final currentCountInDangerZone = ~count
    //     .getRange(
    //         log2Ceil(_decrementingInterfaces.length + 1), clkGatePartitionIndex)
    //     .or();

    // for (final intf in _decrementingInterfaces) {}

    // always enable during restart
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

    // the first bit of the total count that's "dangerous" for enabling clock
    final incrDangerZoneStart = max(
      0,
      clkGatePartitionIndex - log2Ceil(_incrementingInterfaces.length + 1),
    );

    final currentCountInIncrDangerZone =
        count.getRange(incrDangerZoneStart, clkGatePartitionIndex).or();

    Logic anyIntfInIncrDangerZone = Const(0);
    // for increments...
    for (final intf in _incrementingInterfaces) {
      // if we're in the danger zone, and interface is enabled, and the amount
      // also reaches into the danger range, then enable the upper gate

      var intfInDangerZone = intf.amount
          .getRange(
            min(incrDangerZoneStart, intf.width - 1),
            min(clkGatePartitionIndex, intf.amount.width),
          )
          .or();

      // always enable during restart
      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
      }

      anyIntfInIncrDangerZone |= intfInDangerZone;
    }
    upperEnable |= anyIntfInIncrDangerZone & currentCountInIncrDangerZone;

    // for decrements...

    // if any decrement is "big enough" while the lower bits are "small enough',
    // then we have to enable the upper region since it can roll-over

    // let's just draw the line half way for now?
    final decrDangerZoneStart = clkGatePartitionIndex ~/ 2;
    final currentCountInDecrDangerZone =
        ~count.getRange(decrDangerZoneStart, clkGatePartitionIndex).or();

    Logic anyIntfEndangersDecr = Const(0);
    for (final intf in _decrementingInterfaces) {
      var intfEndangersDecrZone = intf.amount
          .getRange(
            decrDangerZoneStart - log2Ceil(_decrementingInterfaces.length + 1),
            clkGatePartitionIndex,
          )
          .or();

      if (intf.hasEnable) {
        intfEndangersDecrZone &= intf.enable!;
      }

      anyIntfEndangersDecr |= intfEndangersDecrZone;
    }
    upperEnable |= anyIntfEndangersDecr & currentCountInDecrDangerZone;

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
