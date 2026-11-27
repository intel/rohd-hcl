// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_inference_tensor.dart
// Configurators for typed tensor layout, traversal, and movement.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a static typed tensor transpose.
class TensorTileTransposeConfigurator extends Configurator {
  /// Tile dimensions, element format, and array layout.
  final tensorKnob = InferenceTensorKnob();
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'layout';
  @override
  String get name => 'Tensor Tile Transpose';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Tensor': tensorKnob};
  @override
  Module createModule() => TensorTileTranspose(tensorKnob.tile());
}

/// Configures square-matrix transpose with one stepped typed row per cycle.
class SystolicMatrixTransposeConfigurator extends Configurator {
  /// Matrix row and column count.
  final dimensionKnob = PositiveIntConfigKnob(value: 2);

  /// Element width and fractional precision.
  final elementKnob = InferenceFixedPointFormatKnob();

  /// Whether row elements are unpacked.
  final unpackedKnob = ToggleConfigKnob(value: false);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'layout';
  @override
  String get name => 'Systolic Matrix Transpose';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Dimension': dimensionKnob,
        'Element Format': elementKnob,
        'Unpacked Row': unpackedKnob,
      };
  @override
  Module createModule() => SystolicMatrixTranspose(
        clk: Logic(),
        reset: Logic(),
        step: Logic(),
        dataIn: elementKnob.array(dimensionKnob.value,
            unpacked: unpackedKnob.value),
      );
}

/// Configures framed stream-to-tile conversion with an optional protocol shell.
class TensorTileTilerConfigurator extends TensorTileTransposeConfigurator {
  /// Scheduling boundary.
  final boundaryKnob = ChoiceConfigKnob(InferenceConfiguratorBoundary.values,
      value: InferenceConfiguratorBoundary.actions);
  @override
  String get name => 'Tensor Tile Tiler';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      {...super.knobs, 'Boundary': boundaryKnob};

  /// Creates a streamed element schema compatible with the configured tile.
  InferenceTensorStreamElement<Logic> elementSchema() =>
      InferenceTensorStreamElement(
        tensorKnob.formatKnob.element(signed: tensorKnob.signedKnob.value),
        rowCount: tensorKnob.rowsKnob.value,
        columnCount: tensorKnob.columnsKnob.value,
      );
  @override
  Module createModule() {
    final tile = tensorKnob.tile();
    final element = Frame(elementSchema());
    return boundaryKnob.value == InferenceConfiguratorBoundary.readyValid
        ? ReadyValidTensorTileTiler(
            clk: Logic(),
            reset: Logic(),
            upstream: ReadyValidInterface(element),
            downstream: ReadyValidInterface(tile))
        : TensorTileTiler(
            clk: Logic(),
            reset: Logic(),
            element: element,
            write: Logic(),
            tileSchema: tile);
  }
}

/// Configures typed tile-to-framed-stream conversion.
class TensorTileUntilerConfigurator extends TensorTileTilerConfigurator {
  @override
  String get name => 'Tensor Tile Untiler';
  @override
  Module createModule() {
    final tile = tensorKnob.tile();
    final element = elementSchema();
    return boundaryKnob.value == InferenceConfiguratorBoundary.readyValid
        ? ReadyValidTensorTileUntiler(
            clk: Logic(),
            reset: Logic(),
            upstream: ReadyValidInterface(tile),
            downstream: ReadyValidInterface(Frame(element)))
        : TensorTileUntiler(
            clk: Logic(),
            reset: Logic(),
            inputTile: tile,
            elementSchema: element,
            load: Logic(),
            advance: Logic());
  }
}

/// Configures explicit-action selective tensor fan-out.
class TensorTileMulticastConfigurator extends TensorTileTransposeConfigurator {
  /// Number of independent destinations.
  final destinationsKnob = PositiveIntConfigKnob(value: 2);
  @override
  String get subcategory => 'distribution';
  @override
  String get name => 'Tensor Tile Multicast';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      {...super.knobs, 'Destinations': destinationsKnob};
  @override
  Module createModule() => TensorTileMulticastCore(
        clk: Logic(),
        reset: Logic(),
        tile: tensorKnob.tile(),
        load: Logic(),
        selection: Logic(width: destinationsKnob.value),
        advance: Logic(width: destinationsKnob.value),
      );
}

/// Configures MHA, GQA, or MQA tile distribution.
class GroupedQueryAttentionTileDistributorConfigurator
    extends TensorTileTransposeConfigurator {
  /// Query-head count.
  final queryHeadsKnob = PositiveIntConfigKnob(value: 4);

  /// Key/value-head count, which must divide the query-head count.
  final keyValueHeadsKnob = PositiveIntConfigKnob(value: 2);
  @override
  String get subcategory => 'distribution';
  @override
  String get name => 'Grouped-Query Attention Tile Distributor';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ...super.knobs,
        'Query Heads': queryHeadsKnob,
        'Key/Value Heads': keyValueHeadsKnob,
      };
  @override
  Module createModule() {
    if (queryHeadsKnob.value % keyValueHeadsKnob.value != 0) {
      throw ArgumentError('Key/value heads must divide the query-head count.');
    }
    return GroupedQueryAttentionTileDistributor(
      clk: Logic(),
      reset: Logic(),
      upstream: ReadyValidInterface(tensorKnob.tile()),
      downstreams: [
        for (var i = 0; i < queryHeadsKnob.value; i++)
          ReadyValidInterface(tensorKnob.tile()),
      ],
      keyValueHead: Logic(width: widthFor(keyValueHeadsKnob.value)),
      mapping: GroupedQueryHeadMapping(
          queryHeadCount: queryHeadsKnob.value,
          keyValueHeadCount: keyValueHeadsKnob.value),
    );
  }
}

/// Configures the existing two-entry typed tensor queue composition.
class TensorPingPongBufferConfigurator extends TensorTileTransposeConfigurator {
  @override
  String get subcategory => 'storage';
  @override
  String get name => 'Tensor Ping-Pong Buffer';
  @override
  Module createModule() => tensorPingPongBuffer(
        clk: Logic(),
        reset: Logic(),
        upstream: ReadyValidInterface(tensorKnob.tile()),
        downstream: ReadyValidInterface(tensorKnob.tile()),
      );
}

/// Configures a combinational multidimensional address calculation.
class TensorStridedAddressConfigurator extends Configurator {
  /// Number of indices and strides.
  final rankKnob = PositiveIntConfigKnob(value: 3);

  /// Index width in each dimension.
  final indexWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Stride width in each dimension.
  final strideWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Base-address width.
  final baseWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Result address width.
  final addressWidthKnob = PositiveIntConfigKnob(value: 16);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'movement';
  @override
  String get name => 'Tensor Strided Address';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Rank': rankKnob,
        'Index Width': indexWidthKnob,
        'Stride Width': strideWidthKnob,
        'Base Address Width': baseWidthKnob,
        'Address Width': addressWidthKnob,
      };
  @override
  Module createModule() => TensorStridedAddress(
        baseAddress: Logic(width: baseWidthKnob.value),
        indices: [
          for (var i = 0; i < rankKnob.value; i++)
            Logic(width: indexWidthKnob.value)
        ],
        strides: [
          for (var i = 0; i < rankKnob.value; i++)
            Logic(width: strideWidthKnob.value)
        ],
        addressWidth: addressWidthKnob.value,
      );
}

/// Configures nested tensor traversal with an optional transport shell.
class TensorStridedAddressGeneratorConfigurator extends Configurator {
  /// Scheduling boundary.
  final boundaryKnob = ChoiceConfigKnob(InferenceConfiguratorBoundary.values,
      value: InferenceConfiguratorBoundary.actions);

  /// Address width.
  final addressWidthKnob = PositiveIntConfigKnob(value: 16);

  /// M extent and index width.
  final mWidthKnob = PositiveIntConfigKnob(value: 4);

  /// N extent and index width.
  final nWidthKnob = PositiveIntConfigKnob(value: 4);

  /// K extent and index width.
  final kWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Command identifier width.
  final commandIdWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Statistics counter width.
  final counterWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Whether to expose counter clearing.
  final clearCountersKnob = ToggleConfigKnob(value: false);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'movement';
  @override
  String get name => 'Tensor Strided Address Generator';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Boundary': boundaryKnob,
        'Address Width': addressWidthKnob,
        'M Width': mWidthKnob,
        'N Width': nWidthKnob,
        'K Width': kWidthKnob,
        'Command ID Width': commandIdWidthKnob,
        'Counter Width': counterWidthKnob,
        'Clear Counters': clearCountersKnob,
      };
  @override
  Module createModule() {
    final command = TensorAddressCommand(
        addressWidth: addressWidthKnob.value,
        mWidth: mWidthKnob.value,
        nWidth: nWidthKnob.value,
        kWidth: kWidthKnob.value,
        commandIdWidth: commandIdWidthKnob.value);
    final result = TensorAddressBeat(
        addressWidth: addressWidthKnob.value,
        mWidth: mWidthKnob.value,
        nWidth: nWidthKnob.value,
        kWidth: kWidthKnob.value,
        commandIdWidth: commandIdWidthKnob.value);
    return boundaryKnob.value == InferenceConfiguratorBoundary.readyValid
        ? TensorStridedAddressGenerator(
            clk: Logic(),
            reset: Logic(),
            upstream: ReadyValidInterface(command),
            downstream: ReadyValidInterface(result),
            counterWidth: counterWidthKnob.value,
            clearCounters: clearCountersKnob.value ? Logic() : null)
        : TensorStridedAddressGeneratorCore(
            clk: Logic(),
            reset: Logic(),
            command: command,
            resultSchema: result,
            load: Logic(),
            advance: Logic(),
            counterWidth: counterWidthKnob.value,
            clearCounters: clearCountersKnob.value ? Logic() : null);
  }
}

/// Configures runtime nested M/N/K coordinate traversal.
class TensorTileIteratorConfigurator extends Configurator {
  /// M extent and index width.
  final mWidthKnob = PositiveIntConfigKnob(value: 4);

  /// N extent and index width.
  final nWidthKnob = PositiveIntConfigKnob(value: 4);

  /// K extent and index width.
  final kWidthKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'movement';
  @override
  String get name => 'Tensor Tile Iterator';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      {'M Width': mWidthKnob, 'N Width': nWidthKnob, 'K Width': kWidthKnob};
  @override
  Module createModule() => TensorTileIterator(
        clk: Logic(),
        reset: Logic(),
        start: Logic(),
        advance: Logic(),
        mTiles: Logic(width: mWidthKnob.value),
        nTiles: Logic(width: nWidthKnob.value),
        kTiles: Logic(width: kWidthKnob.value),
      );
}

/// Configures runtime pooling geometry traversal, with optional split inputs.
class PoolingWindowSequencerConfigurator extends Configurator {
  /// Width shared by runtime geometry inputs; supported range is 1 through 16.
  final geometryWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Whether to include all four runtime split inputs.
  final splitsKnob = ToggleConfigKnob(value: false);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'movement';
  @override
  String get name => 'Pooling Window Sequencer';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      {'Geometry Width': geometryWidthKnob, 'Runtime Splits': splitsKnob};
  @override
  Module createModule() {
    Logic geometry() => Logic(width: geometryWidthKnob.value);
    return PoolingWindowSequencer(
      clk: Logic(),
      reset: Logic(),
      restart: Logic(),
      advanceTerm: Logic(),
      advanceOutput: Logic(),
      inputWidth: geometry(),
      inputHeight: geometry(),
      outputWidth: geometry(),
      outputHeight: geometry(),
      groups: geometry(),
      kernelWidth: geometry(),
      kernelHeight: geometry(),
      strideX: geometry(),
      strideY: geometry(),
      padLeft: geometry(),
      padTop: geometry(),
      splitCount: splitsKnob.value ? geometry() : null,
      outputWidthFirst: splitsKnob.value ? geometry() : null,
      outputWidthMiddle: splitsKnob.value ? geometry() : null,
      outputWidthLast: splitsKnob.value ? geometry() : null,
    );
  }
}

/// Configures typed tensor DMA between independent memory transaction ports.
class TensorDmaConfigurator extends TensorStridedAddressGeneratorConfigurator {
  /// Destination address width.
  final destinationAddressWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Elements per transferred word.
  final lanesKnob = PositiveIntConfigKnob(value: 2);

  /// Transferred element format.
  final elementKnob = InferenceFixedPointFormatKnob();

  /// Whether transferred words have unpacked elements.
  final unpackedKnob = ToggleConfigKnob(value: false);

  /// Source response tag width.
  final tagWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Optional source bounds in words.
  final sourceDepthKnob = IntOptionalConfigKnob(value: null);

  /// Optional destination bounds in words.
  final destinationDepthKnob = IntOptionalConfigKnob(value: null);
  @override
  String get name => 'Tensor DMA';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ...(super.knobs..remove('Boundary')),
        'Destination Address Width': destinationAddressWidthKnob,
        'Word Lanes': lanesKnob,
        'Element Format': elementKnob,
        'Unpacked Word': unpackedKnob,
        'Tag Width': tagWidthKnob,
        'Source Depth': sourceDepthKnob,
        'Destination Depth': destinationDepthKnob,
      };
  @override
  Module createModule() {
    final word =
        elementKnob.array(lanesKnob.value, unpacked: unpackedKnob.value);
    return TensorDmaEngine(
      clk: Logic(),
      reset: Logic(),
      command: ReadyValidInterface(TensorDmaCommand(
          sourceAddressWidth: addressWidthKnob.value,
          destinationAddressWidth: destinationAddressWidthKnob.value,
          mWidth: mWidthKnob.value,
          nWidth: nWidthKnob.value,
          kWidth: kWidthKnob.value,
          commandIdWidth: commandIdWidthKnob.value)),
      sourceReadRequest: ReadyValidInterface(TensorScratchpadReadRequest(
          addressWidth: addressWidthKnob.value, tagWidth: tagWidthKnob.value)),
      sourceReadResponse: ReadyValidInterface(TensorScratchpadReadResponse(
          data: word, tagWidth: tagWidthKnob.value)),
      destinationWriteRequest: ReadyValidInterface(TensorScratchpadWriteRequest(
          data: word, addressWidth: destinationAddressWidthKnob.value)),
      completion: ReadyValidInterface(TensorDmaCompletion(
          commandIdWidth: commandIdWidthKnob.value,
          countWidth: tensorDmaCountWidth(
              mWidth: mWidthKnob.value,
              nWidth: nWidthKnob.value,
              kWidth: kWidthKnob.value))),
      sourceDepth: sourceDepthKnob.value,
      destinationDepth: destinationDepthKnob.value,
      counterWidth: counterWidthKnob.value,
      clearCounters: clearCountersKnob.value ? Logic() : null,
    );
  }
}
