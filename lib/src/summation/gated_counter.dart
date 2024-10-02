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

            intf.amount <=
                ToggleGate(
                  enable: e.enable!,
                  data: e.amount,
                  clk: clk,
                  reset: reset,
                  clockGateControlIntf: _clockGateControlInterface,
                ).gatedData;
          } else if (intf.fixedAmount == null) {
            intf.amount <= e.amount;
          }

          return intf;
        }).toList()
      : super.interfaces;

  late final int clkGatePartitionIndex;
  int? _providedClkGateParitionIndex;

  /// TODO
  ///
  /// If the [clkGatePartitionIndex] is less than 0 or greater than the [width],
  /// then the entire counter will be gated together rather than partitioned. If
  /// no [clkGatePartitionIndex] is provided, the counter will attempt to infer
  /// a good partition index based on the interfaces provided.
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
    this.sameCycleClockGate = true, //TODO: ditch this?
    int? clkGatePartitionIndex,
    super.name,
  }) : _providedClkGateParitionIndex = clkGatePartitionIndex {
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

  late final Logic _mayOverflow = Logic(name: 'mayOverflow')
    ..gets(_calculateMayOverflow());

  Logic _calculateMayOverflow() {
    if (saturates) {
      // if this is a saturating counter, we will never wrap-around
      return Const(0);
    }

    if (_incrementingInterfaces.isEmpty) {
      // if we never increment, no chance of overflow
      return Const(0);
    }

    if (constantMaxValue == null) {
      // for now, this is hard to handle, so just always maybe overflow if
      // anything is incrementing
      return _anyIncrements;
    }

    final maxValueBit = LogicValue.ofInferWidth(constantMaxValue).width - 1;

    final overflowDangerZoneStart = max(
      maxValueBit - log2Ceil(_incrementingInterfaces.length + 1) - 1,
      0,
    );

    final counterInOverflowDangerZone =
        count.getRange(overflowDangerZoneStart).or();

    Logic anyIntfInIncrDangerZone = Const(0);

    for (final intf in _incrementingInterfaces) {
      // if we're in the danger zone, and interface is enabled, and the amount
      // also reaches into the danger range

      if (intf.width <= overflowDangerZoneStart) {
        // if it's too short, don't worry about it
        continue;
      }

      var intfInDangerZone = intf.amount
          .getRange(
            overflowDangerZoneStart,
            width,
          )
          .or();

      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
      }

      anyIntfInIncrDangerZone |= intfInDangerZone;
    }

    // if *any* interface is incrementing at all and upper-most bit(s) is 1,
    // then we may overflow
    Logic anyIntfIncrementing = Const(0);
    for (final intf in _incrementingInterfaces) {
      var intfIsIncrementing = intf.amount.or();
      if (intf.hasEnable) {
        intfIsIncrementing &= intf.enable!;
      }
      //TODO: doc instantiation of ROHD modules

      anyIntfIncrementing |= intfIsIncrementing;
    }
    final topMayOverflow =
        anyIntfIncrementing & count.getRange(maxValueBit, width).or();

    return topMayOverflow |
        (anyIntfInIncrDangerZone & counterInOverflowDangerZone);
  }

  late final Logic _mayUnderflow = Logic(name: 'mayUnderflow')
    ..gets(_calculateMayUnderflow());

  Logic _calculateMayUnderflow() {
    if (saturates) {
      // if this is a saturating counter, we will never wrap-around
      return Const(0);
    }

    if (_decrementingInterfaces.isEmpty) {
      // if we never decrement, no chance of underflow
      return Const(0);
    }

    if (constantMinValue == null) {
      // for now, this is hard to handle, so just always maybe underflow if
      // anything is decrementing
      return _anyDecrements;
    }

    final minValueBit = LogicValue.ofInferWidth(constantMinValue).width - 1;

    // if we're close enough to the minimum value (as judged by upper bits being
    // 0), and we are decrementing by a sufficiently large number (as judged by
    // enough lower bits of decr interfaces), then we may underflow

    final underflowDangerBit =
        minValueBit + log2Ceil(_decrementingInterfaces.length + 1);
    final inUnderflowDangerZone = underflowDangerBit >= count.width
        ? Const(1)
        : ~count
            .getRange(
                minValueBit + log2Ceil(_decrementingInterfaces.length + 1))
            .or();

    Logic anyIntfInDangerZone = Const(0);
    for (final intf in _decrementingInterfaces) {
      var intfInDangerZone = intf.amount.getRange(minValueBit).or();

      if (intf.hasEnable) {
        intfInDangerZone &= intf.enable!;
      }

      anyIntfInDangerZone |= intfInDangerZone;
    }

    return anyIntfInDangerZone & inUnderflowDangerZone;
  }

  late final _mayWrap = Logic(name: 'mayWrap')
    ..gets(_mayUnderflow | _mayOverflow);

  @protected
  late final lowerEnable = Logic(name: 'lowerEnable')
    ..gets(_calculateLowerEnable());

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

    lowerEnable |= _mayWrap;

    if (saturates) {
      lowerEnable &= ~(equalsMin & ~_anyIncrements);
    }

    // always enable during restart
    if (restart != null) {
      lowerEnable |= restart!;
    }

    return lowerEnable;
  }

  late final _anyDecrements = Logic(name: 'anyDecrements')
    ..gets(_decrementingInterfaces
        .map((intf) => intf.amount.or() & (intf.enable ?? Const(1)))
        .toList()
        .swizzle()
        .or());

  late final _anyIncrements = Logic(name: 'anyIncrements')
    ..gets(_incrementingInterfaces
        .map((intf) => intf.amount.or() & (intf.enable ?? Const(1)))
        .toList()
        .swizzle()
        .or());

  @protected
  late final upperEnable = Logic(name: 'upperEnable')
    ..gets(_calculateUpperEnable());

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

    final currentCountInIncrDangerZone = count
        .getRange(
          min(incrDangerZoneStart, width),
          min(clkGatePartitionIndex, width),
        )
        .or();

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
    final currentCountInDecrDangerZone = ~count
        .getRange(
          min(width, decrDangerZoneStart),
          min(width, clkGatePartitionIndex),
        )
        .or();

    Logic anyIntfEndangersDecr = Const(0);
    for (final intf in _decrementingInterfaces) {
      var intfEndangersDecrZone = intf.amount
          .getRange(
            min(
                intf.width,
                max(
                    0,
                    decrDangerZoneStart -
                        log2Ceil(_decrementingInterfaces.length + 1))),
            min(intf.width, clkGatePartitionIndex),
          )
          .or();

      if (intf.hasEnable) {
        intfEndangersDecrZone &= intf.enable!;
      }

      anyIntfEndangersDecr |= intfEndangersDecrZone;
    }
    upperEnable |= anyIntfEndangersDecr & currentCountInDecrDangerZone;

    upperEnable |= _mayWrap;

    if (saturates) {
      upperEnable &= ~(equalsMax & ~_anyDecrements);
    }

    // always enable during restart
    if (restart != null) {
      upperEnable |= restart!;
    }

    return upperEnable;
  }

  // hooks for testbenches and subclasses
  @protected
  late final Logic lowerGatedClock;
  @protected
  late final Logic upperGatedClock;

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

    clkGatePartitionIndex =
        _providedClkGateParitionIndex ?? _pickPartitionIndex();

    if (clkGatePartitionIndex >= width || clkGatePartitionIndex < 0) {
      // just gate the whole thing together
      final clkGate = ClockGate(clk,
          enable: lowerEnable | upperEnable,
          reset: reset,
          controlIntf: _clockGateControlInterface);

      lowerGatedClock = clkGate.gatedClk;
      upperGatedClock = clkGate.gatedClk;

      count <=
          flop(
            clkGate.gatedClk,
            sum,
            reset: reset,
            resetValue: initialValueLogic,
          );
    } else {
      final lowerClkGate = ClockGate(clk,
          enable: lowerEnable,
          reset: reset,
          controlIntf: _clockGateControlInterface,
          name: 'lower_clock_gate');

      final upperClkGate = ClockGate(clk,
          enable: upperEnable,
          reset: reset,
          controlIntf: _clockGateControlInterface,
          name: 'upper_clock_gate');

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

      lowerGatedClock = lowerClkGate.gatedClk;
      upperGatedClock = upperClkGate.gatedClk;

      count <= [upperCount, lowerCount].swizzle();
    }
  }

  int _pickPartitionIndex() {
    //TODO: make this a better estimate
    return width ~/ 2;
  }
}
