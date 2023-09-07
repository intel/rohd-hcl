import 'package:bloc/bloc.dart';
import 'package:confapp_flutter/hcl/cubit/component_cubit.dart';
import 'package:confapp_flutter/main.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Controls the generated SystemVerilog to display
class SystemVerilogCubit extends Cubit<String> {
  SystemVerilogCubit() : super('Loading') {
    initializeData();
  }

  void initializeData() async {
    final intialComponent = hclComponents.first;
    final initialState = await intialComponent.generateSV();
    emit(initialState);
  }

  void setRTL(String rtl) {
    emit(rtl);
  }
}
