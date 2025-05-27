import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/csr/config/csr_container_config.dart';

/// Definition for a coherent block of registers.
///
/// Blocks by definition are instantiations of registers and
/// hence require CsrInstanceConfig objects.
/// This class is also where the choice to instantiate
/// any conditional registers should take place.
@immutable
class CsrBlockConfig extends CsrContainerConfig {
  /// Address off of which all register addresses are offset.
  final int baseAddr;

  /// Registers in this block.
  final List<CsrInstanceConfig> registers;

  /// Construct a new block configuration.
  CsrBlockConfig({
    required super.name,
    required this.baseAddr,
    required List<CsrInstanceConfig> registers,
  }) : registers = List.unmodifiable(registers) {
    // validate the block
    _validate();
  }

  /// Accessor to the config of a particular register
  /// within the block by name [name].
  CsrInstanceConfig getRegisterByName(String name) =>
      registers.firstWhere((element) => element.name == name);

  /// Accessor to the config of a particular register
  /// within the block by relative address [addr].
  CsrInstanceConfig getRegisterByAddr(int addr) =>
      registers.firstWhere((element) => element.addr == addr);

  /// Method to validate the configuration of a single register block.
  ///
  /// Must check that its registers are mutually valid.
  /// Note that this method does not call the validate method of
  /// the individual registers in the block. It is assumed that
  /// register validation is called separately (i.e., in Csr HW construction).

  void _validate() {
    // at least 1 register
    if (registers.isEmpty) {
      throw CsrValidationException('Block $name has no registers.');
    }

    // no two registers with the same name
    // no two registers with the same address
    final issues = <String>[];
    for (var i = 0; i < registers.length; i++) {
      for (var j = i + 1; j < registers.length; j++) {
        if (registers[i].name == registers[j].name) {
          issues.add('Register ${registers[i].name} is duplicated.');
        }
        if (registers[i].addr == registers[j].addr) {
          issues.add('Register ${registers[i].name} has a duplicate address.');
        }
      }
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
    }
  }

  /// Method to determine the minimum number of address bits
  /// needed to address all registers in the block. This is
  /// based on the maximum register address offset.
  @override
  int minAddrBits() {
    var maxAddr = 0;
    for (final reg in registers) {
      if (reg.addr > maxAddr) {
        maxAddr = reg.addr;
      }
    }
    return maxAddr.bitLength;
  }

  /// Method to determine the maximum register size.
  /// This is important for interface data width validation.
  @override
  int maxRegWidth() {
    var maxWidth = 0;
    for (final reg in registers) {
      if (reg.width > maxWidth) {
        maxWidth = reg.width;
      }
    }
    return maxWidth;
  }

  /// Deep clone method.
  @override
  CsrBlockConfig clone() => CsrBlockConfig(
        name: name,
        baseAddr: baseAddr,
      )..registers.addAll(registers.map((e) => e.clone()));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrBlockConfig &&
        super == other &&
        other.baseAddr == baseAddr &&
        const ListEquality<CsrInstanceConfig>()
            .equals(other.registers, registers);
  }

  @override
  // TODO: implement hashCode
  int get hashCode =>
      super.hashCode ^
      baseAddr.hashCode ^
      const ListEquality<CsrInstanceConfig>().hash(registers);
}
