// Simple SystemVerilog generation for FIFO with clean naming.
import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

void main() async {
  print('Generating FIFO SystemVerilog with clean naming...');

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();

  // Create a simple FIFO to show the clean pointer naming.
  final writeEnable = Logic();
  final writeData = Logic(width: 8);
  final readEnable = Logic();

  final fifo = Fifo(
    clk,
    reset,
    writeEnable: writeEnable,
    writeData: writeData,
    readEnable: readEnable,
    depth: 4,
  );

  await fifo.build();

  final sv = fifo.generateSynth();

  Directory('generated').createSync(recursive: true);
  File('generated/CleanFifo.sv').writeAsStringSync(sv);

  print('Generated SystemVerilog saved to generated/CleanFifo.sv');
  print('This shows the clean FIFO pointer arithmetic naming!');
}
