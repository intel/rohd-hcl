# Edge Detection

The `EdgeDetector` is a simple utility to determine whether the current value of a 1-bit signal is different from the value in the previous cycle.  It is a fully synchronous design, so it does not asynchronously detect edges.  It optionally supports a reset, with an optional reset value.  Furthermore, it can be configured to detect positive, negative, or "any" edges.
