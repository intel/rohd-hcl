abstract class ConfigKnob<T> {
  final String name;
  T? value;
  T defaultVal;

  ConfigKnob(this.name, {required this.defaultVal});
}

class IntConfigKnob<int> extends ConfigKnob {
  IntConfigKnob(super.name, {required super.defaultVal});
}

class StringConfigKnob<String> extends ConfigKnob {
  StringConfigKnob(super.name, {required super.defaultVal});
}

abstract class ConfigGenerator {
  String get componentName;
  List<ConfigKnob> get knobs;
  Future<String> generate();
}
