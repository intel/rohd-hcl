import 'package:bloc/bloc.dart';

/// The type of state the CounterCubit is managing is just an int
/// and the initial state is 0.
class SystemVerilogCubit extends Cubit<String> {
  SystemVerilogCubit(String rtl) : super(rtl);

  void setRTL(String rtl) {
    emit(rtl);
  }
}
