import 'package:bloc/bloc.dart';
import 'package:confapp/main.dart';

enum GenerationState { initial, loading, done }

class SystemVerilogCubitState {
  final String systemVerilog;
  final GenerationState generationState;
  const SystemVerilogCubitState(
      {required this.systemVerilog, required this.generationState});
  const SystemVerilogCubitState.loading()
      : this(
            systemVerilog: 'Loading...',
            generationState: GenerationState.loading);
  const SystemVerilogCubitState.done(String systemVerilog)
      : this(
            systemVerilog: systemVerilog,
            generationState: GenerationState.done);
  const SystemVerilogCubitState.initial()
      : this(
            systemVerilog: 'Click "Generate RTL"!',
            generationState: GenerationState.initial);
}

/// Controls the generated SystemVerilog to display
class SystemVerilogCubit extends Cubit<SystemVerilogCubitState> {
  SystemVerilogCubit() : super(const SystemVerilogCubitState.loading()) {
    initializeData();
  }

  void initializeData() async {
    emit(const SystemVerilogCubitState.initial());
  }

  void setLoading() {
    emit(const SystemVerilogCubitState.loading());
  }

  void setRTL(String rtl) {
    emit(SystemVerilogCubitState.done(rtl));
  }
}
