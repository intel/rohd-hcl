# Memory

ROHD-HCL provides a generic `abstract` [`Memory`](https://intel.github.io/rohd-hcl/rohd_hcl/Memory-class.html) class which accepts a dynamic number of `writePorts` and `readPorts`, where each port is of type [`DataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/DataPortInterface-class.html).  A `DataPortInterface` is a simple interface with `en` and `addr` as `control` signals and `data` signal(s).  In a write interface, all signals are in the same direction.  In a read interface, the `control` signals are in the opposite direction of the `data` signal(s).

## Masks

A subclass of `DataPortInterface` is the[`MaskedDataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/MaskedDataPortInterface-class.html), which adds `mask` to the `data` group of signals.  The `mask` signal is a byte-enable signal, where each bit of `mask` controls one byte of `data`.

## Register Files

A subclass of `Memory` is the [`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html), which inherits the same flexible interface from `Memory`.  It has a configurable number of entries via `numEntries`.

The `RegisterFile` accepts masks on writes, but not on reads.

Currently, `RegisterFile` only generates flop-based memory (no latches).

The read path is combinational, so data is provided immediately according to the control signals.

The `RegisterFile` can be initialized with data on reset using `resetValue` following the conventions of `ResettableEntries`.

[RegisterFile Schematic](https://intel.github.io/rohd-hcl/RegisterFile.html)

## First-In First-Out (FIFO) Buffers

Please see [`Fifo`](./fifo.md)

## Memory Models

The `MemoryModel` has the same interface as a `Memory`, but is non-synthesizable and uses a software-based `SparseMemoryStorage` as a backing for data storage. This is a useful tool for testing systems that have relatively large memories.

The `MemoryStorage` class also provides utilities for reading (`loadMemString`) and writing (`dumpMemString`) Verilog-compliant memory files (e.g. for `readmemh`).

## Cam

A content-addressable memory or `Cam` is provided which allows for associative lookup using a `tag` that produces an index to help with building specialized forms of caches where the actual data is stored in a separate register file. The index is to be separately used as a linear address in another component (like a `RegisterFile`) to find the associated data.  In this case the `tag` is matched during a read and the position in memory is returned, which is the index. For the fill ports, the user can simply write a new tag at a given index location. This means the `Cam` is a fine-grained component for use in building associative look of positions of objects in another memory.

Note that because we are using a standard `DataPortInterface` for the write ports, the `dataPort.addr` is really the index position and the `dataPort.data` is the tag we are storing to populate the associative array.  Then upon lookup, we have a `TagInterface` which is more natural:  `lookupPort.tag` is the query and `lookup.idx` is the resulting index to be used to lookup data in a separate component. `lookupPort.hit` tells us that our query was found.

Another form of `Cam` or `CamInvalidate` provides a read interface with a read-with-invalidate feature if the invalidate port is set on the interface.

An example use is:

```dart
const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        numEntries: numEntries,
      );
      // Write tag 0x99 to index position 1
      writePort.addr.inject(1);
      writePort.data.inject(0x99);
      await clk.nextPosedge;

      // Lookup tag 0x99 without invalidate
      lookupPort.tag.inject(0x99);
      await clk.nextPosedge;
      // We found our matching tag at index 1 where we stored it!
      expect(lookupPort.idx.value.toInt(), equals(1),
          reason: 'Should return index 0');
```
