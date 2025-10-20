// Test to verify if original Fifo has the occupancy bugs that FixedFifo claims to fix

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('original FIFO occupancy bug verification', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final writeEnable = Logic()..put(0);
    final readEnable = Logic()..put(0);  // Keep reads disabled to test occupancy buildup
    final writeData = Logic(width: 32);

    final fifo = Fifo(  // Using original Fifo
      clk,
      reset,
      writeEnable: writeEnable,
      readEnable: readEnable,
      writeData: writeData,
      depth: 2,  // Small depth to easily trigger bugs
      generateOccupancy: true,
      name: 'original_fifo_bug_test',
    );

    await fifo.build();
    unawaited(Simulator.run());

    // Reset
    reset.put(1);
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;

    print('=== Testing Original FIFO Occupancy Behavior ===');
    print('FIFO depth: 2');
    print('Initial: empty=${fifo.empty.value.toBool()}, full=${fifo.full.value.toBool()}, occupancy=${fifo.occupancy!.value.toInt()}');

    // Write multiple items with readEnable always 0 (blocked reads)
    for (int i = 0; i < 5; i++) {  // Write more than depth to test for bugs
      writeEnable.put(1);
      writeData.put(0x1000 + i);
      await clk.nextNegedge;
      writeEnable.put(0);
      await clk.nextNegedge;
      
      final occupancy = fifo.occupancy!.value.toInt();
      final full = fifo.full.value.toBool();
      final empty = fifo.empty.value.toBool();
      
      print('After write $i: empty=$empty, full=$full, occupancy=$occupancy');
      
      // Check for the bugs I claimed FixedFifo fixes:
      
      // Bug 1: Occupancy should never exceed depth
      if (occupancy > 2) {
        print('🐛 BUG FOUND: Occupancy ($occupancy) exceeds depth (2)');
      }
      
      // Bug 2: When occupancy equals depth, FIFO should be considered full
      if (occupancy == 2 && !full) {
        print('🐛 POTENTIAL BUG: Occupancy equals depth but full=false');
      }
      
      // Bug 3: Empty flag should be false when occupancy > 0
      if (occupancy > 0 && empty) {
        print('🐛 BUG FOUND: Occupancy > 0 but empty=true');
      }
    }

    print('\n=== Testing Read Behavior After Overfill ===');
    
    // Now enable reads and see what happens
    readEnable.put(1);
    
    for (int i = 0; i < 6; i++) {  // Try to read more than we wrote
      await clk.nextNegedge;
      
      final occupancy = fifo.occupancy!.value.toInt();
      final full = fifo.full.value.toBool();
      final empty = fifo.empty.value.toBool();
      
      print('After read $i: empty=$empty, full=$full, occupancy=$occupancy');
      
      // Bug 4: Occupancy should never go negative
      if (occupancy < 0) {
        print('🐛 BUG FOUND: Occupancy went negative ($occupancy)');
      }
      
      // Bug 5: When occupancy is 0, FIFO should be empty
      if (occupancy == 0 && !empty) {
        print('🐛 POTENTIAL BUG: Occupancy is 0 but empty=false');
      }
      
      // Stop if we're clearly empty
      if (empty && occupancy == 0) {
        print('FIFO is now empty, stopping reads');
        break;
      }
    }

    readEnable.put(0);
    await Simulator.endSimulation();
  });
}