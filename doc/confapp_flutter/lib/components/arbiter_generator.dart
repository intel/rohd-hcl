import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd/rohd.dart';
import 'package:confapp_flutter/components/config.dart';

class PriorityArbiterComponent extends Module {
  late final PriorityArbiter priorityArb;
  PriorityArbiterComponent(int numOfRequest) {
    final reqs = List.generate(numOfRequest, (i) => Logic());

    priorityArb = PriorityArbiter(reqs);
  }
}

class PriorityArbiterGenerator extends ConfigGenerator {
  final IntConfigKnob numRequestKnob =
      IntConfigKnob('numRequest', defaultVal: 5);

  @override
  final componentName = 'Priority Arbiter';

  @override
  late final List<ConfigKnob> knobs = [numRequestKnob];

  @override
  Future<String> generate() async {
    var priorityArbiter =
        PriorityArbiterComponent(numRequestKnob.value).priorityArb;

    await priorityArbiter.build();
    return priorityArbiter.generateSynth();
  }
}
