import 'package:confapp_flutter/components/config.dart';

class SampleGenerator extends ConfigGenerator {
  final StringConfigKnob sampleKnob = StringConfigKnob('sampleKnob');

  @override
  final componentName = 'Sample';

  @override
  late final List<ConfigKnob> knobs = [sampleKnob];

  @override
  Future<String> generate() async {
    return 'component 1 system verilog';
  }
}
