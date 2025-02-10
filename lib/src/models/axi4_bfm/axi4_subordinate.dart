// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_subordinate.dart
// A subordinate AXI4 agent.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A repesentation of an address region for the
/// AXI Subordinate. Regions can have access modes
/// and can be leveraged for wrapping bursts.
class AxiAddressRange {
  /// Starting address of the range.
  final LogicValue start;

  /// Ending address of the range (exclusive).
  final LogicValue end;

  /// Secure region.
  final bool isSecure;

  /// Only accessible in privileged mode.
  final bool isPrivileged;

  /// Constructor.
  AxiAddressRange(
      {required this.start,
      required this.end,
      this.isSecure = false,
      this.isPrivileged = false});
}

/// A model for the subordinate side of
/// an [Axi4ReadInterface] and [Axi4WriteInterface].
class Axi4SubordinateAgent extends Agent {
  /// The system interface.
  final Axi4SystemInterface sIntf;

  /// Channels that the subordinate manages.
  final List<Axi4Channel> channels;

  /// A place where the subordinate should save and retrieve data.
  ///
  /// The [Axi4SubordinateAgent] will reset [storage] whenever
  /// the `resetN` signal is dropped.
  late final MemoryStorage storage;

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

  /// Address range configuration. Controls access to addresses and helps
  /// with the wrap mode for bursts.
  /// TODO: ensure non-overlapping??
  List<AxiAddressRange> ranges = [];

  // to handle response read responses
  final List<List<Axi4ReadRequestPacket>> _dataReadResponseMetadataQueue = [];
  final List<List<List<LogicValue>>> _dataReadResponseDataQueue = [];
  final List<int> _dataReadResponseIndex = [];

  // to handle writes
  final List<List<Axi4WriteRequestPacket>> _writeMetadataQueue = [];
  final List<bool> _writeReadyToOccur = [];

  // capture mapping of channel ID to TB object index
  final Map<int, int> _readAddrToChannel = {};
  final Map<int, int> _writeAddrToChannel = {};

  /// Creates a new model [Axi4SubordinateAgent].
  ///
  /// If no [storage] is provided, it will use a default [SparseMemoryStorage].
  Axi4SubordinateAgent(
      {required this.sIntf,
      required this.channels,
      required Component parent,
      MemoryStorage? storage,
      this.readResponseDelay,
      this.writeResponseDelay,
      this.respondWithError,
      this.invalidReadDataOnError = true,
      this.dropWriteDataOnError = true,
      this.ranges = const [],
      String name = 'axi4SubordinateAgent'})
      : super(name, parent) {
    var maxAddrWidth = 0;
    var maxDataWidth = 0;
    for (var i = 0; i < channels.length; i++) {
      if (channels[i].hasRead) {
        maxAddrWidth = max(maxAddrWidth, channels[i].rIntf!.addrWidth);
        maxDataWidth = max(maxDataWidth, channels[i].rIntf!.dataWidth);
      }
      if (channels[i].hasWrite) {
        maxAddrWidth = max(maxAddrWidth, channels[i].wIntf!.addrWidth);
        maxDataWidth = max(maxDataWidth, channels[i].wIntf!.dataWidth);
      }
    }

    this.storage = storage ??
        SparseMemoryStorage(
          addrWidth: maxAddrWidth,
          dataWidth: maxDataWidth,
        );
    for (var i = 0; i < channels.length; i++) {
      if (channels[i].hasRead) {
        _dataReadResponseMetadataQueue.add([]);
        _dataReadResponseDataQueue.add([]);
        _dataReadResponseIndex.add(0);
        _readAddrToChannel[i] = _dataReadResponseMetadataQueue.length - 1;
      }
      if (channels[i].hasWrite) {
        _writeMetadataQueue.add([]);
        _writeReadyToOccur.add(false);
        _writeAddrToChannel[i] = _writeMetadataQueue.length - 1;
      }
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    sIntf.resetN.negedge.listen((event) {
      storage.reset();
      for (var i = 0; i < channels.length; i++) {
        if (channels[i].hasRead) {
          _dataReadResponseMetadataQueue[_readAddrToChannel[i]!].clear();
          _dataReadResponseDataQueue[_readAddrToChannel[i]!].clear();
          _dataReadResponseIndex[_readAddrToChannel[i]!] = 0;
        }
        if (channels[i].hasWrite) {
          _writeMetadataQueue[_writeAddrToChannel[i]!].clear();
          _writeReadyToOccur[_writeAddrToChannel[i]!] = false;
        }
      }
    });

    // wait for reset to complete
    await sIntf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      await sIntf.clk.nextNegedge;
      for (var i = 0; i < channels.length; i++) {
        if (channels[i].hasRead) {
          _driveReadReadys(index: i);
          _respondRead(index: i);
          _receiveRead(index: i);
        }
        if (channels[i].hasWrite) {
          _driveWriteReadys(index: i);
          _respondWrite(index: i);
          _captureWriteData(index: i);
          _receiveWrite(index: i);
        }
      }
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

  // find the index of the region that the provided address falls in
  // if none, return -1
  int _checkRegion(LogicValue addr) {
    for (var j = 0; j < ranges.length; j++) {
      if ((addr >= ranges[j].start).toBool() &&
          (addr < ranges[j].end).toBool()) {
        return j;
      }
    }
    return -1;
  }

  // assesses the input ready signals and drives them appropriately
  void _driveReadReadys({int index = 0}) {
    // for now, assume we can always handle a new request
    channels[index].rIntf!.arReady.put(true);
  }

  // assesses the input ready signals and drives them appropriately
  void _driveWriteReadys({int index = 0}) {
    // for now, assume we can always handle a new request
    channels[index].wIntf!.awReady.put(true);
    channels[index].wIntf!.wReady.put(true);
  }

  /// Receives one packet (or returns if not selected).
  void _receiveRead({int index = 0}) {
    final rIntf = channels[index].rIntf!;
    final mapIdx = _readAddrToChannel[index]!;

    // work to do if main is indicating a valid read that we are ready to handle
    if (rIntf.arValid.value.toBool() && rIntf.arReady.value.toBool()) {
      logger.info('Received read request on channel $index.');

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

      // generic model does not handle the following read request fields:
      //  cache
      //  qos
      //  region
      //  user
      // These can be handled in a derived class of this model if need be.
      // Because they require implementation specific handling.

      // NOTE: generic model doesn't honor the prot field in read requests.
      // It will be added as a feature request in the future.

      // NOTE: generic model doesn't honor the lock field in read requests.
      // It will be added as a feature request in the future.

      // query storage to retrieve the data
      final data = <LogicValue>[];
      var addrToRead = rIntf.arAddr.value;
      final endCount = (rIntf.arLen?.value.toInt() ?? 0) + 1;
      final dSize = (rIntf.arSize?.value.toInt() ?? 0) * 8;
      var increment = 0;
      if (rIntf.arBurst == null ||
          rIntf.arBurst?.value.toInt() == Axi4BurstField.wrap.value ||
          rIntf.arBurst?.value.toInt() == Axi4BurstField.incr.value) {
        increment = dSize ~/ 8;
      }

      // determine if the address falls in a region
      final region = _checkRegion(addrToRead);
      final inRegion = region >= 0;

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
        if (inRegion &&
            (addrToRead + increment >= ranges[region].end).toBool()) {
          // the original access fell in a region but the next access in
          // the burst overflows the region
          if (rIntf.arBurst?.value.toInt() == Axi4BurstField.wrap.value) {
            // indication that we should wrap around back to the region start
            addrToRead = ranges[region].start;
          } else {
            // OK to overflow
            addrToRead = addrToRead + increment;
          }
        } else {
          // no region or overflow
          addrToRead = addrToRead + increment;
        }
      }

      _dataReadResponseMetadataQueue[mapIdx].add(packet);
      _dataReadResponseDataQueue[mapIdx].add(data);
    }
  }

  // respond to a read request
  void _respondRead({int index = 0}) {
    final rIntf = channels[index].rIntf!;
    final mapIdx = _readAddrToChannel[index]!;

    // only respond if there is something to respond to
    // and the main side is indicating that it is ready to receive
    if (_dataReadResponseMetadataQueue[mapIdx].isNotEmpty &&
        _dataReadResponseDataQueue[mapIdx].isNotEmpty &&
        rIntf.rReady.value.toBool()) {
      final packet = _dataReadResponseMetadataQueue[mapIdx][0];
      final currData =
          _dataReadResponseDataQueue[mapIdx][0][_dataReadResponseIndex[mapIdx]];
      final error = respondWithError != null && respondWithError!(packet);
      final last = _dataReadResponseIndex[mapIdx] ==
          _dataReadResponseDataQueue[mapIdx][0].length - 1;

      // check the request's region for legality
      final region = _checkRegion(packet.addr);
      final inRegion = region >= 0;

      final accessError = inRegion &&
          ((ranges[region].isSecure &&
                  ((packet.prot.toInt() & Axi4ProtField.secure.value) == 0)) ||
              (ranges[region].isPrivileged &&
                  ((packet.prot.toInt() & Axi4ProtField.privileged.value) ==
                      0)));

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
      rIntf.rResp?.put(error | accessError
          ? LogicValue.ofInt(Axi4RespField.slvErr.value, rIntf.rResp!.width)
          : LogicValue.ofInt(Axi4RespField.okay.value, rIntf.rResp!.width));
      rIntf.rUser?.put(0); // don't support user field for now
      rIntf.rLast?.put(last);

      if (last || accessError) {
        // pop this read response off the queue
        _dataReadResponseIndex[mapIdx] = 0;
        _dataReadResponseMetadataQueue[mapIdx].removeAt(0);
        _dataReadResponseDataQueue[mapIdx].removeAt(0);

        logger.info('Finished sending read response for channel $index.');
      } else {
        // move to the next chunk of data
        _dataReadResponseIndex[mapIdx]++;
        logger.info('Still sending the read response for channel $index.');
      }
    } else {
      rIntf.rValid.put(false);
    }
  }

  // handle an incoming write request
  void _receiveWrite({int index = 0}) {
    final wIntf = channels[index].wIntf!;
    final mapIdx = _writeAddrToChannel[index]!;

    // work to do if main is indicating a valid + ready write
    if (wIntf.awValid.value.toBool() && wIntf.awReady.value.toBool()) {
      logger.info('Received write request on channel $index.');
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
          _writeReadyToOccur[mapIdx] = true;
        }
      }

      // queue up the packet for further processing
      _writeMetadataQueue[mapIdx].add(packet);
    }
  }

  // method to capture incoming write data after the initial request
  // note that this method does not handle the first flit of write data
  // if it is transmitted simultaneously with the write request
  void _captureWriteData({int index = 0}) {
    final wIntf = channels[index].wIntf!;
    final mapIdx = _writeAddrToChannel[index]!;

    // NOTE: we are dropping wUser on the floor for now...
    if (_writeMetadataQueue[mapIdx].isNotEmpty &&
        wIntf.wValid.value.toBool() &&
        wIntf.wReady.value.toBool()) {
      final packet = _writeMetadataQueue[mapIdx][0];
      packet.data.add(wIntf.wData.value);
      packet.strobe.add(wIntf.wStrb.value);
      logger.info('Captured write data on channel $index.');
      if (wIntf.wLast.value.toBool()) {
        logger.info('Finished capturing write data on channel $index.');
        _writeReadyToOccur[mapIdx] = true;
      }
    }
  }

  void _respondWrite({int index = 0}) {
    final wIntf = channels[index].wIntf!;
    final mapIdx = _writeAddrToChannel[index]!;

    // only work to do if we have received all of the data for our write request
    if (_writeReadyToOccur[mapIdx]) {
      // only respond if the main is ready
      if (wIntf.bReady.value.toBool()) {
        final packet = _writeMetadataQueue[mapIdx][0];

        // determine if the address falls in a region
        var addrToWrite = packet.addr;
        final region = _checkRegion(addrToWrite);
        final inRegion = region >= 0;
        final accessError = inRegion &&
            ((ranges[region].isSecure &&
                    ((packet.prot.toInt() & Axi4ProtField.secure.value) ==
                        0)) ||
                (ranges[region].isPrivileged &&
                    ((packet.prot.toInt() & Axi4ProtField.privileged.value) ==
                        0)));

        final error = respondWithError != null && respondWithError!(packet);

        // for now, only support sending slvErr and okay as responses
        wIntf.bValid.put(true);
        wIntf.bId?.put(packet.id);
        wIntf.bResp?.put(error || accessError
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

        // generic model does not handle the following write request fields:
        //  cache
        //  qos
        //  region
        //  user
        // These can be handled in a derived class of this model if need be.
        // Because they require implementation specific handling.

        // NOTE: generic model doesn't honor the prot field in write requests.
        // It will be added as a feature request in the future.

        // NOTE: generic model doesn't honor the lock field in write requests.
        // It will be added as a feature request in the future.

        if (!error && !dropWriteDataOnError && !accessError) {
          // write the data to the storage
          final dSize = (packet.size?.toInt() ?? 0) * 8;
          var increment = 0;
          if (packet.burst == null ||
              packet.burst!.toInt() == Axi4BurstField.wrap.value ||
              packet.burst!.toInt() == Axi4BurstField.incr.value) {
            increment = dSize ~/ 8;
          }

          for (var i = 0; i < packet.data.length; i++) {
            final rdData = storage.readData(addrToWrite);
            final strobedData =
                _strobeData(rdData, packet.data[i], packet.strobe[i]);
            final wrData = (dSize < strobedData.width)
                ? [strobedData.getRange(0, dSize), rdData.getRange(dSize)]
                    .rswizzle()
                : strobedData;
            storage.writeData(addrToWrite, wrData);
            if (inRegion &&
                (addrToWrite + increment >= ranges[region].end).toBool()) {
              // the original access fell in a region but the next access in
              // the burst overflows the region
              if (packet.burst!.toInt() == Axi4BurstField.wrap.value) {
                // indication that we should wrap around back to the region start
                addrToWrite = ranges[region].start;
              } else {
                // OK to overflow
                addrToWrite = addrToWrite + increment;
              }
            } else {
              // no region or overflow
              addrToWrite = addrToWrite + increment;
            }
          }
        }

        // pop this write response off the queue
        _writeMetadataQueue[mapIdx].removeAt(0);
        _writeReadyToOccur[mapIdx] = false;

        logger.info('Sent write response on channel $index.');
      }
    } else {
      wIntf.bValid.put(false);
    }
  }
}
