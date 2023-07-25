# Arbiters

ROHD HCL implements a generic `abstract` [`Arbiter`](https://intel.github.io/rohd-hcl/rohd_hcl/Arbiter-class.html) class that other arbiters can extend.  It accepts a `List` of `requests`, where each request is a `1-bit` signal indicating that there is a request for a resource.  The output `grants` is a `List` where each element corresponds to the request with the same index.  The arbiter implementation decides how to select which request receives a grant.

## Priority Arbiter

The [`PriorityArbiter`](https://intel.github.io/rohd-hcl/rohd_hcl/PriorityArbiter-class.html) is a combinational (stateless) arbiter that always grants to the lowest-indexed request.

[PriorityArbiter Schematic](https://intel.github.io/rohd-hcl/PriorityArbiter.html)

## Round Robin Arbiter

The Roun Robin Arbiter is a sequential (stateful) arbiter which grants requests same ways as Priority Arbiter, but keeps track of last request granted.
