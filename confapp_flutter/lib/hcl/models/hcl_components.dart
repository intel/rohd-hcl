import 'package:confapp_flutter/components/config.dart';
import 'package:confapp_flutter/components/components.dart';

class WebPageGenerator {
  final List<ConfigGenerator> components = [
    RotateGenerator(),
    PriorityArbiterGenerator(),
    RippleCarryAdderGenerator(),
    PipelinedIntegerMultiplierGenerator(),
    BitonicSortGenerator(),
  ];
}
