// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_compute_primitives.dart
// Configurators for compute and fixed-latency components.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures an unsigned accumulator.
class AccumulatorConfigurator extends Configurator {
  /// Width of the accumulated value.
  final widthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of the amount input.
  final amountWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Whether accumulation saturates.
  final saturatesKnob = ToggleConfigKnob(value: false);

  /// Whether to include optional control inputs.
  final enableKnob = ToggleConfigKnob(value: false);

  /// Whether to include a clear input.
  final clearKnob = ToggleConfigKnob(value: false);

  /// Whether to include a restart input.
  final restartKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'accumulation';
  @override
  String get name => 'Accumulator';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Value Width': widthKnob,
        'Amount Width': amountWidthKnob,
        'Saturate': saturatesKnob,
        'Enable Input': enableKnob,
        'Clear Input': clearKnob,
        'Restart Input': restartKnob,
      };
  @override
  Module createModule() => Accumulator(
        Logic(name: 'amount', width: amountWidthKnob.value),
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        width: widthKnob.value,
        saturates: saturatesKnob.value,
        enable: enableKnob.value ? Logic(name: 'enable') : null,
        clear: clearKnob.value ? Logic(name: 'clear') : null,
        restart: restartKnob.value ? Logic(name: 'restart') : null,
      );
}

/// Configures numeric rounding and narrowing.
class NumericNarrowingConfigurator extends Configurator {
  /// Input and output widths.
  final inputWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Output width.
  final outputWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Bits discarded before rounding.
  final shiftKnob = NonNegativeIntConfigKnob(value: 0);

  /// Signed interpretation.
  final signedKnob = ToggleConfigKnob(value: false);

  /// Rounding policy.
  final roundingKnob = ChoiceConfigKnob<NumericRoundingMode>(
      NumericRoundingMode.values,
      value: NumericRoundingMode.truncate);

  /// Overflow policy.
  final overflowKnob = ChoiceConfigKnob<NumericOverflowMode>(
      NumericOverflowMode.values,
      value: NumericOverflowMode.wrap);

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'conversion';
  @override
  String get name => 'Numeric Narrowing';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Input Width': inputWidthKnob,
        'Output Width': outputWidthKnob,
        'Right Shift': shiftKnob,
        'Signed': signedKnob,
        'Rounding': roundingKnob,
        'Overflow': overflowKnob,
      };
  @override
  Module createModule() => NumericNarrowing(
        Logic(name: 'value', width: inputWidthKnob.value),
        outputWidth: outputWidthKnob.value,
        shiftRight: shiftKnob.value,
        signed: signedKnob.value,
        roundingMode: roundingKnob.value,
        overflowMode: overflowKnob.value,
      );
}

/// Configures a strict-majority function.
class MajorityConfigurator extends Configurator {
  /// Input width.
  final widthKnob = PositiveIntConfigKnob(value: 5);
  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'population-count';
  @override
  String get name => 'Majority';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Width': widthKnob};
  @override
  Module createModule() =>
      Majority(Logic(name: 'bits', width: widthKnob.value));
}

/// Configures first-match prefix selection.
class FirstMatchPrefixConfigurator extends Configurator {
  /// Number of lanes.
  final lanesKnob = PositiveIntConfigKnob(value: 8);
  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'search';
  @override
  String get name => 'First-Match Prefix';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Lanes': lanesKnob};
  @override
  Module createModule() => FirstMatchPrefix(
        eligibleMask: Logic(name: 'eligible', width: lanesKnob.value),
        matchMask: Logic(name: 'matches', width: lanesKnob.value),
      );
}

/// Configures a direct-control iterative divider.
class IterativeDividerEngineConfigurator extends Configurator {
  /// Width of each operand.
  final widthKnob = PositiveIntConfigKnob(value: 8);
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'division-and-roots';
  @override
  String get name => 'Iterative Divider Engine';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Width': widthKnob};
  @override
  Module createModule() => IterativeDividerEngine(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        start: Logic(name: 'start'),
        dividend: Logic(name: 'dividend', width: widthKnob.value),
        divisor: Logic(name: 'divisor', width: widthKnob.value),
        isSigned: Logic(name: 'isSigned'),
      );
}

/// Configures a ready/valid iterative divider.
class ReadyValidIterativeDividerConfigurator extends Configurator {
  /// Width of each operand.
  final widthKnob = PositiveIntConfigKnob(value: 8);
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'division-and-roots';
  @override
  String get name => 'Ready/Valid Iterative Divider';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Width': widthKnob};
  @override
  Module createModule() => ReadyValidIterativeDivider(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        upstream: IrrevocableReadyValidInterface(
            DivisionRequest(dataWidth: widthKnob.value)),
        downstream:
            ReadyValidInterface(DivisionResult(dataWidth: widthKnob.value)),
      );
}

/// Configures a valid-only carry-save multiplier.
class ValidOnlyCarrySaveMultiplierConfigurator extends Configurator {
  /// Width of each operand.
  final widthKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'multiplication';
  @override
  String get name => 'Valid-Only Carry-Save Multiplier';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Width': widthKnob};
  @override
  Module createModule() => ValidOnlyCarrySaveMultiplier(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        multiplicand: ValidOnlyInterface(Logic(width: widthKnob.value)),
        multiplier: ValidOnlyInterface(Logic(width: widthKnob.value)),
        product: ValidOnlyInterface(Logic(width: 2 * widthKnob.value)),
      );
}

/// Configures the protocol-neutral fixed-latency tracker.
class FixedLatencyTrackerConfigurator extends Configurator {
  /// Core latency.
  final latencyKnob = NonNegativeIntConfigKnob(value: 3);

  /// Minimum interval between requests.
  final intervalKnob = PositiveIntConfigKnob(value: 1);

  /// Number of outstanding requests.
  final capacityKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.flowControl;
  @override
  String get subcategory => 'control';
  @override
  String get name => 'Fixed-Latency Tracker';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Latency': latencyKnob,
        'Initiation Interval': intervalKnob,
        'Capacity': capacityKnob,
      };
  @override
  Module createModule() => FixedLatencyTracker(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        request: Logic(name: 'request'),
        retire: Logic(name: 'retire'),
        latency: latencyKnob.value,
        initiationInterval: intervalKnob.value,
        capacity: capacityKnob.value,
      );
}

/// Configures a ready/valid wrapper around an example fixed-latency delay.
class ReadyValidFixedLatencyConfigurator extends Configurator {
  /// Width of the example payload.
  final widthKnob = PositiveIntConfigKnob(value: 8);

  /// Delay of the example core.
  final latencyKnob = NonNegativeIntConfigKnob(value: 3);

  /// Minimum interval between requests.
  final intervalKnob = PositiveIntConfigKnob(value: 1);

  /// Number of outstanding requests.
  final capacityKnob = PositiveIntConfigKnob(value: 4);

  /// Whether to propagate request IDs.
  final useIdKnob = ToggleConfigKnob(value: false);

  /// Width of each request ID.
  final idWidthKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.flowControl;
  @override
  String get subcategory => 'ready-valid';
  @override
  String get name => 'Fixed-Latency Ready/Valid Delay Example';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Payload Width': widthKnob,
        'Latency': latencyKnob,
        'Initiation Interval': intervalKnob,
        'Capacity': capacityKnob,
        'Propagate ID': useIdKnob,
        if (useIdKnob.value) 'ID Width': idWidthKnob,
      };
  @override
  Module createModule() => ReadyValidFixedLatency<Logic, Logic>(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        upstream: ReadyValidInterface(Logic(width: widthKnob.value)),
        downstream: ReadyValidInterface(Logic(width: widthKnob.value)),
        latency: latencyKnob.value,
        initiationInterval: intervalKnob.value,
        capacity: capacityKnob.value,
        requestId: useIdKnob.value
            ? Logic(name: 'id', width: idWidthKnob.value)
            : null,
        coreIdentity: 'DelayExample',
        coreGenerator: (
            {required clk, required reset, required start, required data}) {
          var result = data;
          for (var stage = 0; stage < latencyKnob.value; stage++) {
            result = flop(clk, result);
          }
          return result;
        },
      );
}

/// Configures a standalone 4:2 compressor.
class Compressor4Configurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'multiplication';
  @override
  String get name => '4:2 Compressor';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {};
  @override
  Module createModule() =>
      Compressor4(Logic(name: 'bits', width: 4), Logic(name: 'carryIn'));
}
