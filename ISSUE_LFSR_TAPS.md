# Feature request: Simple tap-list LFSR API

**Draft superseded:** This API is being implemented in the current branch; no separate follow-up issue is needed if it merges with #328.

## Motivation

The LFSRs added in #328 use a polynomial-based `LfsrDescriptor`. A direct tap-list API would make common LFSR configurations easier to use without requiring callers to construct polynomial descriptors.

This follows the tap-list request discussed in #8, which is being closed for the original LFSR implementation. A contributor has expressed interest in this simpler API.

## Desired solution

Provide a synthesizable LFSR API configured by state width and feedback taps, supporting one or more steps per enabled clock cycle. Reuse or extend the existing LFSR components where practical.

An illustrative API is:

```dart
class Lfsr extends Module {
  Lfsr({
    required Logic clk,
    required int stateWidth,
    required List<int> feedbackTaps,
    int stepsPerCycle = 1,
    Logic? reset,
    Logic? enable,
    Logic? load,
    Logic? loadState,
    BigInt? initialState,
    bool asyncReset = false,
    super.name = 'lfsr',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  });

  Logic get state;
  Logic get dataOut;
}
```

Define and document the tap numbering, shift direction, feedback equation, output ordering, valid tap values, and reset, enable, and load behavior. Include tests for known sequences, multiple steps per cycle, controls, invalid configurations, and generated RTL.

## Alternatives considered

Continue using `SerialLfsr` and `ParallelLfsr` with `LfsrDescriptor` and a polynomial. A tap-list convenience constructor or adapter around those components may also satisfy this request.

## Additional details

The existing descriptor-based LFSRs are right-shifting Fibonacci implementations. State bit zero is emitted first, and parallel output packs the earliest bit in bit zero.

Tap numbering needs a decision: the discussion in #8 asked whether taps should use zero-based state-bit indices or the one-based numbering commonly used in tap tables. Document examples so users can map published polynomials or tap tables to the chosen convention.
