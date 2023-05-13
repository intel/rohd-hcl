# FIFO

ROHD HCL comes with a simple FIFO (First In, First Out).  The detailed API docs are available [here](https://intel.github.io/rohd-hcl/rohd_hcl/Fifo-class.html).

The underlying implementation uses a flop-based memory (see [`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html)) to store data until it is ready to be popped, with independent read and write pointers.

When `writeEnable` is high, `writeData` is added to the FIFO.  When `readEnable` is high, `readData` is popped off the FIFO.

The FIFO has a configurable `depth`.

## Peeking

When `readEnable` is low, the `readData` continually provides access to "peek" the next data.

## Empty and Full

The `empty` signal indicates when nothing is in the FIFO.  The `full` signal indicates when the FIFO can store no additional data.

## Bypass

THe FIFO optionally supports a bypass if `generateBypass` is set.  When generated, if the FIFO is empty and both `readEnable` and `writeEnable` are high at the same time, then the FIFO will do a bypass of the internal storage, allowing for a combinational passthrough.

## Errors

Error information can optionally be generated and provided if `generateError` is set.  If data is popped when the FIFO is empty, or pushed when the FIFO is full, then the `error` signal will assert.

There is no guarantee that the `error` signal will hold high once asserted once.  Behavior after an error condition is undefined.

## Occupancy

Occupancy information can optionally be generated and provided if `generateOccupancy` is set.  The `occupancy` signal will indicate the number of items currently stored in the FIFO.

[FIFO Schematic](https://desmonddak.github.io/rohd-hcl/Fifo.html)
