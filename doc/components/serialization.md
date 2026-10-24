# Serialization / Deserialization

ROHD-HCL implements a `Serializer` and `Deserializer` set of components that enable converting wide structures to a serialized narrow stream of data and vice-versa.

## Typed arrays and dimensions

Both components support `TypedLogicArray<T, V>`, where `T extends Logic` is the
hardware leaf type and `V` is its semantic value type. Leaves can be plain
`Logic`, `LogicEnum`, or a custom `LogicStructure` with a type-preserving
`clone`. `LogicArray` remains a supported input as the ordinary
`TypedLogicArray<Logic, LogicValue>` specialization.

Serialization removes **only the outermost dimension**. An input shaped
`[10, 2, 3]` emits ten `[2, 3]` slices with the same typed leaves and codec.
Deserializing those slices with length 10 reconstructs `[10, 2, 3]`. No
repackaging into a one-dimensional array is required.

Both `Serializer<T, V>.serialized` and `Deserializer<T, V>.deserialized` are
statically typed as `TypedLogicArray<T, V>`. A one-dimensional serializer
input produces a **rank-zero** output with dimensions `[]`; use
`serializer.serialized.scalar` (or `.at([])`) to access the leaf as `T`.
Multidimensional inputs produce array slices, with no cast required.
Specify the deserializer's leaf type explicitly for custom or enum leaves;
its input can be either that leaf or an array slice, including a rank-zero
array. Deserializing a rank-zero input produces shape `[length]`.

Deserialization requires a `valueCodec` for each leaf, not for an entire
slice. Pass the source array's `valueCodec` when reconstructing a transfer,
or `LogicValueCodec.logicValue` when using packed `LogicValue` semantics.
Existing plain-logic deserializer calls must add
`valueCodec: LogicValueCodec.logicValue`; transfer timing is unchanged.

For example, with `clk` and `reset` supplied by the surrounding design:

```dart
enum Phase { idle, busy, done }

final phases = TypedLogicArray<LogicEnum<Phase>, LogicValue>(
  [4, 2],
  ({name}) => LogicEnum(Phase.values, name: name),
);
final serializer = Serializer(phases, clk: clk, reset: reset);
final deserializer = Deserializer<LogicEnum<Phase>, LogicValue>(
  serializer.serialized,
  4,
  valueCodec: phases.valueCodec,
  clk: clk,
  reset: reset,
);
// Each transfer is a [2] slice; the aggregate has dimensions [4, 2].
final LogicEnum<Phase> first = deserializer.deserialized.at([0, 0]);
```

Ports, buffered inputs, and selected slices retain their hardware structure.
Dimension sizes and the deserializer length must be positive. The serializer
requires at least one input axis to remove; the deserializer accepts rank zero.

## Serializer

The `Serializer` is a module that accepts a wider `LogicArray` `deserialized` for input data and optionally a `Logic` `enable` to allow for pausing serialization. While `enable` is high, the `Serializer` sequentially outputs chunks of data on the Logic `serialized` output until the entire `LogicArray` `deserialized` has been transferred to the output.  At that point the `Serializer` raises Logic `done`.  This process will continue until the Logic `enable` is lowered, allowing for back-to-back transfers of wide data over the Logic `serialized` stream. Alternatively, an optional input `endCount` can cause serialization to be halted earlier than the number of steps implied by the width of the `deserialized` input array. The semantics of `endCount` are that serialization will drive the `done` output on the ith step where i==`endCount`. The number of serialization steps in the current transfer is available in Logic `count`. Lowering `enable` will pause the transfer and raising it will continue from where it paused.

## Deserializer

The `Deserializer` is a module that accepts a `Logic` `serialized` stream over a pre-defined `length` number of clocks.  It outputs a `LogicArray` `deserialized` of the same length of Logic words that match the width of Logic `serialized`.  Deserialization runs while Logic `enable` is high, and Logic `done` is emitted when deserialization is complete. This process will continue when Logic `enable` is high, allowing for back-to-back deserialization transfers of a narrow stream of data into wider (`length`) `LogicArray`s during `length` number of serialization steps (clocks while `enable` is high) for each transfer. Alternatively, the optional input `last` allows for earlier termination of deserialization (i.e., driving of the `done` output) meaning only the first n elements in the `deserialized` output array will contain meaningful data from the given transfer where n is the number of cycles up to the point at which `last` was driven. The number of serialization steps in the current transfer is available in Logic `count`.  Lowering `enable` will pause the transfer and raising it will continue from where it paused.
