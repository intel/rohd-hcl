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

Both write and lookup ports use the `TagInterface`, which provides a consistent interface for CAM operations:

- For **writes**: `en` enables the write, `idx` specifies the destination address, `tag` is the data to write, and `hit` sets/clears the valid bit for the entry (hit=1 marks entry valid, hit=0 marks entry invalid).
- For **lookups**: `tag` is the query, `idx` returns the matching index, and `hit` indicates whether a valid match was found. Only entries with their valid bit set will match.

Each CAM entry has a valid bit that must be set for the entry to participate in lookups. This allows distinguishing between "entry contains tag 0x00" and "entry is empty/invalid".

### Read-with-Invalidate Pattern

A read-with-invalidate operation can be implemented by using a dedicated write port wired to the lookup port's outputs:

- Wire `invalidatePort.idx <= lookupPort.idx` to target the found entry
- Wire `invalidatePort.tag <= lookupPort.tag` to match the lookup
- Set `invalidatePort.hit = 0` (always invalidate, never validate)
- Set `invalidatePort.en = lookupPort.hit` (only invalidate if found)

This pattern allows atomic "find and remove" operations where the lookup returns the matching index while simultaneously invalidating that entry.

An example use is:

```dart
      const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = TagInterface(idWidth, tagWidth);
      final invalidatePort = TagInterface(idWidth, tagWidth);
      final lookupPort = TagInterface(idWidth, tagWidth);

      final cam = Cam(
        clk,
        reset,
        [writePort, invalidatePort],
        [lookupPort],
        numEntries: numEntries,
      );

      // Wire invalidatePort to use lookupPort's combinational output
      invalidatePort.idx <= lookupPort.idx;
      invalidatePort.tag <= lookupPort.tag;
      invalidatePort.hit.inject(0);  // Always clear valid bit

      // Write tag 0x99 to index position 1 (hit=1 marks it valid)
      writePort.en.inject(1);
      writePort.hit.inject(1);
      writePort.idx.inject(1);
      writePort.tag.inject(0x99);
      await clk.nextPosedge;

      // Lookup tag 0x99 without invalidate
      lookupPort.tag.inject(0x99);
      invalidatePort.en.inject(0);
      await clk.nextPosedge;
      // We found our matching tag at index 1 where we stored it!
      expect(lookupPort.idx.value.toInt(), equals(1),
          reason: 'Should return index 1');

      // Lookup and invalidate: enable invalidatePort when hit
      invalidatePort.en.inject(1);  // Invalidate on hit
      await clk.nextPosedge;
      // Entry is now invalidated - subsequent lookup will miss
```
