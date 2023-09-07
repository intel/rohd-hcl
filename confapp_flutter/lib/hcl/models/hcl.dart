import 'package:equatable/equatable.dart';
import 'package:confapp_flutter/hcl/models/hcl_components.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Try with selected component first, later only add the new one.
class HCLModel extends Equatable {
  HCLModel({required this.selectedComponent});

  final _generator = WebPageGenerator();
  final Configurator selectedComponent;

  List<Configurator> get components => _generator.components;

  @override
  List<Object> get props => [selectedComponent];
}
