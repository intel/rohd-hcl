# Priority Encoder

A priority encoder is used to find the trailing `1` in a Logic (or, equivalently, count the number of trailing 0s). In ROHD HCL, our `PriorityEncoder` abstract class searches from the LSB to find the leading-1, returning the index of its position from the LSB. If there is no `1` in the Logic, it returns 1 past the width of the Logic.  Additionally, if `outputValid` is set to true, then a `valid` output is produced and will be set to `1` if a trailing-1 is found, otherwise `0`.

## Parallel-Prefix Priority Encoder

We provide one implementation based on `ParallelPrefix` trees, which finds the trailing-1 position using a prefix-tree and then encodes that position.  This `ParallelPrefixPriorityEncoder` allows you to select the prefix-tree of your choice to use in the find position portion, which is followed by a `OneHotToBinary` module to encode that position.

```dart
    final bitVector = Logic(width: 5);
    // ignore: cascade_invocations
    bitVector.put(8);
    final encoder = ParallelPrefixPriorityEncoder(bitVector,
        ppGen: BrentKung.new, outputValid: true);
    final valid = encoder.valid!;
    // encoder.out.value.toInt() will be 3 and valid.value.toBool() will be true
```

## Recursive Priority Encoder

We provide a more direct encoding implementation that builds up the trailing-1 position using a binary recursion tree.  There are two flavors of this implementation: `RecursivePriorityEncoder` is a straight recursion that builds up the binary tree construction using straightforward logic, whereas `RecursiveModulePriorityEncoder` uses the same algorithm, but produces a `Module` for each node of the tree (this results in more readable output Verilog).

```dart
    final bitVector = Logic(width: 5);
    // ignore: cascade_invocations
    bitVector.put(8);
    final encoder = RecursiveModulePriorityEncoder(bitVector, outputValid: true);
    final valid = encoder.valid!;
    // encoder.out.value.toInt() will be 3 and valid.value.toBool() will be true
  ```
