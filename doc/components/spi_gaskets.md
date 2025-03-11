# SPI Gaskets

ROHD-HCL implements a `SpiMain` and `SpiSub` set of components that enable communication via a Serial Peripheral Interface.

## SpiMain

Interacts as the provider on the `SpiInterface`.

The inputs to the `SpiMain` component are:

* `clk` => clock for synchronous logic and driving `SpiInterface.sclk`
* `reset` => asynchronous reset for component and to reset `busIn` values
* `start` => to initiate a data transfer
* `busIn` => to load data to transmit

The outputs to the `SpiSub` component are:

* `busOut` => to output data received
* `done` => signals completion of a data transfer

When data is available on `busIn`, pulsing `reset` will load the data into the internal shift register. Pulsing `start` will make `SpiInterface.csb` active and begin driving a clock signal on `SpiInterface.sclk`. On every clock pulse data will shift out onto `SpiInterface.mosi` and shift in from `SpiInterface.miso`. Data shifted in will be avaible on `busOut`. The `done` signal will indicate when transmissions are complete.

## SpiSub

Interacts as the consumer on the `SpiInterface`.

The inputs to the `SpiSub` component are:

* `reset` => optional input, asynchronous reset for component and to reset `busIn` values
* `busIn` => optional input, to load data to transmit

The outputs to the `SpiSub` component are:

* `busOut` => to output data received
* `done` => signals completion of a data transfer

When data is available on `busIn`, pulsing `reset` will load the data into the internal shift register. When `SpiInterface.csb` is active and clock signal is present on `SpiInterface.sclk`, data will shift out onto `SpiInterface.miso` and shift in from `SpiInterface.mosi`. Data shifted in will be avaible on `busOut`. The `done` signal will indicate when transmissions are complete.
