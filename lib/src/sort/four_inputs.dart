import 'package:rohd/rohd.dart';
import 'sort_bitonic.dart';

// ignore_for_file: avoid_unused_constructor_parameters, public_member_api_docs

class FourInput extends Module {
  final dataWidth = 8;
  final labelWidth = 4;

  FourInput(Logic clk, Logic rst, Logic xValid, Logic x0, Logic x1, Logic x2,
      Logic x3, Logic xLabel0, Logic xLabel1, Logic xLabel2, Logic xLabel3)
      : super(name: 'FourInput') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    xValid = addInput('x_valid', xValid);
    x0 = addInput('x0', x0, width: x0.width);
    x1 = addInput('x1', x1, width: x1.width);
    x2 = addInput('x2', x2, width: x2.width);
    x3 = addInput('x3', x3, width: x3.width);

    xLabel0 = addInput('xLabel0', xLabel0, width: xLabel0.width);
    xLabel1 = addInput('xLabel1', xLabel1, width: xLabel1.width);
    xLabel2 = addInput('xLabel2', xLabel2, width: xLabel2.width);
    xLabel3 = addInput('xLabel3', xLabel3, width: xLabel3.width);

    final y0 = addOutput('y0', width: x0.width);
    final y1 = addOutput('y1', width: x1.width);
    final y2 = addOutput('y2', width: x2.width);
    final y3 = addOutput('y3', width: x3.width);

    final yLabel0 = addOutput('yLabel0', width: xLabel0.width);
    final yLabel1 = addOutput('yLabel1', width: xLabel1.width);
    final yLabel2 = addOutput('yLabel2', width: xLabel2.width);
    final yLabel3 = addOutput('yLabel3', width: xLabel3.width);

    final yValid = addOutput('y_valid');

    final stage0rslt0 = Logic(name: 'stage0_rslt_0', width: dataWidth);
    final stage0rslt1 = Logic(name: 'stage0_rslt_1', width: dataWidth);
    final stage0rslt2 = Logic(name: 'stage0_rslt_2', width: dataWidth);
    final stage0rslt3 = Logic(name: 'stage0_rslt_3', width: dataWidth);

    final stage0labl0 = Logic(name: 'stage0_labl_0', width: labelWidth);
    final stage0labl1 = Logic(name: 'stage0_labl_1', width: labelWidth);
    final stage0labl2 = Logic(name: 'stage0_labl_2', width: labelWidth);
    final stage0labl3 = Logic(name: 'stage0_labl_3', width: labelWidth);

    final stage0Valid = Logic(name: 'stage0_valid');

    // Perform Bitonic sort to get bitonic sequence
    final input2stage00 =
        InputTwo(clk, rst, xValid, x0, x1, xLabel0, xLabel1, 1);

    stage0rslt0 <= input2stage00.y0;
    stage0rslt1 <= input2stage00.y1;
    stage0labl0 <= input2stage00.yLabel0;
    stage0labl1 <= input2stage00.yLabel1;

    final input2stage01 =
        InputTwo(clk, rst, xValid, x2, x3, xLabel2, xLabel3, 0);

    stage0rslt2 <= input2stage01.y0;
    stage0rslt3 <= input2stage01.y1;

    stage0labl2 <= input2stage01.yLabel0;
    stage0labl3 <= input2stage01.yLabel1;

    // Perform bitonic Merge to merge the sequence into ascending order
    final input4Stage10 = FourInputBitonicRequired(
      clk,
      rst,
      stage0Valid,
      stage0rslt0,
      stage0rslt1,
      stage0rslt2,
      stage0rslt3,
      stage0labl0,
      stage0labl1,
      stage0labl2,
      stage0labl3,
    );

    y0 <= input4Stage10.y0;
    y1 <= input4Stage10.y1;
    y2 <= input4Stage10.y2;
    y3 <= input4Stage10.y3;

    yLabel0 <= input4Stage10.yLabel0;
    yLabel1 <= input4Stage10.yLabel1;
    yLabel2 <= input4Stage10.yLabel2;
    yLabel3 <= input4Stage10.yLabel3;
  }
}

class FourInputBitonicRequired extends Module {
  final dataWidth = 8;
  final labelWidth = 4;

  Logic get y0 => output('y0');
  Logic get y1 => output('y1');
  Logic get y2 => output('y2');
  Logic get y3 => output('y3');

  Logic get yLabel0 => output('yLabel0');
  Logic get yLabel1 => output('yLabel1');
  Logic get yLabel2 => output('yLabel2');
  Logic get yLabel3 => output('yLabel3');

  FourInputBitonicRequired(
    Logic clk,
    Logic rst,
    Logic xValid,
    Logic x0,
    Logic x1,
    Logic x2,
    Logic x3,
    Logic xLabel0,
    Logic xLabel1,
    Logic xLabel2,
    Logic xLabel3,
  ) : super(name: 'input_4_bitonic_required ') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    xValid = addInput('x_valid', xValid);

    x0 = addInput('x0', x0, width: x0.width);
    x1 = addInput('x1', x1, width: x1.width);
    x2 = addInput('x2', x2, width: x2.width);
    x3 = addInput('x3', x3, width: x3.width);

    xLabel0 = addInput('xLabel0', xLabel0, width: xLabel0.width);
    xLabel1 = addInput('xLabel1', xLabel1, width: xLabel1.width);
    xLabel2 = addInput('xLabel2', xLabel2, width: xLabel2.width);
    xLabel3 = addInput('xLabel3', xLabel3, width: xLabel3.width);

    final y0 = addOutput('y0', width: x0.width);
    final y1 = addOutput('y1', width: x1.width);
    final y2 = addOutput('y2', width: x2.width);
    final y3 = addOutput('y3', width: x3.width);

    final yLabel0 = addOutput('yLabel0', width: xLabel0.width);
    final yLabel1 = addOutput('yLabel1', width: xLabel1.width);
    final yLabel2 = addOutput('yLabel2', width: xLabel2.width);
    final yLabel3 = addOutput('yLabel3', width: xLabel3.width);

    final stage0rslt0 = Logic(name: 'stage0_rslt_0', width: dataWidth);
    final stage0rslt1 = Logic(name: 'stage0_rslt_1', width: dataWidth);
    final stage0rslt2 = Logic(name: 'stage0_rslt_2', width: dataWidth);
    final stage0rslt3 = Logic(name: 'stage0_rslt_3', width: dataWidth);

    final stage0labl0 = Logic(name: 'stage0_labl_0', width: labelWidth);
    final stage0labl1 = Logic(name: 'stage0_labl_1', width: labelWidth);
    final stage0labl2 = Logic(name: 'stage0_labl_2', width: labelWidth);
    final stage0labl3 = Logic(name: 'stage0_labl_3', width: labelWidth);

    final stage0Valid = Logic(name: 'stage0_valid');

    // Stage 1
    final input2Stage00 =
        InputTwo(clk, rst, xValid, x0, x2, xLabel0, xLabel2, 1);

    stage0rslt0 <= input2Stage00.y0;
    stage0rslt2 <= input2Stage00.y1;
    stage0labl0 <= input2Stage00.yLabel0;
    stage0labl2 <= input2Stage00.yLabel1;

    final input2Stage01 =
        InputTwo(clk, rst, xValid, x1, x3, xLabel1, xLabel3, 1);

    stage0rslt1 <= input2Stage01.y0;
    stage0rslt3 <= input2Stage01.y1;
    stage0labl1 <= input2Stage01.yLabel0;
    stage0labl3 <= input2Stage01.yLabel1;

    // Stage 2
    final input2Stage10 = InputTwo(
        clk, rst, xValid, stage0rslt0, stage0rslt1, xLabel0, xLabel1, 1);

    y0 <= input2Stage10.y0;
    y1 <= input2Stage10.y1;
    yLabel0 <= input2Stage10.yLabel0;
    yLabel1 <= input2Stage10.yLabel1;

    final input2Stage11 = InputTwo(
        clk, rst, xValid, stage0rslt2, stage0rslt3, xLabel2, xLabel3, 1);

    y2 <= input2Stage11.y0;
    y3 <= input2Stage11.y1;
    yLabel2 <= input2Stage11.yLabel0;
    yLabel3 <= input2Stage11.yLabel1;
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

  final xLabel0 = Logic(width: 4);
  final xLabel1 = Logic(width: 4);
  final xLabel2 = Logic(width: 4);
  final xLabel3 = Logic(width: 4);

  final mod = FourInput(
      clk, reset, xValid, x0, x1, x2, x3, xLabel0, xLabel1, xLabel2, xLabel3);

  await mod.build();

  print(mod.generateSynth());

  x0.inject(7);
  x1.inject(5);
  x2.inject(4);
  x3.inject(3);
  xLabel0.inject(0);
  xLabel1.inject(1);
  xLabel2.inject(2);
  xLabel3.inject(3);

  reset.inject(0);
  xValid.inject(1);

  WaveDumper(mod, outputPath: '4_input_sort.vcd');

  Simulator.setMaxSimTime(100);
  await Simulator.run();
}
