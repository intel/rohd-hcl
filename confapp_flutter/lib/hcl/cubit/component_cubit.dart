import 'package:bloc/bloc.dart';
import 'package:confapp_flutter/hcl/models/hcl_components.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Controls the selected component.
class ComponentCubit extends Cubit<Configurator> {
  static final generator = WebPageGenerator();
  Configurator selectedComponent;

  ComponentCubit(this.selectedComponent) : super(generator.components[0]);

  void setSelectedComponent(Configurator selectedComponent) {
    this.selectedComponent = selectedComponent;
    emit(selectedComponent);
  }
}
