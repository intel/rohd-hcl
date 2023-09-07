import 'package:bloc/bloc.dart';
import 'package:confapp_flutter/hcl/cubit/component_cubit.dart';

/// Controls the generated SystemVerilog to display
class SystemVerilogCubit extends Cubit<String> {
  SystemVerilogCubit() : super('Loading') {
    initializeData();
  }

  void initializeData() async {
    // TODO(quek): bad Practice: A cubit not supposed to call another cubit,
    // need to do seperation of concern.
    final intialComponent = ComponentCubit.generator.components[0];
    final initialState = await intialComponent.generateSV();
    emit(initialState);
  }

  void setRTL(String rtl) {
    emit(rtl);
  }
}
