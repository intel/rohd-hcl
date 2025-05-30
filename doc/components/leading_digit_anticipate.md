# Leading Digit Anticipation

An anticipator is a module that can run parallel to another module and predict an output: for example, a leading-one anticipator can run alongside an adder and predict the leading '1' position of the final sum based on the inputs.  Here are two such types of modules:

## LeadingDigitAnticipate

ROHD-HCL comes with a leading-digit anticipate component which predicts the number of leading ones or zeros before the first digit change of sum of two inputs, by looking at those inputs in parallel with the adder.  This prediction is within 1 of the actual digit change (either the `leadingDigit` or `leadingDigit` + 1 is the actual position). This can be used in parallel with an adder to avoid having to do a leading-digit detect after the addition and save delay.

`LeadingDigitAnticipate` assumes a twos-complement representation of the inputs. It will provide a single set of outputs `leadingDigit`, the position of the first `1` for a positive sum and the first '0' for a negative sum, as well as `validLeadDigit` which indicates that a digit change was predicted.  

Here is a sample usage where we are trying to 'normalize' a number by finding its leading digit and shifting left to the leading
digit:

```dart
final predictor = LeadingDigitAnticipate(a, b);

final sumShift = (a + b) << predictor.leadingDigit;

final sumShiftFinal = mux(sumshift[-1], sumShift, sumShift << 1);
```

## LeadingZeroAnticipate

ROHD-HCL also comes with a few leading-zero anticipate components which predict the leading-1 position (or the number of leading zeros) of a future ones-complement addition of two inputs. This can be used in parallel with a ones-complement adder to avoid having to do a leading-1 detect after the addition and therefore save delay. These anticipators guarantee a prediction of the position of a digit change at either `leadingZero` or `leadingZero`+ 1.

These components assume you are adding or subtracting two operands using ones-complement modules which produce an end-around-carry that can be used to decide which operand was bigger during subtraction.

 Generally the output `leadingOne`, holds the position of the first `1` (or number of leading zeros), and `validLeadOne` which indicates that a `1` was indeed found.

Module `LeadingZeroAnticipate` assumes a sign-magnitude representation of the inputs.
It outputs a pair of outputs (`leadingOne`, `validLeadOne`) and (`leadingOneConverse`, `validLeadOneConverse`) which you can then use to select the first set if a carry happens in a parallel ones-complement module.  If you subtract two operands and receive an end-around-carry, that means the first operand was bigger.  In this case, the first pair (`leadingOne`, `validLeadOne`) are relevant to predicting the leading '1'.  Otherwise, the second pair is relevant.

Module `LeadingZeroAnticipateCarry` operates in the same way, but with this module you can supply the end-around-carry as `endAroundCarry` and only the correct pair (`leadingOne`, and `validLeadOne`) are produced for predicting the leading '1' of the computation.

Here is a sample usage in floating point addition: here we want to add two mantissas and then use the number of leading zeros in the sum to adjust the exponent (this simple example ignores the possibility of underflowing the exponent field).  

A slow method would use a priority encoder to find the leading 1 in the sum:

```dart
final adder = OnesComplementAdder(aMantissa, bMantissa, subtractIn: aSign ^ bSign);

// Look at the output sum and find the leading 1
final predictedPos = RecursivePriorityEncoder(adder.sum.reversed).out;

// Shift the sum to have no leading zeros
final mantissa = adder.sum << predictedPos;

// Adjust the exponent by the number of shifts
final exponent = alignedExponent - predictedPos;
```

But you can see this stacks the computation of priority encoding on top of the adder computation (especially the final carry in the adder).  

But we can 'anticipate' the number of leading zeros instead of counting them:

```dart
// Perform the addition
final adder = OnesComplementAdder(aMantissa, bMantissa, subtractIn: aSign ^ bSign);

// Perform the prediction in parallel: Look at the inputs of the adder to anticipate what the sum will look like.
final predictor = LeadingZeroAnticipateCarry(aSign, aMantissa, bSign, bMantissa,
endAroundCarry: adder.endAroundCarry);

final leadingZerosEstimate = predictor.leadingOne;

// Shift the mantissa partially into place (could have a single leading 0)
var trueMantissa = adder.sum << leadingZerosEstimate;

// The estimate can be perfect or off by one to the left.
final leadingZeros = mux(trueMantissa[-1], leadingZerosEstimate, leadingZerosEstimate + 1);
trueMantissa = mux(trueMantissa[-1], trueMantissa, trueMantissa << 1);

// Ajust the exponent by the actual number of leading 0s found
final exponent = alignedExponent - leadingZeros;
```
