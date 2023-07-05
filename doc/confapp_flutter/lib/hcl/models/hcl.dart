import 'package:equatable/equatable.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:confapp_flutter/hcl/models/hcl_components.dart';

/// Try with selected component first, later only add the new one.
final class HCLModel extends Equatable {
  HCLModel({required this.selectedComponent});

  final _generator = WebPageGenerator();
  final ConfigGenerator selectedComponent;

  List<ConfigGenerator> get components => _generator.components;

  @override
  List<Object> get props => [selectedComponent];
}
