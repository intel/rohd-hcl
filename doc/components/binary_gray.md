# Binary Gray

ROHD-HCL provides a module to perform conversion on binary to gray and gray to binary.

## Binary-to-Gray

A fundamental digital logic operation known as binary to gray code conversion is employed in many different applications, notably in digital communication and signal processing systems. Gray code is a binary numbering system that is useful for minimizing communication channel faults because adjacent values only differ in one bit. This conversion algorithm converts a binary value into its equivalent Gray code representation from the input binary value. Each bit in the binary input is XORed with the bit before it to produce the Gray code. In order to reduce errors during signal transmission or processing, the transition between consecutive values must be as smooth as feasible in applications like rotary encoders, error correction, and circuit design.

The `BinaryToGrayConverter` module in ROHD-HCL accept a single input `binary` to be converted to gray of type `Logic`. The output value can be access via the getter `grayCode`.

An example is shown below to convert binary to gray code.

```dart
final binaryInput = Logic(name: 'binaryInput', width: 3)..put(bin('111'));
final binToGray = BinaryToGrayConverter(binaryInput);
await binToGray.build();

print(binToGray.grayCode.value.toString(includeWidth: false)); // output: 100
```

## Gray-to-Binary

The conversion of gray to binary code is an essential process in digital logic and communication systems. A binary numbering system called gray code is appropriate for use in applications where error reduction is crucial because adjacent values only differ by one bit. This conversion algorithm converts a Gray code value into its corresponding binary representation from the input. This is accomplished by computing the equivalent binary bit by XOR operations with the preceding bit after examining each bit in the Gray code, starting with the least significant bit. In many different domains, such as rotary encoders, digital signal processing, and error correction systems, it is necessary to extract precise binary representations from Gray code inputs. These applications include Gray to Binary Code Conversion.

The `GrayToBinary` module in ROHD-HCL accept a single input `gray` to be converted to binary of type `Logic`. The output value can be access via the getter `binaryVal`.

An example is shown below to convert gray code to binary value.

```dart
final graycode = Logic(name: 'grayCode', width: 3)..put(bin('100'));
final grayToBin = GrayToBinaryConverter(graycode);
await grayToBin.build();

print(grayToBin.binaryVal.value.toString(includeWidth: false)); // output: 111
```
