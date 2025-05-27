import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/memory/csr/config/csr_container_config.dart';

/// Definition for a top level module containing CSR blocks.
///
/// This class is also where the choice to instantiate
/// any conditional blocks should take place.
@immutable
class CsrTopConfig extends CsrContainerConfig {
  /// Address bits dedicated to the individual registers.
  ///
  /// This is effectively the number of LSBs in an incoming address
  /// to ignore when assessing the address of a block.
  final int blockOffsetWidth;

  /// Blocks in this module.
  final List<CsrBlockConfig> blocks;

  /// Construct a new top level configuration.
  CsrTopConfig({
    required super.name,
    required this.blockOffsetWidth,
    required List<CsrBlockConfig> blocks,
  }) : blocks = List.unmodifiable(blocks) {
    _validate();
  }

  /// Accessor to the config of a particular register block
  /// within the module by name [name].
  CsrBlockConfig getBlockByName(String name) =>
      blocks.firstWhere((element) => element.name == name);

  /// Accessor to the config of a particular register block
  /// within the module by relative address [addr].
  CsrBlockConfig getBlockByAddr(int addr) =>
      blocks.firstWhere((element) => element.baseAddr == addr);

  /// Method to validate the configuration of register top module.
  ///
  /// Must check that its blocks are mutually valid.
  /// Note that this method does not call the validate method of
  /// the individual blocks. It is assumed that
  /// block validation is called separately (i.e., in CsrBlock HW construction).
  void _validate() {
    // at least 1 block
    if (blocks.isEmpty) {
      throw CsrValidationException(
          'Csr top module $name has no register blocks.');
    }

    // no two blocks with the same name
    // no two blocks with the same base address
    // no two blocks with base addresses that are too close together
    // also compute the max min address bits across the blocks
    final issues = <String>[];
    var maxMinAddrBits = 0;
    for (var i = 0; i < blocks.length; i++) {
      final currMaxMin = blocks[i].minAddrBits();
      if (currMaxMin > maxMinAddrBits) {
        maxMinAddrBits = currMaxMin;
      }

      for (var j = i + 1; j < blocks.length; j++) {
        if (blocks[i].name == blocks[j].name) {
          issues.add('Register block ${blocks[i].name} is duplicated.');
        }

        if (blocks[i].baseAddr == blocks[j].baseAddr) {
          issues.add(
              'Register block ${blocks[i].name} has a duplicate base address.');
        } else if ((blocks[i].baseAddr - blocks[j].baseAddr).abs().bitLength <
            blockOffsetWidth) {
          issues.add(
              'Register blocks ${blocks[i].name} and ${blocks[j].name} are '
              'too close together per the block offset width.');
        }
      }
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
    }

    // is the block offset width big enough to address
    // every register in every block
    if (blockOffsetWidth < maxMinAddrBits) {
      throw CsrValidationException(
          'Block offset width is too small to address all register in all '
          'blocks in the module. The minimum offset width is $maxMinAddrBits.');
    }
  }

  /// Method to determine the minimum number of address bits
  /// needed to address all registers across all blocks. This is
  /// based on the maximum block base address. Note that we independently
  /// validate the block offset width relative to the base addresses
  /// so we can trust the simpler analysis here.
  @override
  int minAddrBits() {
    var maxAddr = 0;
    for (final block in blocks) {
      if (block.baseAddr > maxAddr) {
        maxAddr = block.baseAddr;
      }
    }
    return maxAddr.bitLength;
  }

  /// Method to determine the maximum register size.
  /// This is important for interface data width validation.
  @override
  int maxRegWidth() {
    var maxWidth = 0;
    for (final block in blocks) {
      if (block.maxRegWidth() > maxWidth) {
        maxWidth = block.maxRegWidth();
      }
    }
    return maxWidth;
  }

  /// Deep clone method.
  @override
  CsrTopConfig clone({
    String? name,
    int? blockOffsetWidth,
    List<CsrBlockConfig>? blocks,
  }) =>
      CsrTopConfig(
        name: name ?? this.name,
        blockOffsetWidth: blockOffsetWidth ?? this.blockOffsetWidth,
        blocks: blocks ?? this.blocks,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrTopConfig &&
        super == other &&
        blockOffsetWidth == other.blockOffsetWidth &&
        blocks.length == other.blocks.length &&
        const ListEquality<CsrBlockConfig>().equals(blocks, other.blocks);
  }

  @override
  int get hashCode =>
      super.hashCode ^
      blockOffsetWidth.hashCode ^
      const ListEquality<CsrBlockConfig>().hash(blocks);
}
