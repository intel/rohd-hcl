import 'package:flutter/material.dart';
import 'package:confapp_flutter/hcl/hcl.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class HCLApp extends MaterialApp {
  HCLApp({super.key, required List<Configurator> components})
      : super(
            home: HCLPage(
          components: components,
        ));
}
