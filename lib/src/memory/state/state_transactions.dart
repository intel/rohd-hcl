// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// state_transactions.dart
// Common snapshot and restore transaction contracts.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Transport used to execute a state snapshot or restore transaction.
enum StateTransactionTransport {
  /// No transaction transport is available.
  unsupported,

  /// Transactions are software method calls and create no hardware ports.
  software,

  /// Transactions use an acknowledged hardware protocol.
  hardware
}

/// Quiescence required before a state transaction may be accepted.
enum StateTransactionQuiescence {
  /// The operation is valid while normal activity continues.
  none,

  /// The caller must first stop and drain normal activity.
  required
}

/// How completion of an accepted state transaction is reported.
enum StateTransactionCompletionMode {
  /// Completion is returned by the request call.
  immediate,

  /// Completion is explicitly acknowledged by a hardware protocol.
  acknowledged
}

/// Capabilities for direct memory-state access operations.
class MemoryStateAccessCapabilities {
  /// Capabilities for a software memory model with logical image access.
  static const softwareModel = MemoryStateAccessCapabilities(
    supportsReset: true,
    supportsInitialization: true,
    supportsLoad: true,
    supportsDump: true,
    supportsInspection: true,
  );

  /// Creates a direct memory-state capability declaration.
  const MemoryStateAccessCapabilities({
    required this.supportsReset,
    required this.supportsInitialization,
    required this.supportsLoad,
    required this.supportsDump,
    required this.supportsInspection,
  });

  /// Whether reset can clear or otherwise reinitialize the state.
  final bool supportsReset;

  /// Whether the implementation supports initial state provisioning.
  final bool supportsInitialization;

  /// Whether a logical image can be loaded outside snapshot/restore.
  final bool supportsLoad;

  /// Whether current state can be dumped as a logical image.
  final bool supportsDump;

  /// Whether state can be inspected without replacing it.
  final bool supportsInspection;
}

/// Provides direct memory-state access capability information.
abstract interface class MemoryStateAccessCapabilityProvider {
  /// Direct memory-state access capabilities.
  MemoryStateAccessCapabilities get memoryStateAccessCapabilities;
}

/// Static snapshot and restore capabilities of a stateful component.
class StateTransactionCapabilities {
  /// No snapshot or restore support.
  static const unsupported = StateTransactionCapabilities._(
    transport: StateTransactionTransport.unsupported,
    supportsSnapshot: false,
    supportsRestore: false,
    snapshotQuiescence: StateTransactionQuiescence.none,
    restoreQuiescence: StateTransactionQuiescence.none,
    completionMode: StateTransactionCompletionMode.immediate,
    atomicRestore: false,
  );

  /// Immediate software snapshot and atomic restore support.
  static const software = StateTransactionCapabilities._(
    transport: StateTransactionTransport.software,
    supportsSnapshot: true,
    supportsRestore: true,
    snapshotQuiescence: StateTransactionQuiescence.none,
    restoreQuiescence: StateTransactionQuiescence.none,
    completionMode: StateTransactionCompletionMode.immediate,
    atomicRestore: true,
  );

  /// Atomic restore through an acknowledged, externally quiesced protocol.
  static const quiescedHardwareRestore = StateTransactionCapabilities._(
    transport: StateTransactionTransport.hardware,
    supportsSnapshot: false,
    supportsRestore: true,
    snapshotQuiescence: StateTransactionQuiescence.none,
    restoreQuiescence: StateTransactionQuiescence.required,
    completionMode: StateTransactionCompletionMode.acknowledged,
    atomicRestore: true,
  );

  /// Transport used for transactions.
  final StateTransactionTransport transport;

  /// Whether a logical state image can be captured.
  final bool supportsSnapshot;

  /// Whether a logical state image can replace current state.
  final bool supportsRestore;

  /// Quiescence required before snapshot acceptance.
  final StateTransactionQuiescence snapshotQuiescence;

  /// Quiescence required before restore acceptance.
  final StateTransactionQuiescence restoreQuiescence;

  /// How an accepted request reports completion.
  final StateTransactionCompletionMode completionMode;

  /// Whether restore becomes visible as one indivisible state replacement.
  final bool atomicRestore;

  /// Creates a validated state-transaction capability declaration.
  factory StateTransactionCapabilities({
    required StateTransactionTransport transport,
    required bool supportsSnapshot,
    required bool supportsRestore,
    required StateTransactionQuiescence snapshotQuiescence,
    required StateTransactionQuiescence restoreQuiescence,
    required StateTransactionCompletionMode completionMode,
    required bool atomicRestore,
  }) {
    if (transport == StateTransactionTransport.unsupported &&
        (supportsSnapshot || supportsRestore)) {
      throw ArgumentError(
          'An unsupported transport cannot advertise state transactions.');
    }
    if (!supportsSnapshot &&
        snapshotQuiescence != StateTransactionQuiescence.none) {
      throw ArgumentError(
          'Snapshot quiescence requires snapshot transaction support.');
    }
    if (!supportsRestore &&
        (restoreQuiescence != StateTransactionQuiescence.none ||
            atomicRestore)) {
      throw ArgumentError(
          'Restore properties require restore transaction support.');
    }
    if (transport == StateTransactionTransport.software &&
        completionMode != StateTransactionCompletionMode.immediate) {
      throw ArgumentError('Software state transactions complete immediately.');
    }
    return StateTransactionCapabilities._(
      transport: transport,
      supportsSnapshot: supportsSnapshot,
      supportsRestore: supportsRestore,
      snapshotQuiescence: snapshotQuiescence,
      restoreQuiescence: restoreQuiescence,
      completionMode: completionMode,
      atomicRestore: atomicRestore,
    );
  }

  const StateTransactionCapabilities._({
    required this.transport,
    required this.supportsSnapshot,
    required this.supportsRestore,
    required this.snapshotQuiescence,
    required this.restoreQuiescence,
    required this.completionMode,
    required this.atomicRestore,
  });

  /// Whether [operation] requires the caller to establish quiescence.
  bool requiresQuiescence(StateTransactionOperation operation) =>
      switch (operation) {
        StateTransactionOperation.snapshot =>
          snapshotQuiescence == StateTransactionQuiescence.required,
        StateTransactionOperation.restore =>
          restoreQuiescence == StateTransactionQuiescence.required,
      };

  /// Rejects an unsupported or insufficiently quiesced request.
  void validateRequest(
    StateTransactionOperation operation, {
    required bool quiescent,
  }) {
    final supported = switch (operation) {
      StateTransactionOperation.snapshot => supportsSnapshot,
      StateTransactionOperation.restore => supportsRestore,
    };
    if (!supported) {
      throw UnsupportedError(
          '${operation.name} state transactions are not supported.');
    }
    if (requiresQuiescence(operation) && !quiescent) {
      throw StateError(
          '${operation.name} requires the component to be quiescent.');
    }
  }
}

/// Provides static snapshot and restore capabilities for a component.
abstract interface class StateTransactionCapabilityProvider {
  /// Snapshot and restore behavior exposed by this component.
  StateTransactionCapabilities get stateTransactionCapabilities;
}

/// Operation requested from a state transaction endpoint.
enum StateTransactionOperation {
  /// Capture a logical image without changing state.
  snapshot,

  /// Atomically replace state from a logical image.
  restore
}

/// One correlated snapshot or restore request.
class StateTransactionRequest<ImageType extends Object> {
  /// Caller-provided identifier returned by the completion.
  final int transactionId;

  /// Requested operation.
  final StateTransactionOperation operation;

  /// Restore image, or `null` for a snapshot request.
  final ImageType? image;

  /// Creates a snapshot request.
  StateTransactionRequest.snapshot({required this.transactionId})
      : operation = StateTransactionOperation.snapshot,
        image = null {
    _validateTransactionId();
  }

  /// Creates a restore request.
  StateTransactionRequest.restore({
    required this.transactionId,
    required ImageType this.image,
  }) : operation = StateTransactionOperation.restore {
    _validateTransactionId();
  }

  void _validateTransactionId() {
    if (transactionId < 0) {
      throw ArgumentError.value(
          transactionId, 'transactionId', 'Must not be negative.');
    }
  }
}

/// Completion of one accepted state transaction.
class StateTransactionCompletion<ImageType extends Object> {
  /// Identifier copied from the accepted request.
  final int transactionId;

  /// Completed operation.
  final StateTransactionOperation operation;

  /// Captured image for a snapshot, or `null` after restore.
  final ImageType? image;

  /// Creates a completed snapshot carrying its captured [image].
  const StateTransactionCompletion.snapshot({
    required this.transactionId,
    required ImageType this.image,
  }) : operation = StateTransactionOperation.snapshot;

  /// Creates a completed restore acknowledgment.
  const StateTransactionCompletion.restore({
    required this.transactionId,
  })  : operation = StateTransactionOperation.restore,
        image = null;
}

/// Common transaction endpoint for a logical state image.
abstract interface class StateTransactionEndpoint<ImageType extends Object> {
  /// Static behavior of this endpoint.
  StateTransactionCapabilities get capabilities;

  /// Accepts a request and returns its completion.
  ///
  /// [quiescent] states that the caller has stopped and drained normal
  /// activity. Unsupported or non-quiescent requests throw before changing
  /// state.
  StateTransactionCompletion<ImageType> transact(
    StateTransactionRequest<ImageType> request, {
    bool quiescent = false,
  });
}

/// Operation for one acknowledged logical-image chunk.
enum StateTransactionChunkOperation {
  /// Request the next chunk of a snapshot.
  snapshot,

  /// Supply the next chunk of a restore.
  restore,
}

/// One correlated request in an acknowledged chunk transfer.
class StateTransactionChunkRequest<ChunkType extends Object> {
  /// Transaction identifier shared by every chunk in the transfer.
  final int transactionId;

  /// Operation for this chunk.
  final StateTransactionChunkOperation operation;

  /// Zero-based chunk index.
  final int index;

  /// Total number of chunks in the transfer.
  final int count;

  /// Restore payload, or `null` when requesting a snapshot chunk.
  final ChunkType? chunk;

  /// Creates a validated chunk request.
  StateTransactionChunkRequest({
    required this.transactionId,
    required this.operation,
    required this.index,
    required this.count,
    this.chunk,
  }) {
    if (transactionId < 0) {
      throw ArgumentError.value(
          transactionId, 'transactionId', 'Must not be negative.');
    }
    if (count <= 0 || index < 0 || index >= count) {
      throw ArgumentError('Chunk index and count are invalid.');
    }
    if (operation == StateTransactionChunkOperation.snapshot && chunk != null) {
      throw ArgumentError('Snapshot chunk requests must not carry a payload.');
    }
    if (operation == StateTransactionChunkOperation.restore && chunk == null) {
      throw ArgumentError('Restore chunk requests must carry a payload.');
    }
  }
}

/// Completion acknowledgement for one chunk transfer request.
class StateTransactionChunkCompletion<ChunkType extends Object> {
  /// Transaction identifier copied from the request.
  final int transactionId;

  /// Completed operation.
  final StateTransactionChunkOperation operation;

  /// Zero-based completed chunk index.
  final int index;

  /// Number of chunks in the complete transfer.
  final int count;

  /// Whether this was the final chunk in the transfer.
  final bool complete;

  /// Snapshot payload, or `null` for restore acknowledgements.
  final ChunkType? chunk;

  /// Creates a validated chunk completion.
  StateTransactionChunkCompletion({
    required this.transactionId,
    required this.operation,
    required this.index,
    required this.count,
    required this.complete,
    this.chunk,
  }) {
    if (transactionId < 0 || count <= 0 || index < 0 || index >= count) {
      throw ArgumentError('Chunk completion identifiers are invalid.');
    }
    if (operation == StateTransactionChunkOperation.restore && chunk != null) {
      throw ArgumentError('Restore completions must not carry a payload.');
    }
    if (operation == StateTransactionChunkOperation.snapshot && chunk == null) {
      throw ArgumentError('Snapshot completions must carry a payload.');
    }
  }
}

/// Fixed-width identity and payload contract for a hardware endpoint.
class StateTransactionHardwareEndpointContract {
  /// Creates a validated hardware endpoint geometry.
  StateTransactionHardwareEndpointContract({
    required this.transactionIdWidth,
    required this.manifestWidth,
    required this.chunkIndexWidth,
    required this.chunkCountWidth,
    required this.payloadWidth,
  }) {
    if (transactionIdWidth <= 0 ||
        manifestWidth <= 0 ||
        chunkIndexWidth <= 0 ||
        chunkCountWidth <= 0 ||
        payloadWidth <= 0) {
      throw ArgumentError('Hardware endpoint widths must be positive.');
    }
  }

  /// Width of the transaction identifier.
  final int transactionIdWidth;

  /// Width of the state schema/geometry identity.
  final int manifestWidth;

  /// Width of a zero-based chunk index.
  final int chunkIndexWidth;

  /// Width of the total chunk count.
  final int chunkCountWidth;

  /// Width of one transfer payload.
  final int payloadWidth;
}

/// One ready/valid request presented to a hardware state endpoint.
class StateTransactionHardwareRequest {
  /// Creates a hardware request with explicit manifest and chunk identity.
  StateTransactionHardwareRequest({
    required this.transactionId,
    required this.manifest,
    required this.operation,
    required this.index,
    required this.count,
    required this.payload,
    required this.quiescent,
  }) {
    if (transactionId < 0 ||
        manifest < 0 ||
        index < 0 ||
        count <= 0 ||
        index >= count ||
        payload < 0) {
      throw ArgumentError('Hardware transaction request fields are invalid.');
    }
  }

  /// Correlates request and completion.
  final int transactionId;

  /// Schema and geometry identity supplied by the producer.
  final int manifest;

  /// Requested transfer operation.
  final StateTransactionChunkOperation operation;

  /// Zero-based chunk index.
  final int index;

  /// Total chunks in this transfer.
  final int count;

  /// Packed chunk payload, or zero for a snapshot request.
  final int payload;

  /// Whether the source has established quiescence.
  final bool quiescent;
}

/// Acknowledged response from a hardware state endpoint.
class StateTransactionHardwareCompletion {
  /// Creates a hardware completion.
  const StateTransactionHardwareCompletion({
    required this.transactionId,
    required this.accepted,
    required this.complete,
    required this.error,
    required this.payload,
  }) : assert(
          !complete || accepted,
          'A hardware transaction cannot complete before acceptance.',
        );

  /// Correlates the response with the request.
  final int transactionId;

  /// Whether the endpoint accepted the request.
  final bool accepted;

  /// Whether the complete transaction has atomically committed.
  final bool complete;

  /// Whether the endpoint rejected the request.
  final bool error;

  /// Packed snapshot payload, or zero for restore acknowledgements.
  final int payload;
}

/// A hardware endpoint that acknowledges bounded state-image chunks.
abstract interface class StateTransactionChunkEndpoint<
    ChunkType extends Object> {
  /// Static behavior of this endpoint.
  StateTransactionCapabilities get capabilities;

  /// Accepts one chunk request and returns its acknowledgement.
  StateTransactionChunkCompletion<ChunkType> transactChunk(
    StateTransactionChunkRequest<ChunkType> request, {
    bool quiescent = false,
  });
}

/// A component exposing standardized snapshot and restore transactions.
abstract interface class StateTransactionProvider<ImageType extends Object> {
  /// Snapshot and restore endpoint.
  StateTransactionEndpoint<ImageType> get stateTransactions;
}

/// Immediate software endpoint for models exposing [image] and [load].
mixin SoftwareStateTransactionEndpoint<ImageType extends Object>
    implements
        StateTransactionEndpoint<ImageType>,
        StateTransactionProvider<ImageType> {
  /// Static software transaction behavior.
  @override
  StateTransactionCapabilities get capabilities =>
      StateTransactionCapabilities.software;

  /// Current immutable logical image.
  ImageType get image;

  /// Validates and atomically replaces current logical state.
  void load(covariant ImageType image);

  /// This model's software transaction endpoint.
  @override
  StateTransactionEndpoint<ImageType> get stateTransactions => this;

  @override
  StateTransactionCompletion<ImageType> transact(
    StateTransactionRequest<ImageType> request, {
    bool quiescent = false,
  }) {
    capabilities.validateRequest(
      request.operation,
      quiescent: quiescent,
    );
    switch (request.operation) {
      case StateTransactionOperation.snapshot:
        return StateTransactionCompletion.snapshot(
          transactionId: request.transactionId,
          image: image,
        );
      case StateTransactionOperation.restore:
        load(request.image!);
        return StateTransactionCompletion.restore(
          transactionId: request.transactionId,
        );
    }
  }
}

/// Adapts snapshot and restore callbacks to the software transaction contract.
///
/// The optional capability callback is evaluated for each request so models
/// with optional snapshot support can report their current capabilities.
class SoftwareStateTransactionAdapter<ImageType extends Object>
    with SoftwareStateTransactionEndpoint<ImageType> {
  final ImageType Function() _snapshot;
  // The mixin's covariant load checks the image before invoking this callback.
  // ignore: unsafe_variance
  final void Function(ImageType) _restore;
  final StateTransactionCapabilities Function()? _capabilities;

  /// Creates an endpoint backed by [snapshot] and [restore].
  SoftwareStateTransactionAdapter({
    required ImageType Function() snapshot,
    required void Function(ImageType) restore,
    StateTransactionCapabilities Function()? capabilities,
  })  : _snapshot = snapshot,
        _restore = restore,
        _capabilities = capabilities;

  @override
  StateTransactionCapabilities get capabilities =>
      _capabilities?.call() ?? StateTransactionCapabilities.software;

  @override
  ImageType get image => _snapshot();

  @override
  void load(ImageType image) => _restore(image);
}
