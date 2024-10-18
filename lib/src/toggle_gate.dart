import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/clock_gating.dart';

class ToggleGate extends Module {
  Logic get gatedData => output('gatedData');

  ToggleGate({
    required Logic enable,
    required Logic data,
    required Logic clk,
    required Logic reset,
    dynamic resetValue,
    ClockGateControlInterface? clockGateControlIntf,
    super.name = 'toggle_gate',
  }) {
    enable = addInput('enable', enable);
    data = addInput('data', data, width: data.width);
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    if (resetValue != null && resetValue is Logic) {
      resetValue = addInput('resetValue', resetValue, width: resetValue.width);
    }

    if (clockGateControlIntf != null) {
      clockGateControlIntf =
          ClockGateControlInterface.clone(clockGateControlIntf)
            ..pairConnectIO(this, clockGateControlIntf, PairRole.consumer);
    }

    addOutput('gatedData', width: data.width);

    final lastData = Logic(name: 'lastData', width: data.width);

    final gateEnable = enable & (lastData.neq(data));

    //TODO: test with clock gating enabled and disabled

    final clkGate = ClockGate(
      clk,
      enable: gateEnable,
      reset: reset,
      controlIntf: clockGateControlIntf,
    );

    lastData <=
        flop(
            clkGate.gatedClk,
            en: clkGate.isPresent ? null : gateEnable,
            reset: reset,
            resetValue: resetValue,
            data);

    gatedData <=
        mux(
          enable,
          data,
          lastData,
        );
  }
}
