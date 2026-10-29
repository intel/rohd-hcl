# Standard Interfaces

ROHD-HCL provides a set of standard interfaces using ROHD `Interface`s.  This makes it easy to instantiate and connect common interfaces in a configurable way.

## Module Registration Helpers

Register interfaces on a module with ROHD's `Module` registration methods
rather than calling `connectIO` or `pairConnectIO` directly:

- `addInterfacePorts` clones an `Interface`, registers selected tag directions, and
  returns the module-local clone.
- `addPairInterfacePorts` does the same for a selected `PairRole`.
- `addInterfaceFrom` and `addPairInterfaceFrom` register an intentionally
  different concrete target against a source and return that target.
  Ready/valid retyping accepts a width-compatible plain packed payload bridge
  and rejects mismatched widths or incompatible declared structures.

These methods preserve specialized `connectIO` behavior, including typed
ready/valid payload ports, and keep module code independent of how interface
ports are laid out.

## Modeling Versus RTL

The interfaces above are synthesizable RTL. Some components also have
non-synthesizable software or SystemC models for simulation and verification.
Those are separate from the RTL and are opt-in. See
[Behavioral Models](./behavioral_models.md) for when to use each form.

## APB

The [ABP Interface](https://developer.arm.com/documentation/ihi0024/latest/) is a standard AMBA interface.  ROHD HCL has a configurable version of the APB interface called [`ApbInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/ApbInterface-class.html).

## SPI

The Serial Peripheral Interface (SPI) is a common serial communicaton interface. ROHD HCL has a configurable version of the SPI interface called [`SpiInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/SpiInterface-class.html).
