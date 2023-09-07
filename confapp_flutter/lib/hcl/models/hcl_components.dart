import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/component_config.dart';

class WebPageGenerator {
  final List<Configurator> components = [
    RotateConfigurator(),
    PriorityArbiterConfigurator(),
    RippleCarryAdderConfigurator(),
    PipelinedIntegerMultiplierConfigurator(),
    BitonicSortConfigurator(),
  ];
}
