import 'package:confapp_flutter/hcl/cubit/system_verilog_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confapp_flutter/hcl/cubit/component_cubit.dart';
import 'hcl_view.dart';

class HCLPage extends StatelessWidget {
  /// {@macro counter_page}
  const HCLPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          // Look pretty ungly using static, not sure how to improve this
          create: (BuildContext context) =>
              ComponentCubit(ComponentCubit.generator.components[0]),
        ),
        BlocProvider(
          create: (BuildContext context) => SystemVerilogCubit(),
        ),
      ],
      child: const HCLView(),
    );
  }
}
