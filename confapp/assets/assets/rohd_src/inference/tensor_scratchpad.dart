// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_scratchpad.dart
// Ready/valid banked tensor scratchpad.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/bit_operations/selection/one_hot_mux.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/priority_arbiter.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/storage/memory_array_factories.dart';

/// Policy for multiple scratchpad requests to the same bank in one cycle.
enum TensorScratchpadBankConflictPolicy {
  /// Admit requests only to banks that have a single contender.
  disallow,

  /// Admit the first contender per bank, with writes ordered before reads.
  lowestPortWins,

  /// Do not admit any bank request in a cycle with a conflict.
  stall,
}

/// Mapping from the scratchpad's flat word address to a physical bank.
enum TensorScratchpadBankMapping {
  /// Select a bank with the low address bits; requires power-of-two banking.
  lowAddressBits,

  /// Select a bank with the remainder after dividing by the bank count.
  modulo,
}

/// One tensor scratchpad read request.
/// {@category Inference}
class TensorScratchpadReadRequest extends LogicStructure {
  /// Flat scratchpad address.
  late final Logic address;

  /// Metadata returned with the read response.
  late final Logic tag;

  /// Width of [address].
  final int addressWidth;

  /// Width of [tag].
  final int tagWidth;

  /// Creates a scratchpad read request shape.
  TensorScratchpadReadRequest({
    required this.addressWidth,
    required this.tagWidth,
    String name = 'tensorScratchpadReadRequest',
  }) : super(
          [
            Logic(name: 'address', width: addressWidth),
            Logic(name: 'tag', width: tagWidth),
          ],
          name: name,
        ) {
    if (addressWidth < 1 || tagWidth < 1) {
      throw ArgumentError('Scratchpad read widths must be positive.');
    }
    address = elements[0];
    tag = elements[1];
  }

  TensorScratchpadReadRequest._clone(
    List<Logic> elements, {
    required this.addressWidth,
    required this.tagWidth,
    required String name,
  }) : super(elements, name: name) {
    address = elements[0];
    tag = elements[1];
  }

  @override
  TensorScratchpadReadRequest clone({String? name}) =>
      TensorScratchpadReadRequest._clone(
        elements.map((element) => element.clone(name: element.name)).toList(),
        addressWidth: addressWidth,
        tagWidth: tagWidth,
        name: name ?? this.name,
      );
}

/// One tensor scratchpad write request retaining the word schema [T].
/// {@category Inference}
class TensorScratchpadWriteRequest<T extends Logic> extends LogicStructure {
  /// Flat scratchpad address.
  late final Logic address;

  /// Complete word to store.
  T get data => elements[1] as T;

  /// Width of [address].
  final int addressWidth;

  /// Width of [data].
  final int dataWidth;

  /// Creates a scratchpad write request with a checked clone of [data].
  ///
  /// [data] is a schema, not a driver. Drive this request's [data] field.
  TensorScratchpadWriteRequest({
    required this.addressWidth,
    required T data,
    String name = 'tensorScratchpadWriteRequest',
  })  : dataWidth = data.width,
        super(
          [
            Logic(name: 'address', width: addressWidth),
            cloneTypedPayload<T>(data, name: 'data'),
          ],
          name: name,
        ) {
    if (addressWidth < 1 || dataWidth < 1) {
      throw ArgumentError('Scratchpad write widths must be positive.');
    }
    address = elements[0];
  }

  @override
  TensorScratchpadWriteRequest<T> clone({String? name}) =>
      TensorScratchpadWriteRequest<T>(
        data: data,
        addressWidth: addressWidth,
        name: name ?? this.name,
      );
}

/// One retained tensor scratchpad read response retaining the word schema [T].
/// {@category Inference}
class TensorScratchpadReadResponse<T extends Logic> extends LogicStructure {
  /// Returned word.
  T get data => elements[0] as T;

  /// Metadata copied from the accepted request.
  late final Logic tag;

  /// High when the request address was outside the scratchpad.
  late final Logic error;

  /// Width of [data].
  final int dataWidth;

  /// Width of [tag].
  final int tagWidth;

  /// Creates a scratchpad read response with a checked clone of [data].
  TensorScratchpadReadResponse({
    required T data,
    required this.tagWidth,
    String name = 'tensorScratchpadReadResponse',
  })  : dataWidth = data.width,
        super(
          [
            cloneTypedPayload<T>(data, name: 'data'),
            Logic(name: 'tag', width: tagWidth),
            Logic(name: 'error'),
          ],
          name: name,
        ) {
    if (dataWidth < 1 || tagWidth < 1) {
      throw ArgumentError('Scratchpad response widths must be positive.');
    }
    tag = elements[1];
    error = elements[2];
  }

  @override
  TensorScratchpadReadResponse<T> clone({String? name}) =>
      TensorScratchpadReadResponse<T>(
        data: data,
        tagWidth: tagWidth,
        name: name ?? this.name,
      );
}

class _TensorScratchpadReadPortController<T extends Logic> extends Module {
  Logic get requestCandidate => output('requestCandidate');

  Logic get requestReady => output('requestReady');

  Logic get responseValid => output('responseValid');

  late final T responseData;

  Logic get responseTag => output('responseTag');

  Logic get responseError => output('responseError');

  Logic get invalidAddress => output('invalidAddress');

  Logic get overflow => output('overflow');

  Logic get unexpectedResponse => output('unexpectedResponse');

  _TensorScratchpadReadPortController({
    required Logic clk,
    required Logic reset,
    required Logic requestValid,
    required Logic requestAddressValid,
    required Logic requestTag,
    required Logic requestGrant,
    required Logic rawResponseValid,
    required T rawResponseData,
    required Logic downstreamReady,
    required int dataWidth,
    required int tagWidth,
    super.name = 'tensor_scratchpad_read_port_controller',
  }) : super(
          definitionName: schemaQualifiedDefinitionName(
            'TensorScratchpadReadPortController_',
            [rawResponseData],
            suffix: '_T$tagWidth',
          ),
        ) {
    if (requestTag.width != tagWidth || rawResponseData.width != dataWidth) {
      throw ArgumentError('Scratchpad read-controller widths do not match.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localRequestValid = addInput('requestValid', requestValid);
    final localAddressValid =
        addInput('requestAddressValid', requestAddressValid);
    final localRequestTag = addInput('requestTag', requestTag, width: tagWidth);
    final localRequestGrant = addInput('requestGrant', requestGrant);
    final localRawValid = addInput('rawResponseValid', rawResponseValid);
    final localRawData = addTypedInput<T>('rawResponseData', rawResponseData);
    final localDownstreamReady = addInput('downstreamReady', downstreamReady);
    final outstanding = Logic(name: '${name}_outstanding');
    final occupied = Logic(name: '${name}_occupied');
    final pendingTag = Logic(name: '${name}_pending_tag', width: tagWidth);
    final storedData =
        cloneTypedPayload<T>(localRawData, name: '${name}_stored_data');
    final storedTag = Logic(name: '${name}_stored_tag', width: tagWidth);
    final storedError = Logic(name: '${name}_stored_error');
    final canAcceptRequest = ~outstanding & (~occupied | localDownstreamReady);
    final candidate = localRequestValid & localAddressValid & canAcceptRequest;
    final requestIssued = candidate & localRequestGrant;
    final invalidAccepted =
        localRequestValid & ~localAddressValid & canAcceptRequest;
    final responseArrives = localRawValid & outstanding;
    final responseAccepted = occupied & localDownstreamReady;

    addOutput('requestCandidate') <= candidate;
    addOutput('requestReady') <=
        mux(
          localRequestValid,
          mux(localAddressValid, requestIssued, canAcceptRequest),
          canAcceptRequest,
        );
    addOutput('responseValid') <= occupied;
    responseData = addTypedPayloadOutput<T>(this, 'responseData', storedData);
    responseData <= storedData;
    addOutput('responseTag', width: tagWidth) <= storedTag;
    addOutput('responseError') <= storedError;
    addOutput('invalidAddress') <= invalidAccepted;
    addOutput('overflow') <= responseArrives & occupied & ~localDownstreamReady;
    addOutput('unexpectedResponse') <= localRawValid & ~outstanding;

    Sequential(localClk, reset: localReset, resetValues: {
      outstanding: 0,
      occupied: 0,
      pendingTag: 0,
      storedData: 0,
      storedTag: 0,
      storedError: 0,
    }, [
      If(requestIssued, then: [
        outstanding < 1,
        pendingTag < localRequestTag,
      ]),
      If(responseArrives, then: [
        outstanding < 0,
        occupied < 1,
        storedData < localRawData,
        storedTag < pendingTag,
        storedError < 0,
      ]),
      If(invalidAccepted, then: [
        occupied < 1,
        storedData < 0,
        storedTag < localRequestTag,
        storedError < 1,
      ]),
      If(
        responseAccepted & ~responseArrives & ~invalidAccepted,
        then: [occupied < 0],
      ),
    ]);
  }
}

/// Banked tensor scratchpad with typed requests and synchronous enables.
///
/// Requests to different banks may proceed concurrently. Conflicting requests
/// are resolved by [bankConflictPolicy], with writes ordered before reads.
/// Each read port permits one outstanding raw response and retains that
/// response irrevocably until accepted. Out-of-range reads return a retained
/// zero/error response; out-of-range writes are consumed and reported.
/// A valid read has one cycle of bank latency followed by one cycle to enter
/// the retained response slot. Each bank performs at most one access per cycle.
/// Word type [T] and its declared schema survive bank selection, backing
/// storage, and response retention. All word ports must have compatible
/// schemas.
///
/// Each read/write enable bit offers one access for arbitration on that edge.
/// [canRead] and [canWrite] give admission capacity; only enabled accesses with
/// capacity are admitted. The core never retries a denied offer. A scheduler
/// must account for bank conflicts and port capacity. With `consumeResponses`
/// omitted, each retained response is consumed on the following edge;
/// explicit consumption permits external retention.
/// Reset abandons outstanding reads and clears response slots.
/// {@category Inference}
class TensorScratchpadCore<T extends Logic> extends Module {
  /// Read admission capacity, one bit per logical port.
  Logic get canRead => output('canRead');

  /// Write admission capacity, one bit per logical port.
  Logic get canWrite => output('canWrite');

  /// Retained response availability, one bit per logical port.
  Logic get responseValid => output('responseValid');

  /// Typed retained response ports.
  late final List<TensorScratchpadReadResponse<T>> responses;

  /// Number of flat addressable words.
  final int depth;

  /// Width of one word.
  final int dataWidth;

  /// Width of flat addresses.
  final int addressWidth;

  /// Width of read-response tags.
  final int tagWidth;

  /// Number of physical memory banks.
  final int bankCount;

  /// Bank-conflict policy.
  final TensorScratchpadBankConflictPolicy bankConflictPolicy;

  /// Address-to-bank mapping.
  final TensorScratchpadBankMapping bankMapping;

  /// Selected bank storage. Combinational reads are registered by this module;
  /// one-cycle arrays are used directly.
  final MemoryArrayFunctor<T> memoryFunctor;

  /// Schema shared by every stored word.
  final T wordSchema;

  /// Optional backing-array read collision requirement.
  ///
  /// No same-cycle read/write is issued to a bank. A combinational array with
  /// the read register at the scratchpad boundary has an
  /// [MemoryArrayReadCollision.oldData] sampling contract.
  final MemoryArrayReadCollision? readUnderWrite;

  late final List<TensorScratchpadReadRequest> _readRequests;
  late final List<TensorScratchpadWriteRequest<T>> _writeRequests;
  late final Logic _readEnable;
  late final Logic _writeEnable;
  late final Logic _consumeResponses;

  /// One blocked bit per write followed by read request.
  Logic get blockedRequests => output('blockedRequests');

  /// One bank-denied bit per write followed by read request.
  Logic get bankConflicts => output('bankConflicts');

  /// One invalid-address pulse per read request.
  Logic get invalidReadAddress => output('invalidReadAddress');

  /// One invalid-address pulse per write request.
  Logic get invalidWriteAddress => output('invalidWriteAddress');

  /// One response-buffer overflow bit per read port.
  Logic get responseOverflow => output('responseOverflow');

  /// One unexpected raw response bit per read port.
  Logic get unexpectedResponse => output('unexpectedResponse');

  /// Creates an action-driven banked tensor scratchpad.
  ///
  /// Banks use a single unmasked read port and a single unmasked write port
  /// with one shared access per cycle. The default array clears on reset;
  /// custom arrays provide their own storage reset behavior.
  TensorScratchpadCore({
    required Logic clk,
    required Logic reset,
    required List<TensorScratchpadReadRequest> readRequests,
    required List<TensorScratchpadReadResponse<T>> readResponses,
    required List<TensorScratchpadWriteRequest<T>> writeRequests,
    required Logic readEnable,
    required Logic writeEnable,
    required this.depth,
    required this.bankCount,
    Logic? consumeResponses,
    MemoryArrayFunctor<T>? memoryFunctor,
    this.bankConflictPolicy = TensorScratchpadBankConflictPolicy.lowestPortWins,
    this.bankMapping = TensorScratchpadBankMapping.lowAddressBits,
    this.readUnderWrite,
    super.name = 'tensor_scratchpad_core',
  })  : memoryFunctor = memoryFunctor ?? registerFileArray<T>(),
        wordSchema = _firstPort(writeRequests, 'writeRequests').data,
        dataWidth = _firstPort(writeRequests, 'writeRequests').dataWidth,
        addressWidth = max(1, max(depth, 1).log2Ceil),
        tagWidth = _firstPort(readRequests, 'readRequests').tagWidth,
        super(
          definitionName: schemaQualifiedDefinitionName(
              'TensorScratchpadCore_'
              'D${depth}_W${writeRequests.first.dataWidth}_'
              'B${bankCount}_R${readRequests.length}_'
              'P${writeRequests.length}_T${readRequests.first.tagWidth}_'
              '${bankConflictPolicy.name}_${bankMapping.name}_'
              '${memoryFunctor?.identity ?? 'registerFile'}_',
              [writeRequests.first.data]),
        ) {
    if (readResponses.length != readRequests.length) {
      throw ArgumentError(
        'Scratchpads require one response per read port.',
      );
    }
    if (depth < 1 || bankCount < 1 || bankCount > depth) {
      throw ArgumentError('Scratchpad depth and bank count are invalid.');
    }
    if (bankMapping == TensorScratchpadBankMapping.lowAddressBits &&
        (bankCount & (bankCount - 1)) != 0) {
      throw ArgumentError(
        'Low-address-bit banking requires a power-of-two bank count.',
      );
    }
    if (readRequests.any(
          (request) =>
              request.addressWidth != addressWidth ||
              request.tagWidth != tagWidth,
        ) ||
        writeRequests.any(
          (request) =>
              request.addressWidth != addressWidth ||
              request.dataWidth != dataWidth,
        ) ||
        readResponses.any(
          (response) =>
              response.dataWidth != dataWidth || response.tagWidth != tagWidth,
        )) {
      throw ArgumentError('Scratchpad port shapes do not match.');
    }
    if (!compatiblePayloadSet([
      wordSchema,
      for (final request in writeRequests) request.data,
      for (final response in readResponses) response.data,
    ], allowRenamedClones: true)) {
      throw ArgumentError('Scratchpad word schemas do not match.');
    }
    final latency = this.memoryFunctor.capabilities.readLatency;
    if (latency != 0 && latency != 1) {
      throw ArgumentError('Scratchpad bank read latency must be 0 or 1.');
    }
    if (latency == 0 &&
        readUnderWrite != null &&
        readUnderWrite != MemoryArrayReadCollision.oldData) {
      throw ArgumentError('Registered combinational scratchpad reads '
          'sample old data.');
    }

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    _readRequests = UnmodifiableListView([
      for (var port = 0; port < readRequests.length; port++)
        addTypedInput<TensorScratchpadReadRequest>(
            'read_$port', readRequests[port]),
    ]);
    _writeRequests = UnmodifiableListView([
      for (var port = 0; port < writeRequests.length; port++)
        addTypedInput<TensorScratchpadWriteRequest<T>>(
            'write_$port', writeRequests[port]),
    ]);
    responses = UnmodifiableListView([
      for (var port = 0; port < readResponses.length; port++)
        addTypedPayloadOutput(this, 'response_$port', readResponses[port]),
    ]);
    _readEnable =
        addInput('readEnable', readEnable, width: readRequests.length);
    _writeEnable =
        addInput('writeEnable', writeEnable, width: writeRequests.length);
    _consumeResponses = addInput(
      'consumeResponses',
      consumeResponses ??
          Const(LogicValue.filled(readRequests.length, LogicValue.one)),
      width: readRequests.length,
    );
    final readCapacity = [
      for (var port = 0; port < readRequests.length; port++)
        Logic(name: '${name}_read_${port}_capacity'),
    ];
    final writeCapacity = [
      for (var port = 0; port < writeRequests.length; port++)
        Logic(name: '${name}_write_${port}_capacity'),
    ];

    final readGrantSignals = [
      for (var port = 0; port < readRequests.length; port++)
        Logic(name: '${name}_read_${port}_grant'),
    ];
    final rawReads = [
      for (var port = 0; port < readRequests.length; port++)
        (
          valid: Logic(name: 'rawValid_$port'),
          data: cloneTypedPayload<T>(wordSchema, name: 'rawData_$port'),
        ),
    ];
    final readControllers = <_TensorScratchpadReadPortController<T>>[];
    final readCandidates = <Logic>[];
    for (var port = 0; port < readRequests.length; port++) {
      final request = _readRequests[port];
      final response = responses[port];
      final raw = rawReads[port];
      final addressValid = _addressInRange(request.address, depth);
      final controller = _TensorScratchpadReadPortController<T>(
        clk: localClk,
        reset: localReset,
        requestValid: _readEnable[port],
        requestAddressValid: addressValid,
        requestTag: request.tag,
        requestGrant: readGrantSignals[port],
        rawResponseValid: raw.valid,
        rawResponseData: raw.data,
        downstreamReady: _consumeResponses[port],
        dataWidth: dataWidth,
        tagWidth: tagWidth,
        name: '${name}_read_${port}_controller',
      );
      readCapacity[port] <= controller.requestReady;
      response.data <= controller.responseData;
      response.tag <= controller.responseTag;
      response.error <= controller.responseError;
      readCandidates.add(controller.requestCandidate);
      readControllers.add(controller);
    }
    final writeCandidates = <Logic>[];
    final writeAddressValid = <Logic>[];
    for (var port = 0; port < writeRequests.length; port++) {
      final request = _writeRequests[port];
      final addressValid = _addressInRange(request.address, depth);
      writeCandidates.add(_writeEnable[port] & addressValid);
      writeAddressValid.add(addressValid);
    }
    final grants = _connectBanks(
      clk: localClk,
      reset: localReset,
      candidates: [...writeCandidates, ...readCandidates],
      rawReads: rawReads,
    );
    final writeGrants = grants.take(writeRequests.length).toList();
    final readGrants = grants.skip(writeRequests.length).toList();
    final invalidReadPulses = <Logic>[];
    final invalidWritePulses = <Logic>[];
    final blocked = <Logic>[];
    final conflicts = <Logic>[];

    for (var port = 0; port < writeRequests.length; port++) {
      final enabled = _writeEnable[port];
      final invalidAccepted = enabled & ~writeAddressValid[port];
      writeCapacity[port] <=
          mux(
            enabled,
            mux(writeAddressValid[port], writeGrants[port], Const(1)),
            Const(1),
          );
      invalidWritePulses.add(invalidAccepted);
      blocked.add(enabled & ~writeCapacity[port]);
      conflicts.add(writeCandidates[port] & ~writeGrants[port]);
    }
    for (var port = 0; port < readRequests.length; port++) {
      readGrantSignals[port] <= readGrants[port];
      invalidReadPulses.add(readControllers[port].invalidAddress);
      blocked.add(_readEnable[port] & ~readCapacity[port]);
      conflicts.add(readCandidates[port] & ~readGrants[port]);
    }

    addOutput('canRead', width: readRequests.length) <= readCapacity.rconcat();
    addOutput('canWrite', width: writeRequests.length) <=
        writeCapacity.rconcat();
    addOutput('responseValid', width: readResponses.length) <=
        readControllers
            .map((controller) => controller.responseValid)
            .toList()
            .rconcat();
    addOutput(
          'blockedRequests',
          width: writeRequests.length + readRequests.length,
        ) <=
        blocked.rconcat();
    addOutput(
          'bankConflicts',
          width: writeRequests.length + readRequests.length,
        ) <=
        conflicts.rconcat();
    addOutput('invalidReadAddress', width: readRequests.length) <=
        invalidReadPulses.rconcat();
    addOutput('invalidWriteAddress', width: writeRequests.length) <=
        invalidWritePulses.rconcat();
    addOutput('responseOverflow', width: readRequests.length) <=
        readControllers
            .map((controller) => controller.overflow)
            .toList()
            .rconcat();
    addOutput('unexpectedResponse', width: readRequests.length) <=
        readControllers
            .map((controller) => controller.unexpectedResponse)
            .toList()
            .rconcat();
  }

  List<Logic> _connectBanks({
    required Logic clk,
    required Logic reset,
    required List<Logic> candidates,
    required List<({Logic valid, T data})> rawReads,
  }) {
    final writes = _writeRequests.length;
    final addresses = [
      for (final request in _writeRequests) request.address,
      for (final request in _readRequests) request.address,
    ];
    final coordinates = addresses.map(_bankCoordinate).toList();
    final requests = [
      for (var bank = 0; bank < bankCount; bank++)
        [
          for (var port = 0; port < candidates.length; port++)
            candidates[port] & coordinates[port].bank.eq(bank),
        ],
    ];
    final grantsByBank = _admitBanks(requests);
    final latency = memoryFunctor.capabilities.readLatency;
    final bankReturns = <({Logic readers, T data})>[];

    for (var bank = 0; bank < bankCount; bank++) {
      final grants = grantsByBank[bank];
      final writeGrants = grants.take(writes).toList().rconcat();
      final readGrants = grants.skip(writes).toList().rconcat();
      final rows = (depth - 1 - bank) ~/ bankCount + 1;
      final rowWidth = max(1, rows.log2Ceil);
      final rowAddresses = [
        for (final coordinate in coordinates)
          coordinate.row.getRange(0, rowWidth),
      ];
      final write = DataPortInterface<T>.typed(wordSchema, rowWidth);
      final read = DataPortInterface<T>.typed(wordSchema, rowWidth);
      write.en <= writeGrants.or();
      write.addr <=
          OneHotMux(writeGrants, rowAddresses.take(writes).toList()).result;
      final writeWords = [
        for (final request in _writeRequests) request.data,
      ];
      write.data <= OneHotMux<T>(writeGrants, writeWords).result;
      read.en <= readGrants.or();
      read.addr <=
          OneHotMux(readGrants, rowAddresses.skip(writes).toList()).result;
      memoryFunctor(
        clk: clk,
        reset: reset,
        writePorts: [write],
        readPorts: [read],
        entryCount: rows,
        readLatency: latency,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        maxConcurrentAccesses: 1,
        requiredReadCollision: latency == 1 ? readUnderWrite : null,
        name: '${name}_bank_$bank',
      );
      // Route the one-cycle result using the grant sampled with the address.
      bankReturns.add((
        readers: flop(clk, readGrants, reset: reset),
        data: latency == 0
            ? flop<T>(clk, read.data, en: read.en, reset: reset)
            : read.data,
      ));
    }

    final bankData = [for (final response in bankReturns) response.data];
    for (var port = 0; port < rawReads.length; port++) {
      final selected = [
        for (final response in bankReturns) response.readers[port],
      ].rconcat();
      rawReads[port].valid <= selected.or();
      rawReads[port].data <= OneHotMux<T>(selected, bankData).result;
    }
    return [
      for (var port = 0; port < candidates.length; port++)
        [for (final grants in grantsByBank) grants[port]].rconcat().or(),
    ];
  }

  List<List<Logic>> _admitBanks(List<List<Logic>> requests) {
    if (bankConflictPolicy ==
        TensorScratchpadBankConflictPolicy.lowestPortWins) {
      return [
        for (final bankRequests in requests)
          PriorityArbiter(bankRequests).grants,
      ];
    }

    final conflicts = [
      for (final bankRequests in requests) _hasConflict(bankRequests),
    ];
    final stallAll =
        bankConflictPolicy == TensorScratchpadBankConflictPolicy.stall;
    final anyConflict = stallAll ? conflicts.rconcat().or() : null;
    return [
      for (var bank = 0; bank < requests.length; bank++)
        [
          for (final request in requests[bank])
            request & ~(anyConflict ?? conflicts[bank]),
        ],
    ];
  }

  static Logic _hasConflict(List<Logic> requests) {
    Logic seen = Const(0);
    Logic conflict = Const(0);
    for (final request in requests) {
      conflict = conflict | (request & seen);
      seen = seen | request;
    }
    return conflict;
  }

  ({Logic bank, Logic row}) _bankCoordinate(Logic address) {
    if (bankCount == 1) {
      return (bank: Const(0), row: address);
    }
    if ((bankCount & (bankCount - 1)) == 0) {
      final bits = bankCount.log2Ceil;
      return (bank: address.getRange(0, bits), row: address >>> bits);
    }
    final banks = Const(bankCount, width: addressWidth);
    return (bank: address % banks, row: address / banks);
  }

  static Logic _addressInRange(Logic address, int depth) =>
      BigInt.from(depth) == (BigInt.one << address.width)
          ? Const(1)
          : address.lt(Const(depth, width: address.width));
}

/// Ready/valid logical-port adapter around [TensorScratchpadCore].
///
/// Request offers identify contenders for core arbitration. Ingress
/// attachments expose admission capacity as accepted transfers, and egress
/// attachments retire the core's typed retained responses.
/// {@category Inference}
class TensorScratchpad<T extends Logic> extends Module {
  late final TensorScratchpadCore<T> _core;

  /// See [TensorScratchpadCore.depth].
  int get depth => _core.depth;

  /// See [TensorScratchpadCore.dataWidth].
  int get dataWidth => _core.dataWidth;

  /// See [TensorScratchpadCore.addressWidth].
  int get addressWidth => _core.addressWidth;

  /// See [TensorScratchpadCore.tagWidth].
  int get tagWidth => _core.tagWidth;

  /// See [TensorScratchpadCore.bankCount].
  int get bankCount => _core.bankCount;

  /// See [TensorScratchpadCore.bankConflictPolicy].
  TensorScratchpadBankConflictPolicy get bankConflictPolicy =>
      _core.bankConflictPolicy;

  /// See [TensorScratchpadCore.bankMapping].
  TensorScratchpadBankMapping get bankMapping => _core.bankMapping;

  /// See [TensorScratchpadCore.memoryFunctor].
  MemoryArrayFunctor<T> get memoryFunctor => _core.memoryFunctor;

  /// See [TensorScratchpadCore.wordSchema].
  T get wordSchema => _core.wordSchema;

  /// See [TensorScratchpadCore.readUnderWrite].
  MemoryArrayReadCollision? get readUnderWrite => _core.readUnderWrite;

  /// See [TensorScratchpadCore.blockedRequests].
  Logic get blockedRequests => output('blockedRequests');

  /// See [TensorScratchpadCore.bankConflicts].
  Logic get bankConflicts => output('bankConflicts');

  /// See [TensorScratchpadCore.invalidReadAddress].
  Logic get invalidReadAddress => output('invalidReadAddress');

  /// See [TensorScratchpadCore.invalidWriteAddress].
  Logic get invalidWriteAddress => output('invalidWriteAddress');

  /// See [TensorScratchpadCore.responseOverflow].
  Logic get responseOverflow => output('responseOverflow');

  /// See [TensorScratchpadCore.unexpectedResponse].
  Logic get unexpectedResponse => output('unexpectedResponse');

  /// Attaches logical ready/valid ports to the typed banked storage core.
  TensorScratchpad({
    required Logic clk,
    required Logic reset,
    required List<ReadyValidInterface<TensorScratchpadReadRequest>>
        readRequests,
    required List<ReadyValidInterface<TensorScratchpadReadResponse<T>>>
        readResponses,
    required List<ReadyValidInterface<TensorScratchpadWriteRequest<T>>>
        writeRequests,
    required int depth,
    required int bankCount,
    MemoryArrayFunctor<T>? memoryFunctor,
    TensorScratchpadBankConflictPolicy bankConflictPolicy =
        TensorScratchpadBankConflictPolicy.lowestPortWins,
    TensorScratchpadBankMapping bankMapping =
        TensorScratchpadBankMapping.lowAddressBits,
    MemoryArrayReadCollision? readUnderWrite,
    super.name = 'tensor_scratchpad',
  }) : super(
          definitionName: schemaQualifiedDefinitionName(
              'TensorScratchpad_D${depth}_'
              'W${_firstPort(writeRequests, 'writeRequests').data.dataWidth}_'
              'B${bankCount}_R${readRequests.length}_'
              'P${writeRequests.length}_'
              'T${_firstPort(readRequests, 'readRequests').data.tagWidth}_'
              '${bankConflictPolicy.name}_${bankMapping.name}_'
              '${memoryFunctor?.identity ?? 'registerFile'}_',
              [
                _firstPort(
                  writeRequests,
                  'writeRequests',
                ).data.data
              ]),
        ) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final inputs = [
      for (var port = 0; port < readRequests.length; port++)
        addPairInterface(readRequests[port], PairRole.consumer,
            uniquify: (original) => 'read_${port}_$original'),
    ];
    final writes = [
      for (var port = 0; port < writeRequests.length; port++)
        addPairInterface(writeRequests[port], PairRole.consumer,
            uniquify: (original) => 'write_${port}_$original'),
    ];
    final outputs = [
      for (var port = 0; port < readResponses.length; port++)
        addPairInterfaceFrom(
          IrrevocableReadyValidInterface(readResponses[port].data.clone()),
          readResponses[port],
          PairRole.provider,
          uniquify: (original) => 'response_${port}_$original',
        ),
    ];
    final readPayloads = [
      for (final input in inputs) cloneTypedPayload(input.data),
    ];
    final writePayloads = [
      for (final write in writes) cloneTypedPayload(write.data),
    ];
    final consumes = [
      for (var port = 0; port < outputs.length; port++)
        Logic(name: '${name}_consume_$port'),
    ];
    _core = TensorScratchpadCore<T>(
      clk: localClk,
      reset: localReset,
      readRequests: readPayloads,
      writeRequests: writePayloads,
      readResponses: [for (final output in outputs) output.data],
      readEnable: [for (final input in inputs) input.valid].rconcat(),
      writeEnable: [for (final write in writes) write.valid].rconcat(),
      consumeResponses: consumes.rconcat(),
      depth: depth,
      bankCount: bankCount,
      memoryFunctor: memoryFunctor,
      bankConflictPolicy: bankConflictPolicy,
      bankMapping: bankMapping,
      readUnderWrite: readUnderWrite,
      name: '${name}_core',
    );
    for (var port = 0; port < inputs.length; port++) {
      ReadyValidIngressAttachmentPolicy<TensorScratchpadReadRequest>(
        supportsSameCycleReplacement: true,
      ).attach(
        upstream: inputs[port],
        canAccept: _core.canRead[port],
        accept: Logic(name: '${name}_read_${port}_accepted'),
        payload: readPayloads[port],
      );
      ReadyValidEgressAttachmentPolicy<TensorScratchpadReadResponse<T>>()
          .attach(
        downstream: outputs[port],
        offerValid: _core.responseValid[port],
        payload: _core.responses[port],
        transfer: consumes[port],
      );
    }
    for (var port = 0; port < writes.length; port++) {
      ReadyValidIngressAttachmentPolicy<TensorScratchpadWriteRequest<T>>(
        supportsSameCycleReplacement: false,
      ).attach(
        upstream: writes[port],
        canAccept: _core.canWrite[port],
        accept: Logic(name: '${name}_write_${port}_accepted'),
        payload: writePayloads[port],
      );
    }
    for (final port in [
      'blockedRequests',
      'bankConflicts',
      'invalidReadAddress',
      'invalidWriteAddress',
      'responseOverflow',
      'unexpectedResponse',
    ]) {
      final signal = _core.output(port);
      addOutput(port, width: signal.width) <= signal;
    }
  }
}

T _firstPort<T>(List<T> ports, String name) {
  if (ports.isEmpty) {
    throw ArgumentError.value(ports, name, 'At least one port is required.');
  }
  return ports.first;
}
