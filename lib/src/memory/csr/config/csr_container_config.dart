import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/memory/csr/csr_container.dart';

/// A base class for configs for [CsrContainer]s.
@immutable
abstract class CsrContainerConfig {
  /// Creates a clone of the configuration.
  CsrContainerConfig clone();

  /// Determines the minimum number of address bits needed to address all
  /// registers.
  int minAddrBits();

  /// Determines the maximum register size.
  int maxRegWidth();

  /// Name of the configuration.
  final String name;

  /// Creates a config for containers.
  const CsrContainerConfig({required this.name});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrContainerConfig && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}
