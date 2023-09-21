import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class PriorityArbiterConfigurator extends Configurator {
  final IntConfigKnob numRequestKnob = IntConfigKnob(value: 4);

  @override
  final name = 'Priority Arbiter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Number of Requestors': numRequestKnob,
  };

  @override
  Module createModule() {
    final reqs = List.generate(numRequestKnob.value, (i) => Logic());
    return PriorityArbiter(reqs);
  }

  @override
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}
