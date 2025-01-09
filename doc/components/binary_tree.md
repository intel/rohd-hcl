# Binary Tree

ROHD-HCL provides a very general tree generator for reduction using two-input, one-output functions or modules arranged in a binary tree. It can provide sequential execution by flopping at a given depth of compute nodes.

The `BinaryTreeNode` class takes a `List<Logic>` and organizes a recursive binary tree construction along the first dimension.  This could be thought of ranging from as simple as a vector of Logics or as complex as a vector of sub-arrays.  An operation can be either a Function or a single output Module.
The output of the tree is the output of the final `BinaryTreeNode`.  Operand widening can occur, including sign extension if required.

The `BinaryTreeModule` class is an actual `Module` that uses the `BinaryTreeNode` generator internally, but provides the necessary input/output connectivity to feed the tree with operands and connect to other modules.

## Function Example of BinaryTree Computation

```dart
    const width = 17;
    const length = 44;
    final ary = LogicArray([length], width);
    // FIrst sum will be length *(length-1) /2
    for (var i = 0; i < length; i++) {
      ary.elements[i].put(i);
    }
    final prefixAdd = BinaryTreeModule(
        ary, (a, b) => a + b,
        clk: clk, depthToFlop: 1);
 ```

## Module Example of BinaryTree Computation

```dart
    const width = 17;
    const length = 44;
    final ary = LogicArray([length], width);
    // FIrst sum will be length *(length-1) /2
    for (var i = 0; i < length; i++) {
      ary.elements[i].put(i);
    }
    final prefixAdd = BinaryTreeModule(
        ary, (a, b) => ParallelPrefixAdder(a, b).sum,
        clk: clk, depthToFlop: 2);
 ```

## Experimental BinaryTreeNodeAry

The `BinaryTreeNodeAry` generator and its `BinaryTreeAryModule` containing module are an experiment in generalizing binary tree computation to `LogicArray`s, where the first dimension of the array is reduced in a binary tree, whereas the inner dimensions of the arrays are operated upon.

This exposes a type system issue of being able to treat `Logic` or `LogicStructure` as a 0-dimension `LogicArray` as well as how to index a `LogicArray` and get reduced dimension `LogicArray`s, as well as how to build functions that operate on `LogicArray`.

We can envision this being useful for vectorized and matrix data where type systems that organize them as `LogicArray` may reduce in more clear and crisp hardware descriptions, say for tensor operations.

If this kind of computation is useful, we can explore how to expand the capabilities of `LogicArray`, especially conversion back and forth to `LogicArray`s of different dimensions as well as to the `Logic` base structure.
