# Standard Interfaces

ROHD-HCL provides a set of standard interfaces using ROHD `Interface`s.  This makes it easy to instantiate and connect common interfaces in a configurable way.

## Module Registration Helpers

The `RohdHclModuleInterfacePorts` extension provides a shared registration
seam over ROHD's released interface APIs:

- `addInterface` clones an `Interface`, registers selected tag directions, and
  returns the module-local clone.
- `addPairInterface` does the same for a selected `PairRole`.
- `addPairInterfaceFrom` registers an intentionally different concrete
  `PairInterface` target against a source. Ready/valid retyping accepts a
  width-compatible plain packed payload bridge and rejects mismatched widths or
  incompatible declared structures.

The helpers preserve specialized `connectIO` behavior, including typed
ready/valid payload ports. Existing components are not required to migrate to
the seam immediately.

## APB

The [ABP Interface](https://developer.arm.com/documentation/ihi0024/latest/) is a standard AMBA interface.  ROHD HCL has a configurable version of the APB interface called [`ApbInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/ApbInterface-class.html).

## SPI

The Serial Peripheral Interface (SPI) is a common serial communicaton interface. ROHD HCL has a configurable version of the SPI interface called [`SpiInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/SpiInterface-class.html).
