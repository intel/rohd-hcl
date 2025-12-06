# Summation

ROHD-HCL comes with combinational and sequential components for summing any number of input values, including support for increment/decrement and saturation/roll-over behavior.

## SumInterface

The `SumInterface` is shared between [`Sum`](#sum) and [`Counter`](#counter) components and represents a single element to be summed. Each instance of a `SumInterface` has an associated `amount`, which could either be a fixed constant value (`fixedAmount`) or a dynamic `Logic`. Fixed amounts will do some automatic width inference, unless a `width` is specified. The interface can also optionally include an enable signal. It is implemented as a `PairInterface` where all ports are `fromProvider`. Each interface may be either incrementing or decrementing.

```dart
// An interface with a dynamic 4-bit amount to increment by
SumInterface(width: 4);
```

## Sum

The `Sum` component takes a list of `SumInterface`s and adds them all up. The `saturates` configuration enables saturation behavior, otherwise there will be roll-over at overflow/underflow of the counter at `minValue` and `maxValue`. The sum can also be given an `initialValue` to start at.

Internally, the `Sum` component builds a wider bus which is large enough to hold the biggest possible intermediate value during summation before consideration of overflow and saturation.

Note that the implementation's size and complexity when synthesized depend significantly on the configuration. For example, if everything is a nice power-of-2 number, then the logic is much simpler than otherwise where hardware modulos may be required to properly handle roll-over/under scenarios.

A simpler `Sum.ofLogics` constructor has less configurability, but can be passed a simple `List<Logic>` without needing to construct per-element interfaces.

```dart
// An 8-bit sum of a list of `SumInterface`s
Sum(intfs, width: 8);
```

## Counter

The `Counter` component is a similarly configurable version of the `Sum` which maintains a sequential element to store the previous value.

One additional nice feature of the `Counter` is that it supports a `restart` in addition to the normal `reset`. While `reset` will reset the internal flops, `restart` will re-initialize the internal `Sum` back to the reset value, but still perform the computation on inputs in the current cycle. This is especially useful in case you want to restart a counter while events worth counting may still be occuring.

The `Counter` also has a `Counter.simple` constructor which is intended for very basic scenarios like "count up by 1 each cycle".

The `Counter` also has a `Counter.upDown` constructor which is intended for increment/decrement use cases like crediting.

```dart
// A counter which increments by 1 each cycle up to 5, then rolls over.
Counter.simple(clk: clk, reset: reset, maxValue: 5);
```

## Gated Counter

The `GatedCounter` is a version of a `Counter` which contains a number of power-saving features including clock gating to save on flop power and enable gating to avoid unnecessary combinational toggles.

The `GatedCounter` has a `clkGatePartitionIndex` which determines a dividing line for the counter to be clock gated such that flops at or above that index will be independently clock gated from the flops below that index. This is an effective method of saving extra power on many counters because the upper bits of the counter may change much less frequently than the lower bits (or vice versa).  If the index is negative or greater than or equal to the width of the counter, then the whole counter will be clock gated in unison.

The `gateToggles` flag will enable `ToggleGate` insertion on a per-interface basis to help reduce combinational toggles within the design when interfaces are not enabled.
