import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp_flutter/app.dart';
import 'package:confapp_flutter/hcl_bloc_observer.dart';

void main() {
  /// Initializing the [BlocObserver] created and calling runApp
  Bloc.observer = const HCLBlocObserver();
  runApp(const HCLApp());
}
