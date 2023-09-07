import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:confapp_flutter/hcl/models/hcl_components.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

class ComponentModel extends ChangeNotifier {
  final components = WebPageGenerator();
  late Configurator selectedComponent = components.components[0];

  UnmodifiableListView<Configurator> get generators =>
      UnmodifiableListView(components.components);

  Configurator get currComponent => selectedComponent;

  void setComponent(Configurator component) {
    selectedComponent = component;
    notifyListeners();
  }

  void removeAll() {
    notifyListeners();
  }
}
