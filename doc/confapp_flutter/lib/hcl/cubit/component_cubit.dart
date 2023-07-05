import 'package:bloc/bloc.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:confapp_flutter/hcl/models/hcl_components.dart';

/// The type of state the CounterCubit is managing is just an int
/// and the initial state is 0.
class ComponentCubit extends Cubit<ConfigGenerator> {
  static final generator = WebPageGenerator();
  final ConfigGenerator selectedComponent;

  ComponentCubit(this.selectedComponent) : super(generator.components[0]);

  void setSelectedComponent(ConfigGenerator selectedComponent) {
    emit(selectedComponent);
  }
}
