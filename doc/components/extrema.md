# Extrema

ROHD-HCL provides a component to find the extrema of a list of Logic.

The component `Extrema` will determine an extrema (maximum or minimum) and their position in a list of `Logic`s.

## Description

`Extrema` will take in an input containing a `List<Logic>` along with a parameter `max`.

* `max` is a boolean indicating whether to find the maximum value (`true`), or the minimum value (`false`). Default is `true`.

`Extrema` will then ouput two `Logic` signals:

* `index` The index or position of the first extrema in the list.

  * `index` will be a `Logic` with the smallest width needed to represent the largest possible index in the list.

  * If multiple instances of the same extrema exists in the list, the index of the first instance will be returned.

* `val` The value of the extrema.

  * `val` will be a `Logic` with a width equal to the largest width of any element in the list.

The `List<Logic>` may contain `Logic`s of any width. They will all be considered positive unsigned numbers.

`Extrema` will throw an exception if the `Logic` list is empty.

## Example Usage

Dart code:

```dart
void main() {
  // Example list of Logic signals.
     final signals = [
      Logic(width: 8)..put(LogicValue.of([LogicValue.one, LogicValue.zero])), //0b10
      Logic(width: 4)..put(LogicValue.ofInt(13, 4)), //0xD
      Logic()..put(LogicValue.one), //0b1
      Logic(width: 8)..put(LogicValue.ofString('00001101')), // 0xD
      Logic(width: 4)..put(LogicValue.ofString('0001')), //0b1
    ];

    // Create an Extrema module to find the minimum value.
    final findMin = Extrema(signals, max: false);
    await findMin.build();
    // Create an Extrema module to find the first maximum value.
    final findMax = Extrema(signals);
    await findMax.build();

    // Assign the integer representation of the value of the index to a variable.
    final x = findMax.index.value.toInt();
    print('x equals findMax index: $x');

    // print the index and value of the minimum as values
    print('findMin index as a value: ${findMin.index.value}');
    print('findMin value as a value: ${findMin.val.value}');

    // print the index and value of the maximum as values
    print('findMax index as a value: ${findMax.index.value}');
    print('findMax val as a value: ${findMax.val.value}');
}
```

Console output:

```console
x equals findMax index: 1
findMin index as a value: 3'h2
findMin value as a value: 8'h1
findMax index as a value: 3'h1
findMax val as a value: 8'hd
```
