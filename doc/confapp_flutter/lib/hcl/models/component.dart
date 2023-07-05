import 'dart:collection';

import 'package:confapp_flutter/components/config.dart';
import 'package:flutter/foundation.dart';
import 'package:confapp_flutter/hcl/models/hcl_components.dart';

class ComponentModel extends ChangeNotifier {
  final components = WebPageGenerator();
  late ConfigGenerator selectedComponent = components.components[0];

  UnmodifiableListView<ConfigGenerator> get generators =>
      UnmodifiableListView(components.components);

  ConfigGenerator get currComponent => selectedComponent;

  void setComponent(ConfigGenerator component) {
    selectedComponent = component;
    notifyListeners();
  }

  void removeAll() {
    notifyListeners();
  }
}
