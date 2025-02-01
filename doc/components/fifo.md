# FIFO

ROHD-HCL comes with a simple FIFO (First In, First Out).  The detailed API docs are available [here](https://intel.github.io/rohd-hcl/rohd_hcl/Fifo-class.html).

The underlying implementation uses a flop-based memory (see [`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html)) to store data until it is ready to be popped, with independent read and write pointers.

When `writeEnable` is high, `writeData` is added to the FIFO.  When `readEnable` is high, `readData` is popped off the FIFO.

The FIFO has a configurable `depth`.

## Peeking

When `readEnable` is low, the `readData` continually provides access to "peek" the next data.

## Empty and Full

The `empty` signal indicates when nothing is in the FIFO.  The `full` signal indicates when the FIFO can store no additional data.

## Bypass

The FIFO optionally supports a bypass if `generateBypass` is set.  When generated, if the FIFO is empty and both `readEnable` and `writeEnable` are high at the same time, then the FIFO will do a bypass of the internal storage, allowing for a combinational passthrough.

## Errors

Error information can optionally be generated and provided if `generateError` is set.  If data is popped when the FIFO is empty, or pushed when the FIFO is full, then the `error` signal will assert.

There is no guarantee that the `error` signal will hold high once asserted.  Behavior after an error condition is undefined.

## Occupancy

Occupancy information can optionally be generated and provided if `generateOccupancy` is set.  The `occupancy` signal will indicate the number of items currently stored in the FIFO.

## Example Schematic

<!-- An example schematic for one configuration is viewable here: [FIFO Schematic](https://intel.github.io/rohd-hcl/Fifo.html) -->

## Testbench Utilities

The FIFO comes with both a checker and a tracker that you can leverage in your testbench.

### Checker

The `FifoChecker` is a ROHD-VF component which will watch for proper usage of a FIFO in your simulation. It is intended to check usage, not the internal workings of the FIFO, which are already pre-validated in the unit tests.  This means it covers things like underflow, overflow, and that the FIFO is empty at the end of the test.

### Tracker

The `FifoTracker` will generate log files using the `Tracker` from ROHD-VF in either table or JSON format.  It tracks reads and writes per timestamp, including data pushed/popped and the current occupancy.  An example table is shown below (from one of the unit tests):

```text
----------------------------------------
 | T        | C  | D              | O | 
 | I        | O  | A              | C | 
 | M        | M  | T              | C | 
 | E        | M  | A              | U | 
 |          | A  |                | P | 
 |          | N  |                | A | 
 |          | D  |                | N | 
 |          |    |                | C | 
 |          |    |                | Y | 
----------------------------------------
 |       55 | WR |        32'h111 | 1 | {Time: 55, Command: WR, Data: 32'h111, Occupancy: 1}
 |       75 | WR |        32'h222 | 2 | {Time: 75, Command: WR, Data: 32'h222, Occupancy: 2}
 |       75 | RD |        32'h111 | 1 | {Time: 75, Command: RD, Data: 32'h111, Occupancy: 1}
 |       85 | RD |        32'h222 | 0 | {Time: 85, Command: RD, Data: 32'h222, Occupancy: 0}

```
