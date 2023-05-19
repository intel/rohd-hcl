// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_test.dart
// Tests for the APB interface.
//
// 2023 May 19
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class ApbController extends Module {
  ApbController(Apb intf) {
    intf = Apb.clone(intf)
      ..connectIO(this, intf,
          inputTags: {ApbDirection.misc, ApbDirection.fromRequester},
          outputTags: {ApbDirection.fromCompleter});
  }
}

class ApbRequester extends Module {
  ApbRequester(Apb intf) {
    intf = Apb.clone(intf)
      ..connectIO(this, intf,
          inputTags: {ApbDirection.misc, ApbDirection.fromCompleter},
          outputTags: {ApbDirection.fromRequester});
  }
}

class ApbPair extends Module {
  ApbPair(Logic clk, Logic reset) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final apb = Apb(
      includeSlvErr: true,
      userDataWidth: 10,
      userReqWidth: 11,
      userRespWidth: 12,
    );
    apb.clk <= clk;
    apb.resetN <= ~reset;

    ApbController(apb);
    ApbRequester(apb);
  }
}

void main() {
  test('connect apb modules', () async {
    final abpPair = ApbPair(Logic(), Logic());
    await abpPair.build();
  });

  test('abp optional ports null', () async {
    final apb = Apb();
    expect(apb.aUser, isNull);
    expect(apb.bUser, isNull);
    expect(apb.rUser, isNull);
    expect(apb.wUser, isNull);
    expect(apb.slvErr, isNull);
  });
}
