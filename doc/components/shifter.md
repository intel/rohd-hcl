# Shifter

ROHD-HCL provides a component to perform shifting of a Logic based on an input Logic treated as signed.

## SignedShifter

The `SignedShifter` takes as input a Logic $shift$ and interprets $shift > 0$ as left-shift by the magnitude of $shift$ and right-shift by the magnitude of $shift$ if $shift < 0$.

```dart
   final bits = Const(16, width: 8);
   print(bits.value.toRadixString());
   // Produces: 16'b1_0000
   final shift = Logic(width: 3);
   final shifter = SignedShifter(bits, shift);

   shift.put(-1);
   print(shifter.shifted.value.toRadixString());
   // Produces:   16'b1000
   ```