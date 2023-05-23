// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb.dart
// Definitions for the APB interface.
//
// 2023 May 19
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// A grouping of signals on the [Apb] interface based on direction.
enum ApbDirection {
  /// Miscellaneous system-level signals, common inputs to both sides.
  misc,

  /// Signals driven by the requester.
  fromRequester,

  /// Signals driven by the completer.
  fromCompleter
}

/// A standard APB interface.
class Apb extends Interface<ApbDirection> {
  /// The width of address port [addr].
  ///
  /// Equvalent to the `ADDR_WIDTH` parameter in the APB specification.
  ///
  /// Must be less than or equal to 32 bits.
  final int addrWidth;

  /// The width of data ports [wData] and [rData];
  ///
  /// Equvalent to the `DATA_WIDTH` parameter in the APB specification.
  ///
  /// Can be 8 bits, 16 bits, or 32 bits wide.
  final int dataWidth;

  /// The width of user request port [aUser].
  ///
  /// Equvalent to the `USER_REQ_WIDTH` parameter in the APB specification.
  ///
  /// Recommended to have a maximum width of 128 bits. If set to 0, then ports
  /// which use this width will not be created. Recommended to set to 0.
  final int userReqWidth;

  /// The width of user-defined data ports [wUser] and [rUser].
  ///
  /// Equvalent to the `USER_DATA_WIDTH` parameter in the APB specification.
  ///
  /// Recommended to have a maximum width of [dataWidth]/2. If set to 0, then
  /// ports which use this width will not be created. Recommended to set to 0.
  final int userDataWidth;

  /// The width of user response port [bUser].
  ///
  /// Equvalent to the `USER_RESP_WIDTH` parameter in the APB specification.
  ///
  /// Recommended to have a maximum width of 16. If set to 0, then ports which
  /// use this width will not be created. Recommended to set to 0.
  final int userRespWidth;

  /// If `true`, generates the [slvErr] port.
  final bool includeSlvErr;

  /// Clock for the interface.
  ///
  /// All APB signals are timed against the rising edge.
  Logic get clk => port('PCLK');

  /// Reset signal (active LOW).
  ///
  /// Normally connected directly to the system bus reset signal.
  Logic get resetN => port('PRESETn');

  /// Address bus.
  ///
  /// Width is equal to [addrWidth].
  Logic get addr => port('PADDR');

  /// Protection type.
  ///
  /// Indicates the normal, privileged, or secure protection level of the
  /// transaction and whether the transaction is a data access or an instruction
  /// access.
  Logic get prot => port('PPROT');

  /// Extension to protection type.
  Logic get nse => port('PNSE');

  /// Select.
  ///
  /// The Requester generates a select signal for each Completer. Select
  /// indicates that the Completer is selected and that a data transfer is
  /// required.
  Logic get selX => port('PSELx');

  /// Enable.
  ///
  /// Indicates the second and subsequent cycles of an APB transfer.
  Logic get enable => port('PENABLE');

  /// Direction.
  ///
  /// Indicates an APB write access when HIGH and an APB read access when LOW.
  Logic get write => port('PWRITE');

  /// Write data.
  ///
  /// The write data bus is driven by the APB bridge Requester during
  /// write cycles when [write] is HIGH.
  ///
  /// Width is equal to [dataWidth].
  Logic get wData => port('PWDATA');

  /// Write strobe.
  ///
  /// Indicates which byte lanes to update during a write transfer. There is one
  /// write strobe for each 8 bits of the write data bus. Width is equal to
  /// [dataWidth] divided by 8.
  ///
  /// The `n`th bit of [strb] corresponds to range `[(8n + 7):(8n)]` of [wData].
  ///
  /// Must not be active during a read transfer.
  Logic get strb => port('PSTRB');

  /// Ready.
  ///
  /// Used to extend an APB transfer by the Completer.
  Logic get ready => port('PREADY');

  /// Read data.
  ///
  /// Driven by the selected Completer during read cycles when [write] is LOW.
  ///
  /// Width is equal to [dataWidth].
  Logic get rData => port('PRDATA');

  /// Transfer error.
  ///
  /// An optional signal that can be asserted HIGH by the Completer to indicate
  /// an error condition on an APB transfer.
  ///
  /// Only generated if [includeSlvErr] is `true`.
  Logic? get slvErr => includeSlvErr ? port('PSLVERR') : null;

  /// Wake-up.
  ///
  /// Indicates any activity associated with an APB interface.
  Logic get wakeup => port('PWAKEUP');

  /// User request attribute.
  ///
  /// Width equal to [userReqWidth].  Only exists if [userReqWidth] > 0.
  Logic? get aUser => userReqWidth != 0 ? port('PAUSER') : null;

  /// User write data attribute.
  ///
  /// Width equal to [userDataWidth].  Only exists if [userDataWidth] > 0.
  Logic? get wUser => userDataWidth != 0 ? port('PWUSER') : null;

  /// User read data attribute.
  ///
  /// Width equal to [userDataWidth].  Only exists if [userDataWidth] > 0.
  Logic? get rUser => userDataWidth != 0 ? port('PRUSER') : null;

  /// User response attribute.
  ///
  /// Width equal to [userRespWidth].  Only exists if [userRespWidth] > 0.
  Logic? get bUser => userRespWidth != 0 ? port('PBUSER') : null;

  /// Construct a new instance of an APB interface.
  Apb({
    this.addrWidth = 32,
    this.dataWidth = 32,
    this.userReqWidth = 0,
    this.userDataWidth = 0,
    this.userRespWidth = 0,
    this.includeSlvErr = false,
  }) {
    _validateParameters();

    setPorts([
      Port('PCLK'),
      Port('PRESETn'),
    ], [
      ApbDirection.misc
    ]);

    setPorts([
      Port('PADDR', addrWidth),
      Port('PPROT', 3),
      Port('PNSE'),
      Port('PSELx'),
      Port('PENABLE'),
      Port('PWRITE'),
      Port('PWDATA', dataWidth),
      Port('PSTRB', dataWidth ~/ 8),
      if (userReqWidth != 0) Port('PAUSER', userReqWidth),
      if (userDataWidth != 0) Port('PWUSER', userDataWidth),
    ], [
      ApbDirection.fromRequester
    ]);

    setPorts([
      Port('PREADY'),
      Port('PRDATA', dataWidth),
      Port('PSLVERR'),
      Port('PWAKEUP'),
      if (userDataWidth != 0) Port('PRUSER', userDataWidth),
      if (userRespWidth != 0) Port('PBUSER', userRespWidth),
    ], [
      ApbDirection.fromCompleter
    ]);
  }

  /// Constructs a new [Apb] with identical parameters to [other].
  Apb.clone(Apb other)
      : this(
          addrWidth: other.addrWidth,
          dataWidth: other.dataWidth,
          userReqWidth: other.userReqWidth,
          userRespWidth: other.userRespWidth,
          includeSlvErr: other.includeSlvErr,
        );

  /// Checks that the values set for parameters follow the specification's
  /// restrictions.
  void _validateParameters() {
    if (addrWidth > 32 || addrWidth < 0) {
      throw RohdHclException(
          'addrWidth must be a positive number no greater than 32.');
    }

    const legalDataWidths = [8, 16, 32];
    if (!legalDataWidths.contains(dataWidth)) {
      throw RohdHclException('dataWidth must be one of $legalDataWidths');
    }

    if (userReqWidth < 0) {
      throw RohdHclException('userReqWidth must >= 0');
    }

    if (userDataWidth < 0) {
      throw RohdHclException('userDataWidth must >= 0');
    }

    if (userRespWidth < 0) {
      throw RohdHclException('userRespWidth must >= 0');
    }
  }
}
