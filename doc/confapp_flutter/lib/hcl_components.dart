import 'package:confapp_flutter/components/config.dart';
import 'package:confapp_flutter/components/components.dart';
import 'package:confapp_flutter/components/ripple_carry_adder_generator.dart';

class WebPageGenerator {
  final List<ConfigGenerator> generators = [
    RotateGenerator(),
    PriorityArbiterGenerator(),
    RippleCarryAdderGenerator(),
    PipelinedIntegerMultiplierGenerator(),
    BitonicSortGenerator(),
  ];
}
