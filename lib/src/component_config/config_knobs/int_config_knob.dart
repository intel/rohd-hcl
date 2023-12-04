import 'package:rohd_hcl/rohd_hcl.dart';

class IntConfigKnob extends ConfigKnob<int> {
  IntConfigKnob({required super.value});

  Map<String, dynamic> toJson() =>
      {'value': value > 16 ? '0x${value.toRadixString(16)}' : value};

  void loadJson(Map<String, dynamic> decodedJson) {
    final val = decodedJson['value'];
    if (val is String) {
      value = int.parse(val);
    } else {
      value = val as int;
    }
  }
}
