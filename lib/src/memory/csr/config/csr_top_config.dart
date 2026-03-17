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
  /// Default number of addresses in each block's address space.
  ///
  /// Individual blocks may override this value via
  /// [CsrBlockConfig.blockSize] to support heterogeneous block sizes.
  final int blockSize;

  /// Blocks in this module.
  final List<CsrBlockConfig> blocks;

  /// Construct a new top level configuration.
  CsrTopConfig({
    required super.name,
    required this.blockSize,
    required List<CsrBlockConfig> blocks,
  }) : blocks = List.unmodifiable(blocks) {
    _validate();
  }

  /// Returns the effective block size for [block].
  ///
  /// If the block has its own [CsrBlockConfig.blockSize] set, that
  /// value is returned; otherwise the top-level [blockSize] default
  /// is used.
  int blockSizeForBlock(CsrBlockConfig block) => block.blockSize ?? blockSize;

  /// Returns the number of address offset bits needed to index within
  /// [block], derived from the effective block size.
  int blockOffsetWidthForBlock(CsrBlockConfig block) =>
      (blockSizeForBlock(block) - 1).bitLength;

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
    // also check that each block's effective size is large enough
    final issues = <String>[];
    for (var i = 0; i < blocks.length; i++) {
      final effectiveSizeI = blockSizeForBlock(blocks[i]);

      // verify that the effective block size can address all registers
      // in this block (only needs to be checked here for blocks that use the
      // top-level default; blocks with their own override are validated in
      // CsrBlockConfig directly)
      if (blocks[i].blockSize == null &&
          effectiveSizeI < blocks[i].minBlockSize()) {
        issues.add('Block size $effectiveSizeI is too small to address all '
            'registers in block ${blocks[i].name}. The minimum block size '
            'for this block is ${blocks[i].minBlockSize()}.');
      }

      for (var j = i + 1; j < blocks.length; j++) {
        if (blocks[i].name == blocks[j].name) {
          issues.add('Register block ${blocks[i].name} is duplicated.');
        }

        if (blocks[i].baseAddr == blocks[j].baseAddr) {
          issues.add(
              'Register block ${blocks[i].name} has a duplicate base address.');
        } else {
          // the block whose base address comes first in the address space
          // must not bleed into the block that comes second, based on
          // the first block's effective size
          final effectiveSizeJ = blockSizeForBlock(blocks[j]);
          final int separation;
          final int firstBlockSize;
          if (blocks[i].baseAddr < blocks[j].baseAddr) {
            separation = blocks[j].baseAddr - blocks[i].baseAddr;
            firstBlockSize = effectiveSizeI;
          } else {
            separation = blocks[i].baseAddr - blocks[j].baseAddr;
            firstBlockSize = effectiveSizeJ;
          }
          if (separation < firstBlockSize) {
            issues.add(
                'Register blocks ${blocks[i].name} and ${blocks[j].name} are '
                'too close together per their block sizes.');
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
  /// validate the block size relative to the base addresses
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
    int? blockSize,
    List<CsrBlockConfig>? blocks,
  }) =>
      CsrTopConfig(
        name: name ?? this.name,
        blockSize: blockSize ?? this.blockSize,
        blocks: blocks ?? this.blocks,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CsrTopConfig &&
        super == other &&
        blockSize == other.blockSize &&
        blocks.length == other.blocks.length &&
        const ListEquality<CsrBlockConfig>().equals(blocks, other.blocks);
  }

  @override
  int get hashCode =>
      super.hashCode ^
      blockSize.hashCode ^
      const ListEquality<CsrBlockConfig>().hash(blocks);
}
