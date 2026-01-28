# Count

A CountPattern will count the number of occurrence of a fixed-width `pattern` within a given Logic `bus`.

It takes a Binary Logic `bus` and counts the occurrences of a fixed-width `pattern` and outputs it as `count`.  `pattern` refers to the pattern to be counted in the bus. Ensure that the `pattern` width is smaller than the `bus` width. In addition, with `fromStart` which is set as `true` by default to count the pattern from the start of the `bus`. An `error` flag is added to indicate when `pattern` is not found in the `bus`.

## Implementation

To find the number of occurence `count` of a fixed-width `pattern` in a `bus`. The search direction is defined by `fromStart` argument. If `pattern` is not found in the `bus`, the `count` will be set to 0 and `error` will be set to 1. If `pattern` matches, it will be added to `count`. 

## Count Pattern from Start (Scenario 1: Present Once)

For example, if `bus` is `00111110` and `pattern` is `110`, the output `count` will return `1` as the pattern occurred once in the bus from LSB.

```dart
final bus = Const(bin('00111110'), width: 8);
final pattern = Const(bin('110'), width: 3);
final countPattern = CountPattern(bus, pattern);
 ```

## Count Pattern from Start (Scenario 2: Present More Than Once)

For example, if `bus` is `00110110` and `pattern` is `01`, the output `count` will return `2` as the pattern occurred twice in the bus from LSB.

```dart
final bus = Const(bin('00110110'), width: 8);
final pattern = Const(bin('01'), width: 2);
final countPattern = CountPattern(bus, pattern);
 ```

## Count Pattern from Start (Scenario 3: Not Present)

For example, if `bus` is `00010000` and `pattern` is `110`, the output `count` will return `0` and an error will be generated as the pattern does not exist in the bus.

```dart
final bus = Const(bin('00010000'), width: 8);
final pattern = Const(bin('110'), width: 3);
final countPattern = CountPattern(bus, pattern);
 ```

## Count Pattern from End 

For example, if `bus` is `00110111` and `pattern` is `110`, the output `count` will return `1` as the pattern occurred once from the end of the bus.

```dart
final bus = Const(bin('00110111'), width: 8);
final pattern = Const(bin('110'), width: 3);
final countPattern = CountPattern(bus, pattern, fromStart: false);
 ```