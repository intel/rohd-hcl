# Extrema

ROHD-HCL provides a component to find the extrema of a list of Logic.

The component `Extrema` will determine the extremas (maximum or minimum) and their position in a list of [`Logic`]s. 

## Description

`Extrema` will take in an input containing a `List<Logic>` along with parameters for `max` and `first`.

* `max` is a boolean indicating whether to find the maximum value (`true`), or the minimum value (`false`). Default is `true`.

* `first` is a boolean indicating whether to find the first instance of the extrema (`true`), or the last instance (`false`). Default is `true`.

`Extrema` will then ouput two `Logic` signals:
* `index` The index or position of the extrema in the list
  >`index` will be a `Logic` with the smallest width needed to represent the largest possible index in the list.

* `val` The value of the extrema.
  >`val` will be a `Logic` with a width equal to the largest width of any element in the list.

The `List<Logic>` may contain `Logic`s of any width. They will all be considered positive unsigned numbers. 

`Extrema` will throw an exception if the `Logic` list is empty or has an empty element.

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

    // Create an Extrema module to find the last minimum value.
    final lastMin = Extrema(signals, max: false, first: false);
    await lastMin.build();
    // Create an Extrema module to find the first maximum value.
    final firstMax = Extrema(signals);
    await firstMax.build();

    // Assign the integer representation of the value of the index to a variable.
    final x = firstMax.index.value.toInt();
    print('x equals firstMax index: $x');

    // print the index and value of the last minimum
    print('lastMin index: ${lastMin.index}');
    print('lastMin value: ${lastMin.val}');

    // print the index and value of the last minimum as values
    print('lastMin index as a value: ${lastMin.index.value}');
    print('lastMin value as a value: ${lastMin.val.value}');

    // print the index and value of the first maximum as values
    print('firstMax index as a value: ${firstMax.index.value}');
    print('firstMax val as a value: ${firstMax.val.value}');
}
```
Console output:

```console
x equals firstMax index: 1
lastMin index: Logic(3): index
lastMin value: Logic(8): val
lastMin index as a value: 3'h4
lastMin value as a value: 8'h1
firstMax index as a value: 3'h1
firstMax val as a value: 8'hd
```
