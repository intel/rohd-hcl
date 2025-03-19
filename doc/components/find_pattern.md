# Find Pattern

ROHD-HCL comes with a FindPattern.  The detailed API docs are available [here](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html).

A FindPattern will search for first/nth occurrence of a fixed-width `pattern` within a given Logic `bus`.

It takes a Binary Logic `bus` and finds the position of the desired `pattern` within the `bus`. A FindPattern function without any constructor arguments will find the first pattern from the start of the bus.
That is to say, by default a FindPattern will go for finding the first occurrence when no `n` is passed. In addition, with `fromStart` which is set as `true` by default to search for the pattern from the start of the `bus`. Both boolean `fromStart` and Logic `n` are optional. Logic `bus` and Logic `pattern` are mandatory argument.

FindPattern has an output pin named as `index`, for the index position on the occurrence searched taken from the LSB (Least Significant Bit) or MSB (Most Significant Bit) depending on the search direction defined with boolean `fromStart`.

## Implementation

To find the index of a fixed-width `pattern` in a `bus`. By default, it will find the first occurrence of the pattern from the start of the bus. The search direction is defined by `fromStart` argument. To find `index` of the second or third occurrence, define the `n` value to the desired number of occurrences.

`index` and `n` is zero-based index, where first index and first occurrence is defined `0`.

If `pattern` is not found in the `bus`, output `index` will be `0`, and if `generateError` is `true`, output `error` will be generated and is equal to `1`.

## Find Pattern from Start/End

To find the `index` of the first occurrence of specific `pattern` in a `bus` from start/end.

### Find Pattern from Start

To get the `index` location of the pattern from start of the bus, simply pass the Logic `bus` and `pattern`. Ensure that the `pattern` width is smaller than the `bus` width. By default, it will find the first occurrence of the `pattern` from start of the `bus`.

For example, if `bus` is `10100001` and `pattern` is `1010`, the output `index` will return `4` as the first occurrence of the pattern is found at the 5th-bit of the bus from the LSB.

```dart
final bus = Const(bin('10100001'), width: 8);
final pattern = Const(bin('1010'), width: 4);
final findPattern = FindPattern(bus, pattern);
expect(findPattern.index.value.toInt(), equals(4));
```

### Find Pattern from End

To get the `index` location of the pattern from end of the bus (MSB), pass the Logic `bus`, Logic `pattern` and set the `fromStart` to `false`. Ensure that the `pattern` width is smaller than the `bus` width. By default, it will find the first occurrence of the `pattern` from end of the `bus`.

For example, if `bus` is `11101010` and `pattern` is `11101`, the output `index` will return `0` as the first occurrence of the pattern is found at the 0th-bit of the bus from the MSB.

```dart
final bus = Const(bin('11101010'), width: 8);
final pattern = Const(bin('11101'), width: 5);
final findPattern = FindPattern(bus, pattern, fromStart: false);
expect(findPattern.index.value.toInt(), equals(0));
```

## Find Nth Pattern from Start/End

To find the `index` of `n`th occurrence of specific `pattern` in a `bus` from start/end.

### Find Nth Pattern from Start

To get the `index` location of the `n`th occurrence of `pattern` in the `bus`, simply pass the Logic `bus` and `pattern` and additional input Logic of `n`. By default `n` is `null` and will be set to `0` if it is not defined. `n` is zero-based indexing, so if you want to find the 2nd occurrence of the pattern, `n` should be set to `1`.

For example, if `bus` is `10101001` and you want to find the 3rd occurrence of `pattern` of `01`, pass input `n` as `2`. The output `index` will return `5` as the 3rd occurrence of the pattern is found at the 5th-bit of the bus from the LSB.

```dart
final bus = Const(bin('10101001'), width: 8);
final pattern = Const(bin('01'), width: 2);
final n = Const(2, width: log2Ceil(bus.width) + 1);
final findPattern = FindPattern(bus, pattern, n: n);
expect(findPattern.index.value.toInt(), equals(5));
```

### Find Nth Pattern from End

To get the `index` location of the `n`th occurrence of `pattern` from end of the `bus` (MSB), pass the Logic `bus`, Logic `pattern`, set `fromStart` to `false` with additional input Logic of `n`. By default `n` is `null` and will be set to `0` if it is not defined. `n` is zero-based indexing, so if you want to find the 2nd occurrence of the pattern, `n` should be set to `1`.

For example, if `bus` is `10101001` and you want to find the 3rd occurrence of `pattern` of `01`, pass input `n` as `2`. The output `index` will return `6` as the 3rd occurrence of the pattern is found at the 6th-bit of the bus from the MSB.

```dart
final bus = Const(bin('10101001'), width: 8);
final pattern = Const(bin('01'), width: 2);
final n = Const(2, width: log2Ceil(bus.width) + 1);
final findPattern = FindPattern(bus, pattern, fromStart: false, n: n);
expect(findPattern.index.value.toInt(), equals(6));
```

## Pattern not Found in Bus

If `pattern` is not found in the Logic `bus`, output `index` will be `0`. To generate the output pin `error`, set the `generateError` boolean to `true`. By default, `generateError` is `false`. If pattern is not found, `error` will be `1`.

```dart
final bus = Const(bin('00000000'), width: 8);
final pattern = Const(bin('111'), width: 3);
final findPattern = FindPattern(bus, pattern, generateError: true);
expect(findPattern.error!.value.toInt(), equals(1));
```
