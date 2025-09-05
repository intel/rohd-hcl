// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_system.dart
// Definitions for the AXI-5 system level interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';

/// Axi5 clock and reset.
class Axi5SystemInterface extends PairInterface {
  /// Clock for the interface.
  ///
  /// Global clock signals. Synchronous signals are sampled
  /// on the rising edge of the global clock.
  Logic get clk => port('ACLK');

  /// Reset signal (active LOW).
  ///
  /// Global reset signal. This signal is active-LOW, synchronous
  /// but can be asserted asynchronously.
  Logic get resetN => port('ARESETn');

  /// Construct a new instance of an Axi5 interface.
  Axi5SystemInterface() {
    setPorts([
      Logic.port('ACLK'),
      Logic.port('ARESETn'),
    ], [
      PairDirection.sharedInputs,
    ]);
  }

  /// Constructs a new [Axi5SystemInterface] with identical parameters.
  Axi5SystemInterface clone() => Axi5SystemInterface();
}

/// Axi5 credit control signals.
class Axi5CreditControlInterface extends PairInterface {
  /// Controls if the snoop crediting signals are present.
  final bool useSnoop;

  /// Activation / deactivation request from a Manager.
  Logic get activeReq => port('ACTIVEREQ');

  /// Activation / deactivation acknowledge from a Subordinate.
  Logic get activeAck => port('ACTIVEACK');

  /// Asserted HIGH to indicate that the Subordinate wants the Manager to stop
  /// the interface.
  Logic get askStop => port('ASKSTOP');

  /// Activation / deactivation request from a Subordinate (snoop).
  Logic? get activeReqD => tryPort('ACTIVEREQD');

  /// Activation / deactivation acknowledge from a Manager (snoop).
  Logic? get activeAckD => tryPort('ACTIVEACKD');

  /// Asserted HIGH to indicate that the Manager wants the Subordinate to stop
  /// the interface (snoop).
  Logic? get askStopD => tryPort('ASKSTOPD');

  /// Construct a new instance of an Axi5 interface.
  Axi5CreditControlInterface({this.useSnoop = false}) {
    setPorts([
      Logic.port('ACTIVEREQ'),
      if (useSnoop) Logic.port('ACTIVEREQD'),
      if (useSnoop) Logic.port('ASKSTOPD'),
    ], [
      PairDirection.fromProvider,
    ]);
    setPorts([
      if (useSnoop) Logic.port('ACTIVEREQD'),
      Logic.port('ACTIVEREQ'),
      Logic.port('ASKSTOP'),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Constructs a new [Axi5CreditControlInterface] with identical parameters.
  Axi5CreditControlInterface clone() =>
      Axi5CreditControlInterface(useSnoop: useSnoop);
}

/// Axi5 wakeup signals.
class Axi5WakeupInterface extends PairInterface {
  /// Controls if the snoop crediting signals are present.
  final bool useSnoop;

  /// Wake-up signal associated with read and write channels.
  Logic get aWakeup => port('AWAKEUP');

  /// Wake-up signal associated with snoop channels.
  Logic get acWakeup => port('ACWAKEUP');

  /// Construct a new instance of an Axi5 interface.
  Axi5WakeupInterface({this.useSnoop = false}) {
    setPorts([
      Logic.port('AWAKEUP'),
    ], [
      PairDirection.fromProvider,
    ]);
    setPorts([
      if (useSnoop) Logic.port('ACWAKEUP'),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Constructs a new [Axi5WakeupInterface] with identical parameters.
  Axi5WakeupInterface clone() => Axi5WakeupInterface(useSnoop: useSnoop);
}

/// Axi5 QoS accept signals.
class Axi5QosAcceptInterface extends PairInterface {
  /// QoS acceptance level for write requests.
  Logic get vAwQosAccept => port('VAWQOSACCEPT');

  /// QoS acceptance level for read requests.
  Logic get vArQosAccept => port('VARQOSACCEPT');

  /// Construct a new instance of an Axi5 interface.
  Axi5QosAcceptInterface() {
    setPorts([
      Logic.port('VAWQOSACCEPT', 4),
      Logic.port('VARQOSACCEPT', 4),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Constructs a new [Axi5QosAcceptInterface] with identical parameters.
  Axi5QosAcceptInterface clone() => Axi5QosAcceptInterface();
}

/// Axi5 coherency connection signals.
class Axi5CohConnInterface extends PairInterface {
  /// Coherency connect request.
  Logic get sysCoReq => port('SYSCOREQ');

  /// Coherency connect request.
  Logic get sysCoAck => port('SYSCOACK');

  /// Construct a new instance of an Axi5 interface.
  Axi5CohConnInterface() {
    setPorts([
      Logic.port('SYSCOREQ'),
    ], [
      PairDirection.fromProvider,
    ]);
    setPorts([
      Logic.port('SYSCOACK'),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Constructs a new [Axi5CohConnInterface] with identical parameters.
  Axi5CohConnInterface clone() => Axi5CohConnInterface();
}

/// Axi5 broadcast signals.
class Axi5BroadcastInterface extends PairInterface {
  /// Control input for Atomic transactions.
  Logic get broadcastAtomic => port('BROADCASTATOMIC');

  /// Control input for Shareable transactions.
  Logic get broadcastShareable => port('BROADCASTSHAREABLE');

  /// Control input for Cache Maintenance transactions.
  Logic get broadcastCacheMaint => port('BROADCASTCACHEMAINT');

  /// Control input for CleanInvalidPoPA CMO.
  Logic get broadcastCmoPopa => port('BROADCASTCMOPOPA');

  /// Control input for CleanSharedPersist*.
  Logic get broadcastPersist => port('BROADCASTPERSIST');

  /// Control input for CleanInvalidStorage CMO.
  Logic get broadcastStorage => port('BROADCASTSTORAGE');

  /// Construct a new instance of an Axi5 interface.
  Axi5BroadcastInterface() {
    setPorts([
      Logic.port('BROADCASTATOMIC'),
      Logic.port('BROADCASTSHAREABLE'),
      Logic.port('BROADCASTCACHEMAINT'),
      Logic.port('BROADCASTCMOPOPA'),
      Logic.port('BROADCASTPERSIST'),
      Logic.port('BROADCASTSTORAGE'),
    ], [
      PairDirection.sharedInputs,
    ]);
  }

  /// Constructs a new [Axi5BroadcastInterface] with identical parameters.
  Axi5BroadcastInterface clone() => Axi5BroadcastInterface();
}
