# Binary Gray

ROHD-HCL provides a module to perform conversion on binary to gray and gray to
binary.

## Binary-to-Gray

A fundamental digital logic operation known as binary to gray code conversion is
employed in many different applications, notably in digital communication and
signal processing systems. Gray code is a binary numbering system that is useful
for minimizing communication channel faults because adjacent values only differ
in one bit. This conversion algorithm converts a binary value into its
equivalent Gray code representation from the input binary value. Each bit in the
binary input is XORed with the bit before it to produce the Gray code. In order
to reduce errors during signal transmission or processing, the transition
between consecutive values must be as smooth as feasible in applications like
rotary encoders, error correction, and circuit design.

The `BinaryToGrayConverter` module accepts a `Logic` input and exposes the
result through `gray`.

An example is shown below to convert binary to gray code.

```dart
final binaryInput = Logic(name: 'binaryInput', width: 3)..put(bin('111'));
final binToGray = BinaryToGrayConverter(binaryInput);
await binToGray.build();

print(binToGray.gray.value.toString(includeWidth: false)); // output: 100
```

## Gray-to-Binary

Gray-to-binary conversion recovers the binary representation by XORing each Gray
bit with the more-significant decoded bits, starting at the most significant
end.

The `GrayToBinaryConverter` module accepts a `Logic` input and exposes the
result through `binary`. By default it uses the original linear XOR chain.
Pass `ppGen`, such as `BrentKung.new`, to opt into a parallel-prefix XOR
network; topology cost and timing depend on the target technology.

An example is shown below to convert gray code to binary value.

```dart
final graycode = Logic(name: 'grayCode', width: 3)..put(bin('100'));
final grayToBin = GrayToBinaryConverter(graycode);
await grayToBin.build();

print(grayToBin.binary.value.toString(includeWidth: false)); // output: 111
```
## Thermometer conversion

`BinaryToThermometer` converts an unsigned count to contiguous low-order ones,
saturating at the output width and asserting `overflow` for larger inputs.
`ThermometerToBinary` counts set bits and reports `valid` only when those bits
are contiguous from bit zero. For an invalid input its binary output is still
the population count.
