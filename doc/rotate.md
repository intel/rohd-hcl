# Rotate

ROHD HCL comes with a variety of utilities for performing rotations across

- Direction (Left and Right)
- Amount (Dynamic and Fixed), and
- Type (`Logic` and `LogicValue`)

## Synthesizable Rotation

The synthesizable rotate modules accept two inputs: the `original` signal and the `rotateAmount`.

If you want to rotate a signal by a fixed amount, you can use the "fixed" rotation modules: [`RotateLeftFixed`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLeftFixed-class.html) and [`RotateRightFixed`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateRightFixed-class.html).  These will be implemented as a simple signal swizzle (no added gates or logic).

If you want to rotate by a dynamic amount controlled by another signal, you can use the non-fixed rotation modules: [`RotateLeft`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLeft-class.html) and [`RotateRight`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateRight-class.html).  These are implemented as a case statement with a static swizzle per matching rotate amount.  Use the `maxAmount` argument to limit the amount of hardware generated in case you know the `rotateAmount` will never be greater than a certain value.

Instantiating these synthesizable modules looks similar for all four.  An example is shown below creating a dynamic rotate left module that rotates a 16-bit signal by an 8-bit value which is guaranteed to never be larger than 10.

```dart
final original = Logic(width: 16);
final rotateAmount = Logic(width: 8);
final mod = RotateLeft(original, rotateAmount, maxAmount: 10);
final rotated = mod.rotated;
```

A set of convenient `extension`s are provided on top of `Logic` to more easily rotate signals with a simpler API: [`rotateLeft`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogic/rotateLeft.html) and [`rotateRight`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogic/rotateRight.html).  These methods construct the same underlying modules, but based on the type of `rotateAmount` (`int` vs `Logic`) will decide whether to use a "fixed" or "non-fixed" implementation.

```dart
final original = Logic(width: 16);
final rotateAmount = Logic(width: 8);
final rotated = original.rotateLeft(rotateAmount, maxAmount: 10);
```

## On `LogicValue`s

Also included are `extension`s for `LogicValue` with a similar rotation API for values: [`rotateLeft`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogicValue/rotateLeft.html) and [`rotateRight`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogicValue/rotateRight.html).  These are for non-synthesizable value manipulation.

```dart
LogicValue.ofInt(0xf000, 16).rotateLeft(8); // results in 0x00f0
```
