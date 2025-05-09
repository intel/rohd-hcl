# Reduction Tree

The `ReductionTree` component is a general tree generator that allows for arbitrary radix or tree-branching factor in the computation.  It takes a sequence of `Logic` values and performs a specified operation at each node of the tree, taking in 'radix' inputs and producing one output.  If the operation widens the output (say in addition), then the `ReductionTree` will widen values using either sign-extension or zero-extension as specified.

The input sequence is provided in the form 'List\<Logic\>'.  The operation must be provided in the form:

 ```dart
 Logic Function(List<Logic> operands, {String name})
 ```

 This function should support operand lengths between $[2,radix]$ if the tree is to support an arbitrary length sequence: Note that the `ReductionTree` itself does not require the sequence length to be a power of the radix; it will use shorter operations to balance the tree when the sequence length is not a power of the radix.

The resulting tree can be pipelined by specifying the depth of nodes before a pipestage is added.  Since the input can be of arbitrary length, paths in the tree may not be balanced, and extra pipestages will be added in shorter sections of the tree to align the computation.

Here is an example radix-4 computation tree using native addition on 79 13-bit inputs, pipelining every 2 operations deep, and producing a single 13-bit result.

```dart
  Logic addReduce(List<Logic> inputs, {String name = 'native'}) {
    final a = inputs.reduce((v, e) => v + e);
    return a;
  }
  /// Tree reduction using addReduce
    const width = 13;
    const length = 79;
    final vec = <Logic>[];

    final reductionTree = ReductionTree(
        vec, radix: 4, addReduce, clk: clk, depthToFlop; 2);
  ```

Here is the same example radix-4 computation tree but using prefix adders on 79 13-bit inputs, pipelining every 2 operations deep, and producing a single 21-bit result, due to width-extension of the prefix adder, adding 1 bit for each addition in 7 levels of the tree.

  ```dart
Logic addReduceAdders(List<Logic> inputs, {String name = 'prefix'}) {
  if (inputs.length < 4) {
    return inputs.reduce((v, e) => v + e);
  } else {
    final add0 =
        ParallelPrefixAdder(inputs[0], inputs[1], name: '${name}_add0');
    final add1 =
        ParallelPrefixAdder(inputs[2], inputs[3], name: '${name}_add1');
    final addf = ParallelPrefixAdder(add0.sum, add1.sum, name: '${name}_addf');
    return addf.sum;
  }
}

  /// Tree reduction using addReduceWithAdders
    const width = 13;
    const length = 79;
    final vec = <Logic>[];

    final reductionTree = ReductionTree(
        vec, radix: 4, addReduceWithAdders, clk: clk, depthToFlop; 2, signExtend: true);
  ```
