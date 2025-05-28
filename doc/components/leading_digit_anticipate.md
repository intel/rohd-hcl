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

ROHD-HCL also comes with a leading-zero anticipate component which predicts the leading-1 position (or the number of leading zeros) of a future ones-complement addition of two inputs. This can be used in parallel to avoid having to do a leading-1 detect after the addition and save delay. These anticipators guarantee a prediction of the anticipated digit at either p or p+1 where p is the predicted position.

`LeadingZeroAnticipate` assumes a sign-magnitude representation of the inputs.  If you supply the carry from an adder you are using on the same inputs then it will provide a single set of outputs `leadingOne`, the position of the first `1` (or number of leading zeros), as well as `validLeadOne` which indicates that a `1` was found.  

If you do not provide a carry, then the component outputs a pair of outputs (`leadingOneA`, `validLeadOneA`) and (`leadingOneB`, `validLeadOneB`) which you can then use to select the first set if your carry happens.

The computation presume ones-complement subtraction on the inputs and if the first operand is positive and is larger than the second, then an end-around-carry from that is `1`, so the first leading one computation `leadingOneA` is the correct one, and in all other cases the `leadingOneB` is correct.

If you need to compute the number of leading 1s (say in a negative twos complement number), you can use a `LeadingZeroAnticipate` circuit by inverting the input.

Here is a sample usage in floating point addition: here we want to add two mantissas and then use the number of leading zeros in the sum to adjust the exponent (this simple example ignores the possibility of underflowing the exponent field).  Normally one would use a priority encoder to find the leading 1 in the sum:

```dart
final adder = OnesComplementAdder(aMantissa, bMantissa, subtractIn: aSign ^ bSign);

// Look at the output sum and find the leading 1
final predictedPos = RecursivePriorityEncoder(adder.sum.reversed).out;

// Shift the sum to have no leading zeros
final mantissa = adder.sum << predictedPos;

// Adjust the exponent by the number of shifts
final exponent = alignedExponent - predictedPos;
```

But you can see this stacks the computation of priority encoding on top of the adder computation (especially the final carry in the adder).  But we can 'anticipate' the number of leading zeros instead of counting them:

```dart
// Look at the inputs of the adder to anticipate what the sum will look like.
final predictor = LeadingZeroAnticipate(aSign, aMantissa, bSign, bMantissa);

// Do the add in parallel
final adder = OnesComplementAdder(aMantissa, bMantissa, subtractIn: aSign ^ bSign);

final leadingZerosEstimate = predictor.leadingOne;

// Shift the mantissa partially into place (could have a single leading 0)
var trueMantissa = adder.sum << leadingZerosEstimate;

// The estimate can be perfect or off by one to the left.
final leadingZeros = mux(trueMantissa[-1], leadingZerosEstimate, leadingZerosEstimate + 1);
trueMantissa = mux(trueMantissa[-1], trueMantissa, trueMantissa << 1);

// Ajust the exponent by the actual number of leading 0s found
final exponent = alignedExponent - leadingZeros;
```

## Leading Digit Anticipate

For the case of signed operands, we also have a `LeadingDigitAnticipate` module.

```dart

final leadingDigitAnticipate = LeadingDigitAnticipate(twosComplementA, twosComplementB);
```

The same issue of anticipation arises that the leading digit could be one more position higher than anticipated.
