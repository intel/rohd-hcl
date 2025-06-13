# Standard Interfaces

ROHD-HCL provides a set of standard interfaces using ROHD `Interface`s.  This makes it easy to instantiate and connect common interfaces in a configurable way.

## APB

The [ABP Interface](https://developer.arm.com/documentation/ihi0024/latest/) is a standard AMBA interface.  ROHD HCL has a configurable version of the APB interface called [`ApbInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/ApbInterface-class.html).

## SPI

The Serial Peripheral Interface (SPI) is a common serial communicaton interface. ROHD HCL has a configurable version of the SPI interface called [`SpiInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/SpiInterface-class.html).
