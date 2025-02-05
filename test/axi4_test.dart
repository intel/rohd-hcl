// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi_test.dart
// Tests for the AXI4 interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class Axi4Subordinate extends Module {
  Axi4Subordinate(Axi4SystemInterface sIntf, List<Axi4ReadInterface> rIntfs,
      List<Axi4WriteInterface> wIntfs) {
    sIntf = Axi4SystemInterface()
      ..connectIO(this, sIntf, inputTags: {Axi4Direction.misc});

    for (var i = 0; i < rIntfs.length; i++) {
      rIntfs.add(Axi4ReadInterface.clone(rIntfs[i])
        ..connectIO(this, rIntfs[i],
            inputTags: {Axi4Direction.fromMain},
            outputTags: {Axi4Direction.fromSubordinate}));
    }

    for (var i = 0; i < wIntfs.length; i++) {
      wIntfs.add(Axi4WriteInterface.clone(wIntfs[i])
        ..connectIO(this, wIntfs[i],
            inputTags: {Axi4Direction.fromMain},
            outputTags: {Axi4Direction.fromSubordinate}));
    }
  }
}

class Axi4Main extends Module {
  Axi4Main(Axi4SystemInterface sIntf, List<Axi4ReadInterface> rIntfs,
      List<Axi4WriteInterface> wIntfs) {
    sIntf = Axi4SystemInterface()
      ..connectIO(this, sIntf, inputTags: {Axi4Direction.misc});

    for (var i = 0; i < rIntfs.length; i++) {
      rIntfs.add(Axi4ReadInterface.clone(rIntfs[i])
        ..connectIO(this, rIntfs[i],
            inputTags: {Axi4Direction.fromSubordinate},
            outputTags: {Axi4Direction.fromMain}));
    }

    for (var i = 0; i < wIntfs.length; i++) {
      wIntfs.add(Axi4WriteInterface.clone(wIntfs[i])
        ..connectIO(this, wIntfs[i],
            inputTags: {Axi4Direction.fromSubordinate},
            outputTags: {Axi4Direction.fromMain}));
    }
  }
}

class Axi4Pair extends Module {
  Axi4Pair(Logic clk, Logic reset, {int numReads = 1, int numWrites = 1}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi4SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final rIntf = <Axi4ReadInterface>[];
    for (var i = 0; i < numReads; i++) {
      rIntf.add(Axi4ReadInterface());
    }

    final wIntf = <Axi4WriteInterface>[];
    for (var i = 0; i < numWrites; i++) {
      wIntf.add(Axi4WriteInterface());
    }

    Axi4Main(sIntf, rIntf, wIntf);
    Axi4Subordinate(sIntf, rIntf, wIntf);
  }
}

void main() {
  test('connect axi4 modules', () async {
    final axi4Pair = Axi4Pair(Logic(), Logic());
    await axi4Pair.build();
  });

  test('axi4 optional ports null', () async {
    final rIntf = Axi4ReadInterface(
        idWidth: 0,
        lenWidth: 0,
        aruserWidth: 0,
        ruserWidth: 0,
        useLast: false,
        useLock: false);
    expect(rIntf.arId, isNull);
    expect(rIntf.arLen, isNull);
    expect(rIntf.arLock, isNull);
    expect(rIntf.arUser, isNull);
    expect(rIntf.rId, isNull);
    expect(rIntf.rLast, isNull);
    expect(rIntf.rUser, isNull);

    final wIntf = Axi4WriteInterface(
        idWidth: 0,
        lenWidth: 0,
        awuserWidth: 0,
        wuserWidth: 0,
        buserWidth: 0,
        useLock: false);
    expect(wIntf.awId, isNull);
    expect(wIntf.awLen, isNull);
    expect(wIntf.awLock, isNull);
    expect(wIntf.awUser, isNull);
    expect(wIntf.wUser, isNull);
    expect(wIntf.bUser, isNull);
  });
}
