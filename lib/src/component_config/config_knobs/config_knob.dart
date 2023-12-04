abstract class ConfigKnob<T> {
  T value;
  ConfigKnob({required this.value});

  void loadJson(Map<String, dynamic> decodedJson) {
    value = decodedJson['value'] as T;
  }

  @override
  Map<String, dynamic> toJson() => {'value': value};
}
