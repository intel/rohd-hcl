import 'package:rohd/rohd.dart';
import 'sort_bitonic.dart';

// ignore_for_file: avoid_unused_constructor_parameters, public_member_api_docs

class FourInput extends Module {
  final dataWidth = 8;
  final labelWidth = 4;

  FourInput(Logic clk, Logic rst, Logic x0, Logic x1, Logic x2, Logic x3)
      : super(name: 'FourInput') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    x0 = addInput('x0', x0, width: x0.width);
    x1 = addInput('x1', x1, width: x1.width);
    x2 = addInput('x2', x2, width: x2.width);
    x3 = addInput('x3', x3, width: x3.width);

    final y0 = addOutput('y0', width: x0.width);
    final y1 = addOutput('y1', width: x1.width);
    final y2 = addOutput('y2', width: x2.width);
    final y3 = addOutput('y3', width: x3.width);

    final yValid = addOutput('y_valid');

    final stage0rslt0 = Logic(name: 'stage0_rslt_0', width: dataWidth);
    final stage0rslt1 = Logic(name: 'stage0_rslt_1', width: dataWidth);
    final stage0rslt2 = Logic(name: 'stage0_rslt_2', width: dataWidth);
    final stage0rslt3 = Logic(name: 'stage0_rslt_3', width: dataWidth);

    final stage0Valid = Logic(name: 'stage0_valid');

    // Perform Bitonic sort to get bitonic sequence
    final input2stage00 = InputTwo(clk, rst, x0, x1, 1);

    stage0rslt0 <= input2stage00.y0;
    stage0rslt1 <= input2stage00.y1;

    final input2stage01 = InputTwo(clk, rst, x2, x3, 0);

    stage0rslt2 <= input2stage01.y0;
    stage0rslt3 <= input2stage01.y1;

    // Perform bitonic Merge to merge the sequence into ascending order
    final input4Stage10 = FourInputBitonicRequired(
      clk,
      rst,
      stage0rslt0,
      stage0rslt1,
      stage0rslt2,
      stage0rslt3,
    );

    y0 <= input4Stage10.y0;
    y1 <= input4Stage10.y1;
    y2 <= input4Stage10.y2;
    y3 <= input4Stage10.y3;
  }
}

class FourInputBitonicRequired extends Module {
  final dataWidth = 8;
  final labelWidth = 4;

  Logic get y0 => output('y0');
  Logic get y1 => output('y1');
  Logic get y2 => output('y2');
  Logic get y3 => output('y3');

  FourInputBitonicRequired(
    Logic clk,
    Logic rst,
    Logic x0,
    Logic x1,
    Logic x2,
    Logic x3,
  ) : super(name: 'input_4_bitonic_required ') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);

    x0 = addInput('x0', x0, width: x0.width);
    x1 = addInput('x1', x1, width: x1.width);
    x2 = addInput('x2', x2, width: x2.width);
    x3 = addInput('x3', x3, width: x3.width);

    final y0 = addOutput('y0', width: x0.width);
    final y1 = addOutput('y1', width: x1.width);
    final y2 = addOutput('y2', width: x2.width);
    final y3 = addOutput('y3', width: x3.width);

    final stage0rslt0 = Logic(name: 'stage0_rslt_0', width: dataWidth);
    final stage0rslt1 = Logic(name: 'stage0_rslt_1', width: dataWidth);
    final stage0rslt2 = Logic(name: 'stage0_rslt_2', width: dataWidth);
    final stage0rslt3 = Logic(name: 'stage0_rslt_3', width: dataWidth);

    // Stage 1
    final input2Stage00 = InputTwo(clk, rst, x0, x2, 1);

    stage0rslt0 <= input2Stage00.y0;
    stage0rslt2 <= input2Stage00.y1;

    final input2Stage01 = InputTwo(clk, rst, x1, x3, 1);

    stage0rslt1 <= input2Stage01.y0;
    stage0rslt3 <= input2Stage01.y1;

    // Stage 2
    final input2Stage10 = InputTwo(clk, rst, stage0rslt0, stage0rslt1, 1);

    y0 <= input2Stage10.y0;
    y1 <= input2Stage10.y1;

    final input2Stage11 = InputTwo(clk, rst, stage0rslt2, stage0rslt3, 1);

    y2 <= input2Stage11.y0;
    y3 <= input2Stage11.y1;
  }
}

void main(List<String> args) async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic(name: 'reset');
  final xValid = Logic(name: 'xValid');
  final x0 = Logic(width: 8);
  final x1 = Logic(width: 8);
  final x2 = Logic(width: 8);
  final x3 = Logic(width: 8);

  final mod = FourInput(clk, reset, x0, x1, x2, x3);

  await mod.build();

  print(mod.generateSynth());

  x0.inject(7);
  x1.inject(5);
  x2.inject(4);
  x3.inject(3);

  reset.inject(0);
  xValid.inject(1);

  WaveDumper(mod, outputPath: '4_input_sort.vcd');

  Simulator.setMaxSimTime(100);
  await Simulator.run();
}
