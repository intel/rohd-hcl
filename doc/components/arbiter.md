# Arbiters

ROHD HCL implements a generic `abstract` [`Arbiter`](https://intel.github.io/rohd-hcl/rohd_hcl/Arbiter-class.html) class that other arbiters can extend.  It accepts a `List` of `requests`, where each request is a `1-bit` signal indicating that there is a request for a resource.  The output `grants` is a `List` where each element corresponds to the request with the same index.  The arbiter implementation decides how to select which request receives a grant.

## Stateful Arbiter

A `StatefulArbiter` is an `Arbiter` which can hold state, and thus requires a `clk` and `reset`.

## Priority Arbiter

The [`PriorityArbiter`](https://intel.github.io/rohd-hcl/rohd_hcl/PriorityArbiter-class.html) is a combinational (stateless) arbiter that always grants to the lowest-indexed request.

[PriorityArbiter Schematic](https://intel.github.io/rohd-hcl/PriorityArbiter.html)

## Round Robin Arbiter

The `RoundRobinArbiter` is a `StatefulArbiter` which grants requests in a "fair" way so that all requestors get equal access to grants.  There are two implementations available for `RoundRobinArbiter`:

- `MaskRoundRobinArbiter` is the default implementation if you create a `RoundRobinArbiter`.  It uses internal request and grant masks to store state for fair arbitration.
- `RotateRoundRobinArbiter` is an alternative implementation which uses a `PriorityArbiter` and two rotators controlled by a last-granted state.
