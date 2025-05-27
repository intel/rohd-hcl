import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configuration for an architectural register.
///
/// Any architecturally fixed fields can be added directly to this class,
/// but any fields with implementation specific config should be
/// left until the instantiation of the register.
@immutable
class CsrConfig {
  /// Name for the register.
  final String name;

  /// Access rule for the register.
  final CsrAccess access;

  /// Architectural reset value for the register.
  ///
  /// Note that this can be overridden in the instantiation of the register.
  late final int resetValue = _resetValue ?? _resetValueFromFields();
  final int? _resetValue;

  /// Architectural property in which the register can be frontdoor read.
  ///
  /// A frontdoor read occurs explicitly using the register's address.
  final bool isFrontdoorReadable;

  /// Architectural property in which the register can be frontdoor written.
  ///
  /// A frontdoor write occurs explicitly using the register's address.
  final bool isFrontdoorWritable;

  /// Architectural property in which the register can be backdoor read.
  ///
  /// A backdoor read exposes the register's value combinationally to the HW.
  final bool isBackdoorReadable;

  /// Architectural property in which the register can be backdoor written.
  ///
  /// A backdoor write exposes direct write access to the HW through an enable.
  final bool isBackdoorWritable;

  /// Fields in this register.
  late final List<CsrFieldConfig> fields;

  /// Construct a new register configuration.
  CsrConfig({
    required this.name,
    required this.access,
    required List<CsrFieldConfig> fields,
    int? resetValue,
    this.isFrontdoorReadable = true,
    this.isFrontdoorWritable = true,
    this.isBackdoorReadable = true,
    this.isBackdoorWritable = true,
  })  : fields = List.unmodifiable(fields),
        _resetValue = resetValue {
    _validate();
  }

  /// Accessor to the config of a particular field
  /// within the register by name [name].
  CsrFieldConfig getFieldByName(String name) =>
      fields.firstWhere((element) => element.name == name);

  /// Helper to derive a reset value for the register from its fields.
  ///
  /// Only should be used if a reset value isn't explicitly provided.
  int _resetValueFromFields() {
    var rv = 0;
    for (final field in fields) {
      rv |= field.resetValue << field.start;
    }
    return rv;
  }

  /// Method to validate the configuration of a single register.
  ///
  /// Must check that its fields are mutually valid.
  void _validate() {
    final ranges = <List<int>>[];
    final issues = <String>[];
    for (final field in fields) {
      // check to ensure that the field doesn't overlap with any other field
      // overlap can occur on name or on bit placement
      for (var i = 0; i < ranges.length; i++) {
        // check against all other names
        if (field.name == fields[i].name) {
          issues.add('Field ${field.name} is duplicated.');
        }
        // check field start to see if it falls within another field
        else if (field.start >= ranges[i][0] && field.start <= ranges[i][1]) {
          issues.add(
              'Field ${field.name} overlaps with field ${fields[i].name}.');
        }
        // check field end to see if it falls within another field
        else if (field.start + field.width - 1 >= ranges[i][0] &&
            field.start + field.width - 1 <= ranges[i][1]) {
          issues.add(
              'Field ${field.name} overlaps with field ${fields[i].name}.');
        }
      }
      ranges.add([field.start, field.start + field.width - 1]);
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
    }
  }

  /// Clones this configuration with the provided overrides.
  CsrConfig clone({
    String? name,
    CsrAccess? access,
    int? resetValue,
    List<CsrFieldConfig>? fields,
    bool? isFrontdoorReadable,
    bool? isFrontdoorWritable,
    bool? isBackdoorReadable,
    bool? isBackdoorWritable,
  }) =>
      CsrConfig(
        name: name ?? this.name,
        access: access ?? this.access,
        resetValue: resetValue ?? _resetValue,
        fields: fields ?? this.fields,
        isFrontdoorReadable: isFrontdoorReadable ?? this.isFrontdoorReadable,
        isFrontdoorWritable: isFrontdoorWritable ?? this.isFrontdoorWritable,
        isBackdoorReadable: isBackdoorReadable ?? this.isBackdoorReadable,
        isBackdoorWritable: isBackdoorWritable ?? this.isBackdoorWritable,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrConfig &&
        other.name == name &&
        other.access == access &&
        other.resetValue == resetValue &&
        other.isFrontdoorReadable == isFrontdoorReadable &&
        other.isFrontdoorWritable == isFrontdoorWritable &&
        other.isBackdoorReadable == isBackdoorReadable &&
        other.isBackdoorWritable == isBackdoorWritable &&
        const DeepCollectionEquality().equals(other.fields, fields);
  }

  @override
  int get hashCode =>
      name.hashCode ^
      access.hashCode ^
      resetValue.hashCode ^
      isFrontdoorReadable.hashCode ^
      isFrontdoorWritable.hashCode ^
      isBackdoorReadable.hashCode ^
      isBackdoorWritable.hashCode ^
      const DeepCollectionEquality().hash(fields);
}
