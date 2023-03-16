ROHD Hardware Component Libary
==============================

A hardware component library developed with [ROHD](https://github.com/intel/rohd).

This project is a work in progress!  Please feel free to contribute or provide feedback.

## Component Plan

Below is a list of planned components to implement.

- Encoders
	- 1-hot to Binary
	- Binary to 1-hot
	- Gray to Binary
	- Binary to Gray
	- Priority
- Arbiters
	- Priority
	- Round-robin
- FIFO
	- Synchronous
	- Asynchronous
	- Bubble Generating
- Find
	- Find N'th bit=X
	- Find N'th bit=X from end
	- Min
	- Max
- Count
	- Count bit=X
	- Count X
- Sort
- Arithmetic
	- Adders
	- Subtractors
	- Multipliers
		- Pipelined Integer Multiplier
	- Dividers
	- Log
- Rotate
	- Left
	- Right
- Counter
- LFSR
- Error checking
	- ECC
	- CRC
	- Parity
- Data flow
	- Ready/Valid
	- Connect/Disconnect (e.g. SFI)
	- Widening
	- Narrowing
	- Crediting
	- NoC's
		- Coherent
		- Non-Coherent
- Memory
	- Register Files
		- Flop-based
		- Latch-based
	- LRU

## Guidelines

- All components should be `Module`s so that they are convertible to SystemVerilog stand-alone
- Components should be general and easily reusable
- Components should be as configurable as may be useful
- Components must be extensively tested
- Components must have excellent documentation and examples
- The first component in a category should be the simplest
- Focus on breadth of component types before depth in one type