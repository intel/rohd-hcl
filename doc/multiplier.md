# Multiplier

ROHD HCL provides a multiplier module to get the product from a list of logic. As of now, we have

- [Carry Save Multiplier](#carry-save-multiplier)

## Carry Save Multiplier

Carry save multiplier is a digital circuit used for performing multiplication operations. It is particularly useful in applications that require high speed multip0lication, such as digital signal processing.

The [`CarrySaveMultiplier`](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySaveMultiplier-class.html) module in ROHD-HCl accept four inputs: the clock `clk` signal, reset `reset` signal, a List of Logic()'s `toMultiply` and the name of the module `name`. Note that `toMultiply` must have inputs of two and width of the inputs must be the same or `RohdHclException()` will be thrown.

An example is shown below to multiply two inputs of signals that have 8-bits of width.

```dart
const dataWidth = 8;
final clk = SimpleClockGenerator(10).clk;
final reset = Logic(name: 'reset');
final a = Logic(name: 'a', width: dataWidth);
final b = Logic(name: 'b', width: dataWidth);

final multiply = CarrySaveMultiplier(clk, reset, toMultiply: [a, b], name: 'csm_module');
await multiply.build()
```
