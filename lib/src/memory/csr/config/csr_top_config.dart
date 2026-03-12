// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_top_config.dart
// Configuration for a top-level control and status register (CSR) module.
//
// 2024 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

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
  /// Default number of address bits dedicated to registers within each block.
  ///
  /// This is effectively the number of LSBs in an incoming address
  /// to ignore when assessing the address of a block. Individual blocks may
  /// override this value via [CsrBlockConfig.blockOffsetWidth] to support
  /// heterogeneous block sizes.
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

  /// Returns the effective block offset width for [block].
  ///
  /// If the block has its own [CsrBlockConfig.blockOffsetWidth] set, that
  /// value is returned; otherwise the top-level [blockOffsetWidth] default
  /// is used.
  int blockOffsetWidthForBlock(CsrBlockConfig block) =>
      block.blockOffsetWidth ?? blockOffsetWidth;

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
  /// block validation is called separately (i.e., in [CsrBlock] HW
  /// construction).
  void _validate() {
    // at least 1 block
    if (blocks.isEmpty) {
      throw CsrValidationException(
          'Csr top module $name has no register blocks.');
    }

    // no two blocks with the same name
    // no two blocks with the same base address
    // no two blocks with base addresses that are too close together
    // also check that each block's effective offset width is large enough
    final issues = <String>[];
    for (var i = 0; i < blocks.length; i++) {
      final effectiveWidthI = blockOffsetWidthForBlock(blocks[i]);

      // verify that the effective offset width can address all registers
      // in this block (only needs to be checked here for blocks that use the
      // top-level default; blocks with their own override are validated in
      // CsrBlockConfig directly)
      if (blocks[i].blockOffsetWidth == null &&
          effectiveWidthI < blocks[i].minAddrBits()) {
        issues.add(
            'Block offset width $effectiveWidthI is too small to address all '
            'registers in block ${blocks[i].name}. The minimum offset width '
            'for this block is ${blocks[i].minAddrBits()}.');
      }

      for (var j = i + 1; j < blocks.length; j++) {
        if (blocks[i].name == blocks[j].name) {
          issues.add('Register block ${blocks[i].name} is duplicated.');
        }

        if (blocks[i].baseAddr == blocks[j].baseAddr) {
          issues.add(
              'Register block ${blocks[i].name} has a duplicate base address.');
        } else {
          // two blocks must be spaced far enough apart that neither block's
          // address range overlaps the other; use the larger of the two
          // effective offset widths as the required minimum separation
          final effectiveWidthJ = blockOffsetWidthForBlock(blocks[j]);
          final minSeparation = effectiveWidthI > effectiveWidthJ
              ? effectiveWidthI
              : effectiveWidthJ;
          if ((blocks[i].baseAddr - blocks[j].baseAddr).abs().bitLength <
              minSeparation) {
            issues.add(
                'Register blocks ${blocks[i].name} and ${blocks[j].name} are '
                'too close together per their block offset widths.');
          }
        }
      }
    }
    if (issues.isNotEmpty) {
      throw CsrValidationException(issues.join('\n'));
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
