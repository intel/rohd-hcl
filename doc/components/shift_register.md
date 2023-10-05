# Shift Register

The `ShiftRegister` in ROHD HCL is a configurable shift register including:

- support for any width data
- a configurable `depth` (which corresponds to the latency)
- an optional `enable`
- an optional `reset`
- if `reset` is provided, an optional `resetValue`
- access to each of the `stages` output from each flop
