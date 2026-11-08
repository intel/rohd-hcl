# Priority Encoder

A priority encoder finds the least-significant `1` in a `Logic` input, or
equivalently counts its trailing zeros. It returns the position from the LSB.
Set `generateValid: true` to expose `valid`, which is high when a bit is set.
Use `valid` to distinguish a match from an all-zero input rather than relying on
a particular no-match index across implementations.

## Parallel-Prefix Priority Encoder

We provide one implementation based on `ParallelPrefix` trees, which finds the
trailing-1 position using a prefix-tree and then encodes that position.  This
`ParallelPrefixPriorityEncoder` allows you to select the prefix-tree of your
choice to use in the find position portion, which is followed by a
`OneHotToBinary` module to encode that position.

```dart
    final bitVector = Logic(width: 5);
    // ignore: cascade_invocations
    bitVector.put(8);
    final encoder = ParallelPrefixPriorityEncoder(bitVector,
        ppGen: BrentKung.new, generateValid: true);
    final valid = encoder.valid!;
    // encoder.out.value.toInt() will be 3 and valid.value.toBool() will be true
```

## Recursive Priority Encoder

We provide a more direct encoding implementation that builds up the trailing-1
position using a binary recursion tree.  There are two flavors of this
implementation: `RecursivePriorityEncoder` is a straight recursion that builds
up the binary tree construction using straightforward logic, whereas
`RecursiveModulePriorityEncoder` uses the same algorithm, but produces a
`Module` for each node of the tree (this results in more readable output
Verilog).

```dart
    final bitVector = Logic(width: 5);
    // ignore: cascade_invocations
    bitVector.put(8);
    final encoder = RecursiveModulePriorityEncoder(bitVector, generateValid: true);
    final valid = encoder.valid!;
    // encoder.out.value.toInt() will be 3 and valid.value.toBool() will be true
  ```
