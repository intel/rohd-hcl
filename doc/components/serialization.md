# Serialization / Deserialization

ROHD-HCL implements a `Serializer` and `Deserializer` set of components that enable converting wide structures to a serialized narrow stream of data and vice-versa.

## Serializer

The `Serializer` is a module that accepts a wider `LogicArray` `deserialized` for input data and optionally a `Logic` `readyIn` to allow for pausing serialization. While `readyIn` is high, the `Serializer` sequentially outputs chunks of data on the Logic `serialized` output until the entire `LogicArray` `deserialized` has been transferred to the output.  At that point the `Serializer` raises Logic `done`.  This process will continue until the Logic `readyIn` is lowered, allowing for back-to-back transfers of wide data over the Logic `serialized` stream. The number of serialization steps in the current transfer is available in Logic `count`. Lowering `readyIn` will pause the transfer and raising it will continue from where it paused.

## Deserializer

The `Deserializer` is a module that accepts a `Logic` `serialized` stream over a pre-defined `length` number of clocks.  It outputs a `LogicArray` `deserialized` of the same length of Logic words that match the width of Logic `serialized`.  Deserialization runs while Logic `enable` is high, and Logic `validOut` is emitted when deserialization is complete.  This process will continue when Logic `enable` is high, allowing for back-to-back deserialization transfers of a narrow stream of data into wider (`length`) `LogicArray`s during `length` number of serialization steps (clocks while `enable` is high) for each transfer.  The number of serialization steps in the current transfer is available in Logic `count`.  Lowering `enable` will pause the transfer and raising it will continue from where it paused.
