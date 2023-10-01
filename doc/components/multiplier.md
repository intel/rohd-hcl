# Multiplier

ROHD HCL provides a multiplier module to get the product from a list of logic. As of now, we have

- [Carry Save Multiplier](#carry-save-multiplier)

## Carry Save Multiplier

Carry save multiplier is a digital circuit used for performing multiplication operations. It is particularly useful in applications that require high speed multiplication, such as digital signal processing.

The [`CarrySaveMultiplier`](https://intel.github.io/rohd-hcl/rohd_hcl/CarrySaveMultiplier-class.html) module in ROHD-HCL accept input parameters the clock `clk` signal, reset `reset` signal, `Logic`s' a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or `RohdHclException` will be thrown.

An example is shown below to multiply two inputs of signals that have 4-bits of width.

```dart
const widthLength = 4;
final a = Logic(name: 'a', width: widthLength);
final b = Logic(name: 'b', width: widthLength);
final reset = Logic(name: 'reset');
final clk = SimpleClockGenerator(10).clk;

final csm = CarrySaveMultiplier(clk: clk, reset: reset, a, b);

await csm.build();

reset.inject(0);

Simulator.setMaxSimTime(10000);

unawaited(Simulator.run());

Future<void> waitCycles(int numCycles) async {
    for (var i = 0; i < numCycles; i++) {
        await clk.nextPosedge;
    }
}

a.put(10);
b.put(3);

await waitCycles(csm.latency).then(
    (value) {
        print(csm.product.value.toInt());
    },
);

Simulator.endSimulation();
```
