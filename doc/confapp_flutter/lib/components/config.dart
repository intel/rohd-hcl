abstract class ConfigKnob<T> {
  final String name;
  T? value;

  ConfigKnob(this.name);
}

class IntConfigKnob<int> extends ConfigKnob {
  IntConfigKnob(super.name);
}

class StringConfigKnob<String> extends ConfigKnob {
  StringConfigKnob(super.name);
}

abstract class ConfigGenerator {
  String get componentName;
  List<ConfigKnob> get knobs;
  Future<String> generate();
}
