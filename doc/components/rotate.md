# Rotate

ROHD-HCL comes with a variety of utilities for performing rotations across

- Direction (Left and Right)
- Amount (Dynamic and Fixed), and
- Type (`Logic` and `LogicValue`)

## Synthesizable Rotation

The synthesizable rotate modules accept two inputs: the `original` signal and the `rotateAmount`.

A set of convenient `extension`s are provided on top of `Logic` to easily rotate signals with a simple API: [`rotateLeft`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogic/rotateLeft.html) and [`rotateRight`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogic/rotateRight.html).  These methods construct the underlying modules automatically for you.

An example is shown below creating a dynamic "non-fixed" rotate left module that rotates a 16-bit signal by an 8-bit value which is guaranteed to never be larger than 10.

```dart
final original = Logic(width: 16);
final rotateAmount = Logic(width: 8);
final rotated = original.rotateLeft(rotateAmount, maxAmount: 10);
```

Here's another example with "fixed" rotation to the right by 3:

```dart
final original = Logic(width: 16);
final rotateAmount = 3;
final rotated = original.rotateRight(rotateAmount);
```

### Rotation Amount Type

Based on the type of `rotateAmount` (`int` vs `Logic`), this API will decide whether to use a "fixed" or "non-fixed" implementation.

A "fixed" implementation will be implemented as a simple signal swizzle (no added gates or logic).

A "non-fixed" version is implemented as a case statement with a static swizzle per matching rotate amount.  For a "non-fixed" rotation, use the `maxAmount` argument to limit the amount of hardware generated in case you know the `rotateAmount` will never be greater than a certain value.

### Module Types

Rotations are also accessible via `Module` construction instead of `extension`s, if preferred.

If you want to rotate a signal by a fixed amount, you can use the "fixed" rotation modules: [`RotateLeftFixed`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLeftFixed-class.html) and [`RotateRightFixed`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateRightFixed-class.html).

If you want to rotate by a dynamic amount controlled by another signal, you can use the "non-fixed" rotation modules: [`RotateLeft`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLeft-class.html) and [`RotateRight`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateRight-class.html).

Instantiating these synthesizable modules looks similar for all four rotation combinations.

```dart
final original = Logic(width: 16);
final rotateAmount = Logic(width: 8);
final mod = RotateLeft(original, rotateAmount, maxAmount: 10);
final rotated = mod.rotated;
```

## On `LogicValue`s

Also included are `extension`s for `LogicValue` with a similar rotation API for values: [`rotateLeft`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogicValue/rotateLeft.html) and [`rotateRight`](https://intel.github.io/rohd-hcl/rohd_hcl/RotateLogicValue/rotateRight.html).  These are for non-synthesizable value manipulation.

```dart
LogicValue.ofInt(0xf000, 16).rotateLeft(8); // results in 0x00f0
```

<!-- [Rotate Right Schematic](https://intel.github.io/rohd-hcl/RotateRight.html) -->
