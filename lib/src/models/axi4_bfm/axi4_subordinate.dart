// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_subordinate.dart
// A subordinate AXI4 agent.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model for the subordinate side of an [Axi4ReadInterface] and [Axi4WriteInterface].
class Axi4SubordinateAgent extends Agent {
  /// The system interface.
  final Axi4SystemInterface sIntf;

  /// The read interface to drive.
  final Axi4ReadInterface rIntf;

  /// The write interface to drive.
  final Axi4WriteInterface wIntf;

  /// A place where the subordinate should save and retrieve data.
  ///
  /// The [Axi4SubordinateAgent] will reset [storage] whenever the `resetN` signal
  /// is dropped.
  final MemoryStorage storage;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(Axi4ReadRequestPacket request)? readResponseDelay;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(Axi4WriteRequestPacket request)? writeResponseDelay;

  /// A function that determines whether a response for a request should contain
  /// an error (`slvErr`).
  ///
  /// If none is provided, it will always respond with no error.
  final bool Function(Axi4RequestPacket request)? respondWithError;

  /// If true, then returned data on an error will be `x`.
  final bool invalidReadDataOnError;

  /// If true, then writes that respond with an error will not store into the
  /// [storage].
  final bool dropWriteDataOnError;

  // to handle response read responses
  final List<Axi4ReadRequestPacket> _dataReadResponseMetadataQueue = [];
  final List<List<LogicValue>> _dataReadResponseDataQueue = [];
  int _dataReadResponseIndex = 0;

  // to handle writes
  final List<Axi4WriteRequestPacket> _writeMetadataQueue = [];
  bool _writeReadyToOccur = false;

  /// Creates a new model [Axi4SubordinateAgent].
  ///
  /// If no [storage] is provided, it will use a default [SparseMemoryStorage].
  Axi4SubordinateAgent(
      {required this.sIntf,
      required this.rIntf,
      required this.wIntf,
      required Component parent,
      MemoryStorage? storage,
      this.readResponseDelay,
      this.writeResponseDelay,
      this.respondWithError,
      this.invalidReadDataOnError = true,
      this.dropWriteDataOnError = true,
      String name = 'axi4SubordinateAgent'})
      : assert(rIntf.addrWidth == wIntf.addrWidth,
            'Read and write interfaces should have same address width.'),
        assert(rIntf.dataWidth == wIntf.dataWidth,
            'Read and write interfaces should have same data width.'),
        storage = storage ??
            SparseMemoryStorage(
              addrWidth: rIntf.addrWidth,
              dataWidth: rIntf.dataWidth,
            ),
        super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    sIntf.resetN.negedge.listen((event) {
      storage.reset();
      _dataReadResponseDataQueue.clear();
      _dataReadResponseMetadataQueue.clear();
      _dataReadResponseIndex = 0;
      _writeMetadataQueue.clear();
      _writeReadyToOccur = false;
    });

    // wait for reset to complete
    await sIntf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      await sIntf.clk.nextNegedge;
      _driveReadys();
      _respondRead();
      _respondWrite();
      _receiveRead();
      _captureWriteData();
      _receiveWrite();
    }
  }

  /// Calculates a strobed version of data.
  static LogicValue _strobeData(
          LogicValue originalData, LogicValue newData, LogicValue strobe) =>
      [
        for (var i = 0; i < strobe.width; i++)
          (strobe[i].toBool() ? newData : originalData)
              .getRange(i * 8, i * 8 + 8)
      ].rswizzle();

  // assesses the input ready signals and drives them appropriately
  void _driveReadys() {
    // for now, assume we can always handle a new request
    rIntf.arReady.put(true);
    wIntf.awReady.put(true);
    wIntf.wReady.put(true);
  }

  /// Receives one packet (or returns if not selected).
  void _receiveRead() {
    // work to do if main is indicating a valid read that we are ready to handle
    if (rIntf.arValid.value.toBool() && rIntf.arReady.value.toBool()) {
      final packet = Axi4ReadRequestPacket(
          addr: rIntf.arAddr.value,
          prot: rIntf.arProt.value,
          id: rIntf.arId?.value,
          len: rIntf.arLen?.value,
          size: rIntf.arSize?.value,
          burst: rIntf.arBurst?.value,
          lock: rIntf.arLock?.value,
          cache: rIntf.arCache?.value,
          qos: rIntf.arQos?.value,
          region: rIntf.arRegion?.value,
          user: rIntf.arUser?.value);

      // NOTE: generic model does not handle the following read request fields:
      //  cache
      //  qos
      //  region
      //  user
      // These can be handled in a derived class of this model if need be.
      // Because for the most part they require implementation specific handling.

      // NOTE: generic model doesn't honor the prot field in read requests.
      // It will be added as a feature request in the future.

      // NOTE: generic model doesn't honor the lock field in read requests.
      // It will be added as a feature request in the future.

      // query storage to retrieve the data
      final data = <LogicValue>[];
      var addrToRead = rIntf.arAddr.value;
      final endCount = rIntf.arLen?.value.toInt() ?? 1;
      final dSize = (rIntf.arSize?.value.toInt() ?? 0) * 8;
      var increment = 0;
      if (rIntf.arBurst == null ||
          rIntf.arBurst?.value.toInt() == Axi4BurstField.wrap.value ||
          rIntf.arBurst?.value.toInt() == Axi4BurstField.incr.value) {
        increment = dSize ~/ 8;
      }

      for (var i = 0; i < endCount; i++) {
        var currData = storage.readData(addrToRead);
        if (dSize > 0) {
          if (currData.width < dSize) {
            currData = currData.zeroExtend(dSize);
          } else if (currData.width > dSize) {
            currData = currData.getRange(0, dSize);
          }
        }
        data.add(currData);
        addrToRead = addrToRead + increment;
      }

      _dataReadResponseMetadataQueue.add(packet);
      _dataReadResponseDataQueue.add(data);
    }
  }

  // respond to a read request
  void _respondRead() {
    // only respond if there is something to respond to
    // and the main side is indicating that it is ready to receive
    if (_dataReadResponseMetadataQueue.isNotEmpty &&
        _dataReadResponseDataQueue.isNotEmpty &&
        rIntf.rReady.value.toBool()) {
      final packet = _dataReadResponseMetadataQueue[0];
      final currData = _dataReadResponseDataQueue[0][_dataReadResponseIndex];
      final error = respondWithError != null && respondWithError!(packet);
      final last =
          _dataReadResponseIndex == _dataReadResponseDataQueue[0].length - 1;

      // TODO: how to deal with delays??
      // if (readResponseDelay != null) {
      //   final delayCycles = readResponseDelay!(packet);
      //   if (delayCycles > 0) {
      //     await sIntf.clk.waitCycles(delayCycles);
      //   }
      // }

      // for now, only support sending slvErr and okay as responses
      rIntf.rValid.put(true);
      rIntf.rId?.put(packet.id);
      rIntf.rData.put(currData);
      rIntf.rResp?.put(error
          ? LogicValue.ofInt(Axi4RespField.slvErr.value, rIntf.rResp!.width)
          : LogicValue.ofInt(Axi4RespField.okay.value, rIntf.rResp!.width));
      rIntf.rUser?.put(0); // don't support user field for now
      rIntf.rLast?.put(last);

      if (last) {
        // pop this read response off the queue
        _dataReadResponseIndex = 0;
        _dataReadResponseMetadataQueue.removeAt(0);
        _dataReadResponseDataQueue.removeAt(0);
      } else {
        // move to the next chunk of data
        _dataReadResponseIndex++;
      }
    }
  }

  // handle an incoming write request
  void _receiveWrite() {
    // work to do if main is indicating a valid write that we are ready to handle
    if (wIntf.awValid.value.toBool() && wIntf.awReady.value.toBool()) {
      final packet = Axi4WriteRequestPacket(
          addr: wIntf.awAddr.value,
          prot: wIntf.awProt.value,
          id: wIntf.awId?.value,
          len: wIntf.awLen?.value,
          size: wIntf.awSize?.value,
          burst: wIntf.awBurst?.value,
          lock: wIntf.awLock?.value,
          cache: wIntf.awCache?.value,
          qos: wIntf.awQos?.value,
          region: wIntf.awRegion?.value,
          user: wIntf.awUser?.value,
          data: [],
          strobe: []);

      // might need to capture the first data and strobe simultaneously
      // NOTE: we are dropping wUser on the floor for now...
      if (wIntf.wValid.value.toBool() && wIntf.wReady.value.toBool()) {
        packet.data.add(wIntf.wData.value);
        packet.strobe.add(wIntf.wStrb.value);
        if (wIntf.wLast.value.toBool()) {
          _writeReadyToOccur = true;
        }
      }

      // queue up the packet for further processing
      _writeMetadataQueue.add(packet);
    }
  }

  // method to capture incoming write data after the initial request
  // note that this method does not handle the first flit of write data
  // if it is transmitted simultaneously with the write request
  void _captureWriteData() {
    // NOTE: we are dropping wUser on the floor for now...
    if (_writeMetadataQueue.isNotEmpty &&
        wIntf.wValid.value.toBool() &&
        wIntf.wReady.value.toBool()) {
      final packet = _writeMetadataQueue[0];
      packet.data.add(wIntf.wData.value);
      packet.strobe.add(wIntf.wStrb.value);
      if (wIntf.wLast.value.toBool()) {
        _writeReadyToOccur = true;
      }
    }
  }

  void _respondWrite() {
    // only work to do if we have received all of the data for our write request
    if (_writeReadyToOccur) {
      // only respond if the main is ready
      if (wIntf.bReady.value.toBool()) {
        final packet = _writeMetadataQueue[0];
        final error = respondWithError != null && respondWithError!(packet);

        // for now, only support sending slvErr and okay as responses
        wIntf.bValid.put(true);
        wIntf.bId?.put(packet.id);
        wIntf.bResp?.put(error
            ? LogicValue.ofInt(Axi4RespField.slvErr.value, wIntf.bResp!.width)
            : LogicValue.ofInt(Axi4RespField.okay.value, wIntf.bResp!.width));
        wIntf.bUser?.put(0); // don't support user field for now

        // TODO: how to deal with delays??
        // if (readResponseDelay != null) {
        //   final delayCycles = readResponseDelay!(packet);
        //   if (delayCycles > 0) {
        //     await sIntf.clk.waitCycles(delayCycles);
        //   }
        // }

        // NOTE: generic model does not handle the following write request fields:
        //  cache
        //  qos
        //  region
        //  user
        // These can be handled in a derived class of this model if need be.
        // Because for the most part they require implementation specific handling.

        // NOTE: generic model doesn't honor the prot field in write requests.
        // It will be added as a feature request in the future.

        // NOTE: generic model doesn't honor the lock field in write requests.
        // It will be added as a feature request in the future.

        if (!error || !dropWriteDataOnError) {
          // write the data to the storage
          var addrToWrite = packet.addr;
          final dSize = (packet.size?.toInt() ?? 0) * 8;
          var increment = 0;
          if (packet.burst == null ||
              packet.burst!.toInt() == Axi4BurstField.wrap.value ||
              packet.burst!.toInt() == Axi4BurstField.incr.value) {
            increment = dSize ~/ 8;
          }

          for (var i = 0; i < packet.data.length; i++) {
            final strobedData = _strobeData(
                storage.readData(addrToWrite),
                packet.data[i],
                packet.strobe[i] ??
                    LogicValue.filled(packet.data[i].width, LogicValue.one));
            storage.writeData(addrToWrite, strobedData.getRange(0, dSize));
            addrToWrite = addrToWrite + increment;
          }
        }

        // pop this write response off the queue
        _writeMetadataQueue.removeAt(0);
        _writeReadyToOccur = false;
      }
    }
  }
}
