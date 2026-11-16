# SPI Gaskets

ROHD-HCL provides `TypedSpiMain` and `TypedSpiSub` endpoints for communication
via a Serial Peripheral Interface. Their transmit (`busIn`) and receive
(`busOut`) payloads can use different `Logic` types or structures. Specify
`busOutSchema` to describe the received data, including for a receive-only
subordinate. Each supplied payload must have the interface's `dataLength`.
Transmission operates on the packed bits, most significant bit first, without
semantic conversion.
Structured constant transmit inputs with driveable clones retain their type
even when widened to `Logic`.

`SpiMain` and `SpiSub` remain available as deprecated compatibility wrappers
with their original flat parallel ports and generated definition names.

## TypedSpiMain

Interacts as the provider on the `SpiInterface`.

The inputs to the `SpiMain` component are:

* `clk` => clock for synchronous logic and driving `SpiInterface.sclk`
* `reset` => asynchronous reset for the component and preparation for a transmit
  load
* `start` => to initiate a data transfer
* `busIn` => to load data to transmit

The outputs of the `SpiMain` component are:

* `busOut` => to output data received
* `done` => signals completion of a data transfer

Pulsing `reset` clears the receive shift register and prepares the next transmit
load. Hold `busIn` stable through the first falling `SpiInterface.sclk` edge:
its most significant bit drives `mosi` before the first rising edge, and the
remaining bits are captured on that rising edge. Pulsing `start` makes
`SpiInterface.csb` active and begins driving `SpiInterface.sclk`. Data shifts
out on `mosi` and in from `miso`; received data is available on `busOut`. The
`done` signal indicates when the transfer is complete.

## TypedSpiSub

Interacts as the consumer on the `SpiInterface`.

The inputs to the `SpiSub` component are:

* `reset` => optional input, asynchronous reset for the component and
  preparation for a transmit load
* `busIn` => optional input, to load data to transmit

The outputs to the `SpiSub` component are:

* `busOut` => to output data received
* `done` => signals completion of a data transfer

When both `reset` and `busIn` are provided, reset clears the receive shift
register and prepares the next transmit load. Hold `busIn` stable through the
first falling `SpiInterface.sclk` edge with `csb` active. Its most significant
bit drives `miso` before the first rising edge, and the remaining bits are
captured on that rising edge. With `csb` active, data shifts out on `miso` and
in from `mosi`; received data is available on `busOut`. The optional `done`
signal indicates when the transfer is complete. Without both `reset` and
`busIn`, no parallel transmit load is performed.
