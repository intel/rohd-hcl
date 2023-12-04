abstract class ConfigKnob<T> {
  T value;
  ConfigKnob({required this.value});

  Map<String, dynamic> toJson() => {'value': value};

  void loadJson(Map<String, dynamic> decodedJson) {
    value = decodedJson['value'] as T;
  }
}
