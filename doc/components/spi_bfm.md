# SPI BFM

The SPI BFM is a collection of [ROHD-VF](https://github.com/intel/rohd-vf) components and objects that are helpful for validating hardware that contains an SPI interface.  It includes all the basic SPI interface features for sending and responding to data between a main-sub connection.

The main two components are the `SpiMainAgent` and the `SpiSubAgent`, which behave like a "Main" and "Sub" as commonly seen in SPI implementations. Both have a standard `Sequencer` that accepts `SpiPacket`s to be driven out to each other.  Both also have a corresponding `Driver` as `SpiMainDriver` and `SpiSubDriver`, respectively, that handle the driving of data onto the `SpiInterface`.

An `SpiMonitor` is also included, which implements the standard `Monitor` and provides a stream of `SpiPacket`s monitored on positive edges of the clock.  The `SpiTracker` can be used to log all items detected by the monitor by implementing the standard `Tracker` API (log file or JSON both supported).

Finally, a `SpiChecker` monitors an `SpiInterface` for a subset of the rules commonly used in SPI implementations. Errors are flagged using the `severe` log messages, as is standard for errors in ROHD-VF.

The unit tests in `spi_bfm_test.dart`, which have a main and sub communicating with each other, are a good example for setting up the SPI BFM. The unit test in `spi_gaskets_test` also have good example of the SPI BFM interacting with their corresponding hardware components.

## Unsupported features

The following features are currently not supported by or have no utilities within the BFM:

- **CPOL/CPHA**: different clock polarity and clock phase are not considered, the BFM is implemented with a SPI Mode = 0 (CPOL/CPHA = 0).
