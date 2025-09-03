// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_memory_subordinate.dart
// A subordinate AXI4 agent that proxies a persistent memory.
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
/// an AXI4 multi-lane cluster of read/write channels
/// in which the underlying target is a persistent memory.
class Axi4SubordinateMemoryAgent extends Agent {
  /// The system interface.
  final Axi4SystemInterface sIntf;

  /// Channels that the subordinate manages.
  ///
  /// TODO: this requires every lane to be read/write...
  final List<Axi4SubordinateClusterAgent> lanes;

  /// A place where the subordinate should save and retrieve data.
  ///
  /// The [Axi4SubordinateMemoryAgent] will reset [storage] whenever
  /// the `resetN` signal is dropped.
  late final MemoryStorage storage;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(Axi4RequestPacket request)? readResponseDelay;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(Axi4RequestPacket request)? writeResponseDelay;

  /// A function that determines whether a response for a request should contain
  /// an error (`slvErr`).
  ///
  /// If none is provided, it will always respond with no error.
  final bool Function(Axi4RequestPacket request)? respondWithError;

  /// If `true`, then returned data on an error will be `x`.
  final bool invalidReadDataOnError;

  /// If `true`, then writes that respond with an error will not store into the
  /// [storage].
  final bool dropWriteDataOnError;

  /// Address range configuration. Controls access to addresses and helps
  /// with the wrap mode for bursts.
  // TODO(kimmeljo): ensure non-overlapping??
  List<AxiAddressRange> ranges = [];

  /// Enable locking functionality as per AXI4 spec.
  final bool supportLocking;

  // to handle response read responses
  final List<List<Axi4RequestPacket>> _dataReadResponseMetadataQueue = [];
  final List<List<List<LogicValue>>> _dataReadResponseDataQueue = [];
  // final List<List<bool>> _dataReadResponseErrorQueue = [];
  final List<int> _dataReadResponseIndex = [];

  // to handle writes
  final List<List<Axi4RequestPacket>> _writeMetadataQueue = [];
  final List<List<Axi4DataPacket>> _writeDataQueue = [];
  final List<bool> _writeReadyToOccur = [];

  // capture mapping of channel ID to TB object index
  final Map<int, int> _readAddrToChannel = {};
  final Map<int, int> _writeAddrToChannel = {};

  // for locking behavior
  final Map<LogicValue, int> _rmwLocks = {};

  /// Creates a new model [Axi4SubordinateMemoryAgent].
  ///
  /// If no [storage] is provided, it will use a default [SparseMemoryStorage].
  Axi4SubordinateMemoryAgent(
      {required this.sIntf,
      required this.lanes,
      required Component parent,
      MemoryStorage? storage,
      this.readResponseDelay,
      this.writeResponseDelay,
      this.respondWithError,
      this.invalidReadDataOnError = true,
      this.dropWriteDataOnError = true,
      this.ranges = const [],
      this.supportLocking = false,
      String name = 'axi4SubordinateMemoryAgent'})
      : super(name, parent) {
    var maxAddrWidth = 0;
    var maxDataWidth = 0;
    for (var i = 0; i < lanes.length; i++) {
      maxAddrWidth = max(maxAddrWidth, lanes[i].arIntf.addrWidth);
      maxDataWidth = max(maxDataWidth, lanes[i].rIntf.dataWidth);
    }

    this.storage = storage ??
        SparseMemoryStorage(
          addrWidth: maxAddrWidth,
          dataWidth: maxDataWidth,
        );
    for (var i = 0; i < lanes.length; i++) {
      // read side handling
      _dataReadResponseMetadataQueue.add([]);
      _dataReadResponseDataQueue.add([]);
      // _dataReadResponseErrorQueue.add([]);
      _dataReadResponseIndex.add(0);
      _readAddrToChannel[i] = _dataReadResponseMetadataQueue.length - 1;

      // write side handling
      _writeMetadataQueue.add([]);
      _writeDataQueue.add([]);
      _writeReadyToOccur.add(false);
      _writeAddrToChannel[i] = _writeMetadataQueue.length - 1;
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    sIntf.resetN.negedge.listen((event) {
      storage.reset();
      for (var i = 0; i < lanes.length; i++) {
        // read side reset
        _dataReadResponseMetadataQueue[_readAddrToChannel[i]!].clear();
        _dataReadResponseDataQueue[_readAddrToChannel[i]!].clear();
        // _dataReadResponseErrorQueue[_readAddrToChannel[i]!].clear();
        _dataReadResponseIndex[_readAddrToChannel[i]!] = 0;

        // write side reset
        _writeMetadataQueue[_writeAddrToChannel[i]!].clear();
        _writeDataQueue[_writeAddrToChannel[i]!].clear();
        _writeReadyToOccur[_writeAddrToChannel[i]!] = false;
      }
    });

    // wait for reset to complete
    await sIntf.resetN.nextPosedge;

    // register listeners on requests
    //  AR (read request)
    //  AW (write request)
    //  W (write request data)
    for (var i = 0; i < lanes.length; i++) {
      lanes[i]
          .writeAgent
          .reqAgent
          .monitor
          .stream
          .listen((d) => _receiveWrite(packet: d, index: i));
      lanes[i]
          .writeAgent
          .dataAgent
          .monitor
          .stream
          .listen((d) => _captureWriteData(packet: d, index: i));
      lanes[i]
          .readAgent
          .reqAgent
          .monitor
          .stream
          .listen((d) => _receiveRead(packet: d, index: i));
    }

    // handle responding to requests
    while (!Simulator.simulationHasEnded) {
      await sIntf.clk.nextNegedge;
      for (var i = 0; i < lanes.length; i++) {
        // write handling should come before reads for the edge case in which a
        // read happens in the cycle after the final WVALID for the same
        // channel/address
        // _driveWriteReadys(index: i);
        _respondWrite(index: i);
        // _captureWriteData(index: i);
        // _receiveWrite(index: i);

        // deal with reads after writes
        // _driveReadReadys(index: i);
        _respondRead(index: i);
        // _receiveRead(index: i);
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

  // // assesses the input ready signals and drives them appropriately
  // void _driveReadReadys({int index = 0}) {
  //   // for now, assume we can always handle a new request
  //   lanes[index].arIntf.ready.inject(true);
  // }

  // // assesses the input ready signals and drives them appropriately
  // void _driveWriteReadys({int index = 0}) {
  //   // for now, assume we can always handle a new request
  //   lanes[index].awIntf.ready.inject(true);
  //   lanes[index].awIntf.ready.inject(true);
  // }

  /// Receives one packet (or returns if not selected).
  void _receiveRead({required Axi4RequestPacket packet, int index = 0}) {
    final rIntf = lanes[index].arIntf;
    final mapIdx = _readAddrToChannel[index]!;

    logger.info('Received read request on channel $index.');

    // generic model does not handle the following read request fields:
    //  cache
    //  qos
    //  region
    //  user
    //  domain (even when applicable)
    //  bar (even when applicable)
    // These can be handled in a derived class of this model if need be.
    // Because they require implementation specific handling.

    // NOTE: generic model doesn't use the instruction/data bit of the prot field.

    // query storage to retrieve the data
    final data = <LogicValue>[];
    var addrToRead = rIntf.addr.value;
    final endCount = (rIntf.len?.value.toInt() ?? 0) + 1;
    final dSize = Axi4SizeField.getImpliedSize(
        Axi4SizeField.fromValue(rIntf.size?.value.toInt() ?? 0));
    var increment = 0;
    if (rIntf.burst == null ||
        rIntf.burst?.value.toInt() == Axi4BurstField.wrap.value ||
        rIntf.burst?.value.toInt() == Axi4BurstField.incr.value) {
      increment = dSize ~/ 8;
    }

    // determine if the address falls in a region
    final region = _checkRegion(addrToRead);
    final inRegion = region >= 0;

    // examine locking behavior
    final isRmw =
        supportLocking && (rIntf.lock != null && rIntf.lock!.value.toBool());

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

      // lock handling logic
      if (supportLocking) {
        // part of an rmw operation
        if (isRmw) {
          // assign the lock to this channel
          // regardless if it existed before
          logger.info('RMW locking address $addrToRead on channel $index.');
          _rmwLocks[addrToRead] = index;
        } else {
          // remove the rmw lock if it is there
          // regardless of what channel we came from
          if (_rmwLocks.containsKey(addrToRead)) {
            _rmwLocks.remove(addrToRead);
          }
        }
      }

      if (inRegion && (addrToRead + increment >= ranges[region].end).toBool()) {
        // the original access fell in a region but the next access in
        // the burst overflows the region
        if (rIntf.burst?.value.toInt() == Axi4BurstField.wrap.value) {
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

  // respond to a read request
  void _respondRead({int index = 0}) {
    final rIntf = lanes[index].rIntf;
    final mapIdx = _readAddrToChannel[index]!;

    // only respond if there is something to respond to
    // and the main side is indicating that it is ready to receive
    if (_dataReadResponseMetadataQueue[mapIdx].isNotEmpty &&
            _dataReadResponseDataQueue[mapIdx]
                .isNotEmpty /*&&
        _dataReadResponseErrorQueue[mapIdx].isNotEmpty*/
        ) {
      final packet = _dataReadResponseMetadataQueue[mapIdx][0];
      // final reqSideError = _dataReadResponseErrorQueue[mapIdx][0];
      final currData = _dataReadResponseDataQueue[mapIdx][0].rswizzle();
      final error = respondWithError != null && respondWithError!(packet);

      // check the request's region for legality
      final region = _checkRegion(packet.addr);
      final inRegion = region >= 0;

      // check if this was part of a locked transaction
      final locked = supportLocking &&
          packet.lock != null &&
          packet.lock!.toBool() &&
          _rmwLocks.containsKey(packet.addr) &&
          _rmwLocks[packet.addr] == index;

      final accessError = inRegion &&
          ((ranges[region].isSecure &&
                  ((packet.prot.toInt() & Axi4ProtField.secure.value) == 0)) ||
              (ranges[region].isPrivileged &&
                  ((packet.prot.toInt() & Axi4ProtField.privileged.value) ==
                      0)));

      // TODO(kimmeljo): how to deal with delays??
      // if (readResponseDelay != null) {
      //   final delayCycles = readResponseDelay!(packet);
      //   if (delayCycles > 0) {
      //     await sIntf.clk.waitCycles(delayCycles);
      //   }
      // }

      // for security, must 0 out data when an error occurs
      final rdData = error || accessError
          ? LogicValue.ofInt(0x0, currData.width)
          : currData;

      // push the response onto the driver
      final rVal = error || accessError /*|| reqSideError*/
          ? LogicValue.ofInt(Axi4RespField.slvErr.value, rIntf.resp!.width)
          : LogicValue.ofInt(
              (locked ? Axi4RespField.exOkay.value : Axi4RespField.okay.value),
              rIntf.resp!.width);
      lanes[index].readAgent.dataAgent.sequencer.add(Axi4DataPacket(
          data: rdData,
          user: LogicValue.ofInt(0, rIntf.userWidth),
          id: packet.id,
          resp: rVal));

      // pop this read response off the queue
      _dataReadResponseIndex[mapIdx] = 0;
      _dataReadResponseMetadataQueue[mapIdx].removeAt(0);
      _dataReadResponseDataQueue[mapIdx].removeAt(0);
      // _dataReadResponseErrorQueue[mapIdx].removeAt(0);

      logger.info('Queued read response for channel $index.');
    }
  }

  // handle an incoming write request
  void _receiveWrite({required Axi4RequestPacket packet, int index = 0}) {
    final awIntf = lanes[index].awIntf;
    final wIntf = lanes[index].wIntf;
    final mapIdx = _writeAddrToChannel[index]!;

    logger.info('Received write request on channel $index.');
    final packet = Axi4RequestPacket(
      addr: awIntf.addr.value,
      prot: awIntf.prot.value,
      id: awIntf.id?.value,
      len: awIntf.len?.value,
      size: awIntf.size?.value,
      burst: awIntf.burst?.value,
      lock: awIntf.lock?.value,
      cache: awIntf.cache?.value,
      qos: awIntf.qos?.value,
      region: awIntf.region?.value,
      user: awIntf.user?.value,
    );

    // might need to capture the first data and strobe simultaneously
    // NOTE: we are dropping wUser on the floor for now...
    if (wIntf.valid.value.toBool() && wIntf.ready.value.toBool()) {
      final dataPacket =
          Axi4DataPacket(data: wIntf.data.value, strb: wIntf.strb.value);
      _writeDataQueue[mapIdx].add(dataPacket);
      if (wIntf.last!.value.toBool()) {
        _writeReadyToOccur[mapIdx] = true;
      }
    }

    // queue up the packet for further processing
    _writeMetadataQueue[mapIdx].add(packet);
  }

  // method to capture incoming write data after the initial request
  // note that this method does not handle the first flit of write data
  // if it is transmitted simultaneously with the write request
  void _captureWriteData({required Axi4DataPacket packet, int index = 0}) {
    final wIntf = lanes[index].wIntf;
    final mapIdx = _writeAddrToChannel[index]!;

    // TODO: what about interleaving data on the same lane but w/ different IDs...

    // NOTE: we are dropping wUser on the floor for now...
    final dataPacket =
        Axi4DataPacket(data: wIntf.data.value, strb: wIntf.strb.value);
    _writeDataQueue[mapIdx].add(dataPacket);
    logger.info('Captured write data on channel $index.');
    if (wIntf.last!.value.toBool()) {
      logger.info('Finished capturing write data on channel $index.');
      _writeReadyToOccur[mapIdx] = true;
    }
  }

  void _respondWrite({int index = 0}) {
    final bIntf = lanes[index].bIntf;
    final mapIdx = _writeAddrToChannel[index]!;

    // only work to do if we have received all of the data for our write request
    if (_writeReadyToOccur[mapIdx]) {
      final packet = _writeMetadataQueue[mapIdx][0];

      // determine if the address falls in a region
      var addrToWrite = packet.addr;
      final region = _checkRegion(addrToWrite);
      final inRegion = region >= 0;
      final accessError = inRegion &&
          ((ranges[region].isSecure &&
                  ((packet.prot.toInt() & Axi4ProtField.secure.value) == 0)) ||
              (ranges[region].isPrivileged &&
                  ((packet.prot.toInt() & Axi4ProtField.privileged.value) ==
                      0)));

      // examine locking behavior
      final isRmw =
          supportLocking && (packet.lock != null && packet.lock!.toBool());

      // compute data size and increment
      final dSize = Axi4SizeField.getImpliedSize(
          Axi4SizeField.fromValue(packet.size!.toInt()));
      var increment = 0;
      if (packet.burst == null ||
          packet.burst!.toInt() == Axi4BurstField.wrap.value ||
          packet.burst!.toInt() == Axi4BurstField.incr.value) {
        increment = dSize ~/ 8;
      }

      // compute the addresses to write to
      // based on the burst mode, len, and size
      final addrsToWrite = <LogicValue>[];
      final dataToWrite = _writeDataQueue[mapIdx];
      for (var i = 0; i < dataToWrite.length; i++) {
        addrsToWrite.add(addrToWrite);
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

      // locking logic for write ops
      var rmwErr = false;
      if (supportLocking) {
        for (final addr in addrsToWrite) {
          // given write is rmw locked
          if (isRmw) {
            // rmw lock must be associated with our channel
            // if not, must respond with an error
            // also remove the lock moving forward
            if (!_rmwLocks.containsKey(addr) || _rmwLocks[addr] != index) {
              logger.info('Encountered a write on channel $index that is '
                  'part of an RMW but the lock was either '
                  'not initiated prior or removed.');
              rmwErr |= true;
              if (_rmwLocks.containsKey(addr)) {
                _rmwLocks.remove(addr);
              }
            }
          }
          // given write is not rmw locked
          else {
            // remove the rmw lock if it is there
            // regardless of what channel we came from
            if (_rmwLocks.containsKey(addr)) {
              _rmwLocks.remove(addr);
            }
          }
        }
      }

      final error = respondWithError != null && respondWithError!(packet);

      // drive the write response
      final rVal = error || accessError
          ? LogicValue.ofInt(Axi4RespField.slvErr.value, bIntf.resp!.width)
          : LogicValue.ofInt(
              (isRmw && !rmwErr
                  ? Axi4RespField.exOkay.value
                  : Axi4RespField.okay.value),
              bIntf.resp!.width);
      lanes[index].writeAgent.respAgent.sequencer.add(Axi4ResponsePacket(
          id: packet.id,
          resp: rVal,
          user: LogicValue.ofInt(0, bIntf.userWidth)));

      // TODO(kimmeljo): how to deal with delays??
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
      //  domain (even when applicable)
      //  bar (even when applicable)
      // These can be handled in a derived class of this model if need be.
      // Because they require implementation specific handling.

      // NOTE: generic model doesn't use the instruction/data bit of the prot field.

      // apply the write to storage
      // only if there were no errors
      if (!(error || accessError) || !dropWriteDataOnError) {
        for (var i = 0; i < dataToWrite.length; i++) {
          final rdData = storage.readData(addrsToWrite[i]);
          final strobedData =
              _strobeData(rdData, dataToWrite[i].data, dataToWrite[i].strb!);
          final wrData = (dSize < strobedData.width)
              ? [strobedData.getRange(0, dSize), rdData.getRange(dSize)]
                  .rswizzle()
              : strobedData;
          storage.writeData(addrsToWrite[i], wrData);
        }
      }

      // pop this write response off the queue
      _writeMetadataQueue[mapIdx].removeAt(0);
      _writeReadyToOccur[mapIdx] = false;

      logger.info('Sent write response on channel $index.');
    }
  }
}
