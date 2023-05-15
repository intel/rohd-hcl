import 'package:rohd/rohd.dart';

/// A datatype class that hold result from [FullAdder].
class FullAdderResult {
  /// The output sum from full adder.
  final sum = Logic(name: 'sum');

  /// The output carry-out from full adder.
  final cOut = Logic(name: 'c_out');
}

/// A [FullAdder] module that can perform simple adder. The full adder output
/// can be defined in the truth table.
class FullAdder extends Module {
  /// The variable that hold [FullAdder] results.
  final fullAdderResult = FullAdderResult();

  /// The results returned from [FullAdder].
  FullAdderResult get fullAdderRes => fullAdderResult;

  /// Constructs a [FullAdder] with value [a], [b] and [carryIn].
  FullAdder({
    required Logic a,
    required Logic b,
    required Logic carryIn,
    super.name = 'full_adder',
  }) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carryIn = addInput('carry_in', carryIn, width: carryIn.width);

    final carryOut = addOutput('carry_out');
    final sum = addOutput('sum');

    final and1 = carryIn & (a ^ b);
    final and2 = b & a;

    Combinational([
      sum < (a ^ b) ^ carryIn,
      carryOut < and1 | and2,
    ]);

    fullAdderResult.sum <= output('sum');
    fullAdderResult.cOut <= output('carry_out');
  }
}

/// An [NBitAdder] that perform addition.
class NBitAdder extends Module {
  /// The List of results returned from the [FullAdder].
  final sum = <Logic>[];

  /// The final result of the NBitAdder.
  LogicValue get sumRes => sum.rswizzle().value;

  /// Constructs an n-bit adder based on inputs [a] and [b].
  NBitAdder(Logic a, Logic b) : super(name: 'ripple_carry_adder') {
    Logic carry = Const(0);

    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carry = addInput('carry_in', carry, width: carry.width);

    final n = a.width;
    FullAdder? res;

    assert(a.width == b.width, 'a and b should have same width.');

    for (var i = 0; i < n; i++) {
      res = FullAdder(a: a[i], b: b[i], carryIn: carry);

      carry = res.fullAdderRes.cOut;
      sum.add(res.fullAdderRes.sum);
    }

    sum.add(carry);
  }
}

/// A multiplier module that are able to get the product of two values.
class CarrySaveMultiplier extends Module {
  /// The list of the sum from every pipeline stages.
  final List<Logic> sum =
      List.generate(8, (index) => Logic(name: 'sum_$index'));

  /// The list pf carry from every pipeline stages.
  final List<Logic> carry =
      List.generate(8, (index) => Logic(name: 'carry_$index'));

  /// The final product of the multiplier module.
  Logic get product => output('product');

  /// The pipeline for [CarrySaveMultiplier].
  late final Pipeline pipeline;

  /// Construct a [CarrySaveMultiplier] that multiply [valA] and
  /// [valB].
  CarrySaveMultiplier(Logic valA, Logic valB, Logic clk, Logic reset,
      {super.name = 'carry_save_multiplier'}) {
    // Declare Input Node
    valA = addInput('a', valA, width: valA.width);
    valB = addInput('b', valB, width: valB.width);
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final product = addOutput('product', width: valA.width + valB.width + 1);

    final rCarryA = Logic(name: 'rcarry_a', width: valA.width);
    final rCarryB = Logic(name: 'rcarry_b', width: valB.width);

    pipeline = Pipeline(
      clk,
      stages: [
        ...List.generate(
          valB.width,
          (row) => (p) {
            final columnAdder = <Conditional>[];
            final maxIndexA = (valA.width - 1) + row;

            for (var column = maxIndexA; column >= row; column--) {
              final fullAdder = FullAdder(
                      a: column == maxIndexA || row == 0
                          ? Const(0)
                          : p.get(sum[column]),
                      b: p.get(valA)[column - row] & p.get(valB)[row],
                      carryIn: row == 0 ? Const(0) : p.get(carry[column - 1]))
                  .fullAdderRes;

              columnAdder
                ..add(p.get(carry[column]) < fullAdder.cOut)
                ..add(p.get(sum[column]) < fullAdder.sum);
            }

            return columnAdder;
          },
        ),
        (p) => [
              p.get(rCarryA) <
                  <Logic>[
                    Const(0),
                    ...List.generate(
                        valA.width - 1,
                        (index) =>
                            p.get(sum[(valA.width + valB.width - 2) - index]))
                  ].swizzle(),
              p.get(rCarryB) <
                  <Logic>[
                    ...List.generate(
                        valA.width,
                        (index) =>
                            p.get(carry[(valA.width + valB.width - 2) - index]))
                  ].swizzle()
            ],
      ],
      reset: reset,
      resetValues: {product: Const(0)},
    );

    final nBitAdder = NBitAdder(
      pipeline.get(rCarryA),
      pipeline.get(rCarryB),
    );

    product <=
        <Logic>[
          ...List.generate(
            valA.width + 1,
            (index) => nBitAdder.sum[(valA.width) - index],
          ),
          ...List.generate(
            valA.width,
            (index) => pipeline.get(sum[valA.width - index - 1]),
          )
        ].swizzle();
  }
}
