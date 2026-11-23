// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// policy_mux_core.dart
// Protocol-neutral action-driven arbitration mux.
//
// 2026 October 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/arbitration_policy.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/policy_arbiter.dart';
import 'package:rohd_hcl/src/flow_control/control/hardware_core_functor.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Configured arbitration and action contract for [PolicyMuxCoreFunctor].
/// {@category Flow Control}
class PolicyMuxCoreCapabilities implements HardwareCoreCapabilities {
  /// Number of request and payload inputs.
  final int inputCount;

  /// Stable arbitration policy identity.
  final String policyIdentity;

  /// Event that advances arbitration state.
  final ArbitrationAdvanceMode advanceMode;

  /// Ownership-retention behavior.
  final ArbitrationRetentionPolicy retentionPolicy;

  /// Width of each runtime policy input.
  final List<int> policyInputWidths;

  /// Creates policy-mux capability metadata.
  PolicyMuxCoreCapabilities({
    required this.inputCount,
    required this.policyIdentity,
    required this.advanceMode,
    required this.retentionPolicy,
    required List<int> policyInputWidths,
  }) : policyInputWidths = List.unmodifiable(policyInputWidths);

  /// Whether construction requires an explicit completion action.
  bool get requiresCompletion =>
      advanceMode == ArbitrationAdvanceMode.onCompletion;

  /// Whether construction requires explicit capture and release actions.
  bool get requiresOwnerControls =>
      retentionPolicy == ArbitrationRetentionPolicy.lockUntilRelease;

  @override
  String get configurationIdentity => 'N${inputCount}_'
      'P${policyIdentity}_A${advanceMode.name}_R${retentionPolicy.name}_'
      'I${policyInputWidths.isEmpty ? 'none' : policyInputWidths.join('_')}';
}

/// Wrapper-owned signals used to construct an action-driven policy mux.
/// {@category Flow Control}
class PolicyMuxCoreRequest<LogicType extends Logic> {
  /// Core clock.
  final Logic clk;

  /// Synchronous core reset.
  final Logic reset;

  /// One typed payload per arbitration input.
  final List<LogicType> payloads;

  /// One live request bit per arbitration input.
  final List<Logic> requests;

  /// Explicit action permitting the selected request to be serviced.
  final Logic service;

  /// Runtime inputs interpreted by the configured arbitration policy.
  final List<Logic> policyInputs;

  /// Optional owner-completion action.
  final Logic? complete;

  /// Optional owner-capture action.
  final Logic? captureOwner;

  /// Optional owner-release action.
  final Logic? releaseOwner;

  /// Creates a typed policy-mux construction request.
  const PolicyMuxCoreRequest({
    required this.clk,
    required this.reset,
    required this.payloads,
    required this.requests,
    required this.service,
    this.policyInputs = const [],
    this.complete,
    this.captureOwner,
    this.releaseOwner,
  });
}

/// Protocol-neutral policy mux driven by an explicit service action.
/// {@category Flow Control}
class PolicyMuxCore<LogicType extends Logic> extends Module {
  /// Configured action and arbitration contract.
  final PolicyMuxCoreCapabilities capabilities;

  /// One-hot candidate proposed by the policy.
  Logic get candidate => output('candidate');

  /// One-hot selected owner after retention.
  Logic get selection => output('selection');

  /// Active one-hot grant masked by live requests.
  Logic get grant => output('grant');

  /// Payload selected by [selection].
  late final LogicType selectedData;

  /// High while an active grant presents [selectedData].
  Logic get valid => output('valid');

  /// High when the `service` action accepts an active grant.
  Logic get accepted => output('accepted');

  /// One-hot accepted grant.
  Logic get acceptedGrant => output('acceptedGrant');

  /// High when the configured policy advancement event occurs.
  Logic get completed => output('completed');

  /// One-hot grant used to advance policy state.
  Logic get completedGrant => output('completedGrant');

  /// High while ownership is retained.
  Logic get locked => output('locked');

  PolicyMuxCore._({
    required PolicyMuxCoreRequest<LogicType> request,
    required ArbitrationPolicy policy,
    required this.capabilities,
    required String definitionName,
    required String name,
  }) : super(definitionName: definitionName, name: name) {
    final localClk = addInput('clk', request.clk);
    final localReset = addInput('reset', request.reset);
    final localPayloads = [
      for (var index = 0; index < request.payloads.length; index++)
        addTypedInput(
          'payload_$index',
          request.payloads[index],
        ),
    ];
    final localRequests = [
      for (var index = 0; index < request.requests.length; index++)
        addInput('request_$index', request.requests[index]),
    ];
    final localService = addInput('service', request.service);
    final localPolicyInputs = [
      for (var index = 0; index < request.policyInputs.length; index++)
        addInput(
          'policyInput_$index',
          request.policyInputs[index],
          width: request.policyInputs[index].width,
        ),
    ];
    final localComplete = request.complete == null
        ? null
        : addInput('complete', request.complete!);
    final localCapture = request.captureOwner == null
        ? null
        : addInput('captureOwner', request.captureOwner!);
    final localRelease = request.releaseOwner == null
        ? null
        : addInput('releaseOwner', request.releaseOwner!);

    addOutput('candidate', width: capabilities.inputCount);
    addOutput('selection', width: capabilities.inputCount);
    addOutput('grant', width: capabilities.inputCount);
    selectedData =
        addTypedPayloadOutput(this, 'selectedData', localPayloads.first);
    addOutput('valid');
    addOutput('accepted');
    addOutput('acceptedGrant', width: capabilities.inputCount);
    addOutput('completed');
    addOutput('completedGrant', width: capabilities.inputCount);
    addOutput('locked');

    final arbiter = PolicyArbiter(
      localRequests,
      clk: localClk,
      reset: localReset,
      policy: policy,
      advanceMode: capabilities.advanceMode,
      retentionPolicy: capabilities.retentionPolicy,
      accepted: localService,
      complete: localComplete,
      captureOwner: localCapture,
      releaseOwner: localRelease,
      policyInputs: localPolicyInputs,
      name: '${name}_arbiter',
    );
    candidate <= arbiter.candidate;
    selection <= arbiter.selection;
    grant <= arbiter.grants.rconcat();
    acceptedGrant <= arbiter.acceptedGrant;
    completedGrant <= arbiter.completedGrant;
    locked <= arbiter.locked;
    valid <= grant.or();
    accepted <= arbiter.acceptedGrant.or();
    completed <= arbiter.completedGrant.or();

    var selected = localPayloads.last;
    for (var index = capabilities.inputCount - 2; index >= 0; index--) {
      selected = mux<LogicType>(
          selection[index], localPayloads[index], selected,
          outputGenerator: ({name}) =>
              localPayloads.first.cloneTyped(name: name));
    }
    selectedData <= selected;
  }
}

/// Constructed policy mux and its output-only binding.
/// {@category Flow Control}
class PolicyMuxCoreBinding<LogicType extends Logic>
    implements HardwareCoreBinding {
  @override
  final PolicyMuxCore<LogicType> module;

  /// Capabilities validated for this construction.
  final PolicyMuxCoreCapabilities capabilities;

  /// Creates a policy-mux binding.
  const PolicyMuxCoreBinding(this.module, this.capabilities);

  /// One-hot policy candidate.
  Logic get candidate => module.candidate;

  /// One-hot retained or current owner.
  Logic get selection => module.selection;

  /// Active one-hot grant.
  Logic get grant => module.grant;

  /// Selected typed payload.
  LogicType get selectedData => module.selectedData;

  /// High while an active request is selected.
  Logic get valid => module.valid;

  /// High when the service action accepts a request.
  Logic get accepted => module.accepted;

  /// One-hot accepted grant.
  Logic get acceptedGrant => module.acceptedGrant;

  /// High when policy state advances.
  Logic get completed => module.completed;

  /// One-hot grant used to advance policy state.
  Logic get completedGrant => module.completedGrant;

  /// High while an owner is retained.
  Logic get locked => module.locked;
}

/// Constructs protocol-neutral policy mux cores.
/// {@category Flow Control}
class PolicyMuxCoreFunctor<LogicType extends Logic> extends HardwareCoreFunctor<
    PolicyMuxCoreRequest<LogicType>, PolicyMuxCoreBinding<LogicType>> {
  /// Selection policy composed by the core.
  final ArbitrationPolicy policy;

  @override
  final PolicyMuxCoreCapabilities capabilities;

  /// Creates a configured policy-mux construction functor.
  PolicyMuxCoreFunctor({
    required int inputCount,
    required this.policy,
    ArbitrationAdvanceMode advanceMode = ArbitrationAdvanceMode.onAccepted,
    ArbitrationRetentionPolicy retentionPolicy =
        ArbitrationRetentionPolicy.none,
    List<int> policyInputWidths = const [],
  }) : capabilities = PolicyMuxCoreCapabilities(
          inputCount: inputCount,
          policyIdentity: policy.identity,
          advanceMode: advanceMode,
          retentionPolicy: retentionPolicy,
          policyInputWidths: policyInputWidths,
        ) {
    if (inputCount < 1) {
      throw ArgumentError.value(
        inputCount,
        'inputCount',
        'Must be at least one.',
      );
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(policy.identity)) {
      throw ArgumentError.value(
        policy.identity,
        'policy.identity',
        'Must be a valid SystemVerilog identifier fragment.',
      );
    }
    if (policyInputWidths.any((width) => width < 1)) {
      throw ArgumentError.value(
        policyInputWidths,
        'policyInputWidths',
        'Every policy input must have positive width.',
      );
    }
  }

  @override
  String get identity => 'policy_mux_core';

  @override
  PolicyMuxCoreBinding<LogicType> construct(
    PolicyMuxCoreRequest<LogicType> request, {
    required String name,
  }) {
    if (request.payloads.length != capabilities.inputCount ||
        request.requests.length != capabilities.inputCount) {
      throw ArgumentError(
        'The request must provide exactly ${capabilities.inputCount} '
        'payloads and request bits.',
      );
    }
    if (!compatiblePayloadSet(request.payloads, ignoreConstantNames: true)) {
      throw ArgumentError.value(
        request.payloads,
        'payloads',
        'Payloads must have compatible declared shapes and widths.',
      );
    }
    if (request.requests.any((request) => request.width != 1)) {
      throw ArgumentError.value(
        request.requests,
        'requests',
        'Every request must be one bit.',
      );
    }
    for (final control in {
      'clk': request.clk,
      'reset': request.reset,
      'service': request.service,
      'complete': request.complete,
      'captureOwner': request.captureOwner,
      'releaseOwner': request.releaseOwner,
    }.entries) {
      if (control.value != null && control.value!.width != 1) {
        throw ArgumentError.value(
          control.value,
          control.key,
          'Policy-mux controls must be one bit.',
        );
      }
    }
    if (request.policyInputs.map((input) => input.width).toList().join(',') !=
        capabilities.policyInputWidths.join(',')) {
      throw ArgumentError.value(
        request.policyInputs,
        'policyInputs',
        'Widths must match the configured policy-input capabilities.',
      );
    }
    if (capabilities.requiresCompletion != (request.complete != null)) {
      throw ArgumentError(
        capabilities.requiresCompletion
            ? 'The configured advance mode requires a completion action.'
            : 'A completion action is incompatible with the advance mode.',
      );
    }
    final hasCapture = request.captureOwner != null;
    final hasRelease = request.releaseOwner != null;
    if (hasCapture != hasRelease ||
        capabilities.requiresOwnerControls != hasCapture) {
      throw ArgumentError(
        capabilities.requiresOwnerControls
            ? 'The retention policy requires capture and release actions.'
            : 'Capture and release actions are incompatible with the '
                'retention policy.',
      );
    }

    final module = PolicyMuxCore<LogicType>._(
      request: request,
      policy: policy,
      capabilities: capabilities,
      definitionName: 'PolicyMuxCore_${definitionIdentity}_'
          '${capabilities.configurationIdentity}_'
          'W${request.payloads.first.width}_'
          '${payloadShapesIdentity(request.payloads)}',
      name: name,
    );
    return PolicyMuxCoreBinding<LogicType>(module, capabilities);
  }
}
