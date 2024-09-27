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

```dart
// A counter which increments by 1 each cycle up to 5, then rolls over.
Counter.simple(clk: clk, reset: reset, maxValue: 5);
```

## Gated Counter

The `GatedCounter` is a version of a `Counter` which contains a number of power-saving features including clock gating to save on flop power and enable gating to avoid unnecessary combinational toggles.

Rules:

- For determining if a portion of the flops should be enabled:
  - Summary rule is: if the counter *may* change to impact those flops, enable them. Else, disable them.
  - Basic rules:
    - We round estimate numbers to powers of 2 so that we can check bits instead of using comparators
    - Lower enable
      - If any (enabled) interfaces have any 1's in any lower bits, enable
    - Upper enable
      - If any (enabled) interfaces have any 1's in any upper bits, enable
      - For INCREMENTs
        - If current count has 1's in a "range" of uppermost lower bits, AND
        - If any (enabled) interfaces have 1's in a "range" of uppermost lower bits, enable
      - For DECREMENTs
        - If current count has no 1's in a "range" of uppermost lower bits, AND
        - If the lower bits are "close enough" to 0 (to cause decrement on upper bits), enable
  - Special considerations:
    - Overflow: if the counter may overflow, enable lower bound bits
    - Underflow: if the counter may underflow, enable upper bits
    - Saturation: if a counter saturates, then overflow/underflow cannot occur, so don't consider it
    - Max value: if the max value prevents upper bits from ever toggling, then don't even generate the flop, tie to 0
    - Min value: there are only clever things here in really weird cases, don't optimize for it (e.g. max == min)
  - Blanket cases:
    - If all interfaces are not enabled, GATE ALL
    - If all interfaces have 0 on them, GATE ALL
    - If restarting, UNGATE ALL
- For selecting a boundary
  - Optional: accept a provided number for where to draw the boundary
  - Consider the maximum magnitude of interfaces (incr and decr separately), and draw the partition some number of bits away from that number, so that the percentage of time that clocks are enabled is relatively low if the increment amount was full every time (e.g. 4 bits would be 1/16th of the time enabled).
