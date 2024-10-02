import 'package:rohd/rohd.dart';

class ToggleGate extends Module {
  Logic get gatedData => output('gatedData');

  ToggleGate(
      {required Logic enable,
      required Logic data,
      required Logic clk,
      Logic? reset}) {
    enable = addInput('enable', enable);
    data = addInput('data', data, width: data.width);
    clk = addInput('clk', clk);
    if (reset != null) {
      reset = addInput('reset', reset);
    }

    addOutput('gatedData', width: data.width);

    gatedData <=
        mux(
          enable,
          data,
          flop(clk, en: enable, reset: reset, data),
        );
  }
}
