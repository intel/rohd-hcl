import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/finite_state_machine_with_updates.dart';
import 'package:test/test.dart';

enum ExStates {
  state1,
  state2,
}

class ExMod extends Module {
  ExMod(Logic clk) {
    clk = addInput('clk', clk);

    FiniteStateMachineWithUpdates<ExStates>(
      clk,
      Logic(),
      ExStates.state1,
      [
        StateWithUpdates<ExStates>(
          ExStates.state1,
          events: {},
          actions: [],
          updates: [Logic() < 1],
        ),
        StateWithUpdates<ExStates>(
          ExStates.state2,
          events: {},
          actions: [],
        ),
      ],
    );
  }
}

void main() {
  test('basic', () async {
    final dut = ExMod(Logic());
    await dut.build();

    print(dut.generateSynth());
  });
}
