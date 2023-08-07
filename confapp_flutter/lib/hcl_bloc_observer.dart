import 'package:bloc/bloc.dart';

/// [BlocObserver] observe all state changes in the application.
class HCLBlocObserver extends BlocObserver {
  const HCLBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    print('${bloc.runtimeType} $change');
  }
}
