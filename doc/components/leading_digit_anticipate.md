# Leading Digit Anticipation

An anticipator is a circuit that can run parallel to another circuit and predict an output: for example, a leading one anticipator can run alongside an adder and predict the leading '1' position of the final sum based on the inputs.  Here are two such circuits:

## LeadingDigitAnticipate

ROHD-HCL comes with a leading-digit anticipate component which predicts the number of leading ones or zeros before the first digit change of a future sum of two inputs.  This prediction is within 1 of the actual digit change (either the `leadingDigit` or `leadingDigit` + 1 is the actual position). This can be used in parallel with an adder to avoid having to do a leading-digit detect after the addition and save delay.

`LeadingDigitAnticipate` assumes a twos-complement representation of the inputs. It will provide a single set of outputs `leadingDigit`, the position of the first `1` for a positive sum and the first '0' for a negative sum, as well as `validLeadDigit` which indicates that a digit change was predicted.  

Here is a sample usage where we are trying to 'normalize' a number by finding its leading digit and shifting left to the leading
digit:

```dart
final predictor = LeadingDigitAnticipate(a, b);

final sumShift = (a + b) << predictor.leadingDigit;

final sumShiftFinal = mux(sumshift[-1], sumShift, sumShift << 1);
```

## LeadingZeroAnticipate

ROHD-HCL also comes with a leading-zero anticipate component which predicts the leading-1 position (or the number of leading zeros) of a future ones-complement addition of two inputs. This can be used in parallel to avoid having to do a leading-1 detect after the addition and save delay.

`LeadingZeroAnticipate` assumes a sign-magnitude representation of the inputs.  If you supply the carry from an adder you are using on the same inputs then it will provide a single set of outputs `leadingOne`, the position of the first `1` (or number of leading zeros), as well as `validLeadOne` which indicates that a `1` was found.  

If you do not provide a carry, then the component outputs a pair of outputs (`leadingOneA`, `validLeadOneA`) and (`leadingOneB`, `validLeadOneB`) which you can then use to select the first set if your carry happens.

The computation presume ones-complement subtraction on the inputs and if first operand is positive and is larger than the second, then a carry from that is `1`, so the first leading one computation `leadingOneA` is the correct one, and in all other cases use the `leadingOneB`.

If you need to compute the number of leading 1s (say in a negative twos complement number), you can use a `LeadingZeroAnticipate` circuit by inverting the input.

Here is a sample usage:

```dart
final predictor = LeadingZeroAnticipate(aSign, a, bSign, b);

final adder = OnesComplementAdder(a, b, subtractIn: aSign ^ bSign, outputEndAroundCarry: true);

final leadingZeros = mux(adder.carry | aSign, predictor.leadingOneA!, predictor.leadingOneB!);
```
