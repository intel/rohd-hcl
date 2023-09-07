import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp_flutter/app.dart';
import 'package:confapp_flutter/hcl_bloc_observer.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

final List<Configurator> hclComponents = [
  RotateConfigurator(),
  PriorityArbiterConfigurator(),
  RippleCarryAdderConfigurator(),
  PipelinedIntegerMultiplierConfigurator(),
  BitonicSortConfigurator(),
];

void main() {
  /// Initializing the [BlocObserver] created and calling runApp
  Bloc.observer = const HCLBlocObserver();

  runApp(HCLApp(
    components: hclComponents,
  ));
}
