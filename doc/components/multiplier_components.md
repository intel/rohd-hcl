# Booth Encoding Multiplier Building Blocks

The Compression Tree multipliers `CompressionTreeMultiplier` and `CompressionTreeMultiplyAccumulate` use a set of building blocks that can also be used for building up other multipliers and arithmetic circuits.  These are from the family of Booth-encoding multipliers which are comprised of three major stages:

1) Booth radix encoding (typically radix-4) generating partial products
2) Partial product array column compression to two addends
3) Final adder

Each of these stages can be implemented with different algorithms and in ROHD-HCL, we provide the flexible building blocks for these three stages.

- [Partial Product Generator](#partial-product-generator)
- [Compression Tree](#compression-tree)
- [Final Adder](#final-adder)

## Introduction to Booth Encoding

Think of the hand-multiplication process where you write down the multiplicand and the multiplier.  Then, starting with the LSB of the multiplier (6), you would take each bit (0 1 1 0), and created a shifted version of the multiplicand (3 = 0 0 1 1) to write down as an addend row, shifting left 1 position per row. Once complete, you would add up all the rows. In the example below, the bits of the multiplier (6) select single multiples of multiplicand (3) shifted into a partial product matrix, which adds up to their product (18).

```text
                0  0  1  1   (3)
                0  1  1  0   (6)
                ==========
                0  0  0  0
             0  0  1  1
          0  0  1  1
       0  0  0  0
       ====================
       0  0  1  0  0  1  0  (18)             
```

With Booth encoding, we take multiple adjacent bits of the multiplier (6) to form these rows. In the case that most closely matches hand-multiplication, radix-2 Booth encoding, we take two adjacent bit slices to create multiples [-1,-0, +0, +1] where a leading bit in the slice would indicate negation. These then select the appropriate multiple to shift into the row. So (6) = [0 1 1 0] gets sliced left-to-right (leading with a 0) to create multiple selectors: [0 0], [1 0], [1 1], [0 1]. These slices are radix encoded into multiple (±0, ±1) selectors as follows according to radix-2:

| Bit i | Bit i-1 | Multiple|
|:-----:|:-------:|:-------:|
| 0     |     0   |      +0 |
| 0     |     1   |     +1  |
| 1     |     0   |     -1  |
| 1     |     1   |     -0  |

: Radix-2 Table

These slices then select shifted multiples of the multiplicand (3 = 0 0 1 1) as follows.

```text
row  slice  mult
00   [0 0] = +0            0  0  0  0
01   [1 0] = -1         1  1  0  0
02   [1 1] = -0      1  1  1  1
03   [0 1] = +1   0  0  1  1
```

A few things to note: first, that we are negating by ones' complement (so we need a -0) and second, these rows do not add up to (18: 10010). For Booth encoded rows to add up properly, they need to be in twos' complement form, and they need to be sign-extended.

 Here is the matrix with a crude sign extension `brute` (the table formatting is available from our [PartialProductGenerator](https://intel.github.io/rohd-hcl/rohd_hcl/PartialProductGeneratorBase-class.html) component). With twos' complementation, and sign bits folded in (note the LSB of each row has a sign term from the previous row), these addends are correctly formed and add to (18: 10010).

```text
            7  6  5  4  3  2  1  0  
00 M=0 S=0: 0  0  0  0  0  0  0  0  : 00000000 = 0 (0)
01 M=1 S=1: 1  1  1  1  1  0  0  0  : 11111000 = 248 (-8)
02 M=0 S=1: 1  1  1  1  1  1  1     : 11111110 = 254 (-2)
03 M=1 S=0: 0  0  0  1  1  1        : 00011100 = 28 (28)
04 M=  S= : 0  0  0  0  0           : 00000000 = 0 (0)
====================================
            0  0  0  1  0  0  1  0  : 00010010 = 18 (18)
 ```

 There are more compact ways of doing sign-extension which result in far fewer additions. Here is an example of `compact` sign-extension, where the last row which carries only a sign bit is folded into the previous row:  

```text
            7  6  5  4  3  2  1  0  
00 M=0 S=0:          1  0  0  0  0  : 00010000 = 16 (16)
01 M=1 S=1:          0  1  0  0  0  : 00001000 = 8 (8)
02 M=0 S=1:       0  1  1  1  1     : 00011110 = 30 (30)
03 M=1 S=0: 1  1  0  1  1  1        : 11011100 = 220 (-36)
====================================
            0  0  0  1  0  0  1  0  : 00010010 = 18 (18)
```

And of course, with higher radix-encoding, we select more bits at a time from the multiplier and therefore have fewer rows to add. Here is radix-4 Booth encoding for our example, slicing (6: 0110) radix$_{4}$[100]=-2 and radix$_{4}$[011]=2 as multiples:

```text
            7  6  5  4  3  2  1  0  
00 M=2 S=1:    0  1  1  1  0  0  0  : 00111000 = 56 (56)
01 M=2 S=0: 1  1  0  1  1  0  1     : 11011010 = 218 (-38)
====================================
            0  0  0  1  0  0  1  0  : 00010010 = 18 (18)
```

Note that radix-4 shifts by 2 positions each row, but with only two rows and with sign-extension adding an LSB bit to each row, you only see a shift of 1 in row 1, but in a larger example you would see the two-bit shift in the following rows.

## Partial Product Generator

The base class of `PartialProductGenerator` is [PartialProductArray](https://intel.github.io/rohd-hcl/rohd_hcl/PartialProductArray-class.html) which is simply a `List<List<Logic>>` to represent addends and a `rowShift[row]` to represent the shifts in the partial product matrix. If customization is needed beyond sign extension options, routines are provided that allow for fixed customization of bit positions or conditional (mux based on a Logic) form in the `PartialProductArray`.

```dart
final ppa = ppg as PartialProductArray;
ppa.setAbsolute(row, col, logic);
ppa.setAbsoluteAll(row, col, List<Logic>);
ppa.muxAbsolute(row, col, condition, logic);
ppa.muxAbsoluteAll(row, col, condition, List<logic>);
```

 The `PartialProductGenerator` adds to this the [RadixEncoder](https://intel.github.io/rohd-hcl/rohd_hcl/RadixEncoder-class.html) to encode the rows along with a matching `MultiplicandSelector` to create the actual mantissas used in each row.

As a building block which creates a set of rows of partial products from a multiplicand and a multiplier, it maintains the partial products as a list of rows on the `PartialProductArray` base. Its primary inputs are the multiplicand, multiplier, `RadixEncoder`, and whether the operands are signed.

The partial product generator produces a set of addends in shifted position to be added.  The main output of the component is

```dart
 - List<List<Logic>> partialProducts;
 - rowShift = <int>[];
```

### Radix Encoding

An argument to the `PartialProductGenerator` is the `RadixEncoder` to be used.  The [RadixEncoder](https://intel.github.io/rohd-hcl/rohd_hcl/RadixEncoder-class.html) takes a single argument which is the radix (power of 2) to be used.

Instead of using the 1's in the multiplier to select shifted versions of the multiplicand to add in a partial product matrix, radix-encoding will encode multiples of the multiplicand by examining adjacent bits of the multiplier.  For radix-4, for example, for a multiplier of size M, instead of M rows of partial products, M/2 rows are formed by selecting from multiples [-2, -1, 0, 1, 2] of the multiplicand.  These multiples are computed from an 3 bit slices, overlapped by 1 bit, of the multiplier.  Higher radixes use wider slices of the multiplier to encode fewer multiples and therefore fewer rows.

| Bit i | Bit i-1 | Bit i-2 | Multiple|
|:-----:|:-------:|:-------:|:-------:|
| 0     |     0   |    0    |    +0   |
| 0     |     0   |    1    |     1   |
| 0     |     1   |    0    |     1   |
| 0     |     1   |    1    |     2   |
| 1     |     0   |    0    |     2   |
| 1     |     0   |    1    |    -1   |
| 1     |     1   |    0    |    -1   |
| 1     |     1   |    1    |    -0   |

: Radix-4 Table

Our `RadixEncoder` module is general, creating selection tables for arbitrary Booth radixes of powers of 2.  Currently, we are limited to radix-16 because of challenges in creating the odd multiples efficiently, and there are more advanced techniques for efficiently generating higher radixes than 16 than our current encoding/selection/partial-product generation scheme.

### Sign Extension Option

The `PartialProductSignExtension` defines the abstract API for doing different kinds of sign extension on the `PartialProductArray`, from very simplistic for helping design new arithmetics to fairly standard to even compact, rectangular forms. The following derived sub-classes do different kinds of sign extension:

- `NoneSignExtension`: no sign extension.
- `BruteSignExtension`: full width extension which is robust but costly.
- `StopBitsSignExtension`: A standard form which has the inverse-sign and a '1' stop-bit in each row
- `CompactSignExtension`: A form that eliminates a final sign in an otherwise empty final row.
- `CompactRectSignExtension`: An enhanced form of compact that can handle rectangular multiplications.

You can perform sign extension by constructing a sign extender with the `PartialProductArray` as an argument and then calling `signExtend()`.

```dart
CompactSignExtension(ppg).signExtend();
```

### Partial Product Visualization

Creating new arithmetic building blocks from these components is tricky and visualizing intermediate results really helps.  To that end, our `PartialProductGenerator` class has visualization extension `EvaluateLivePartialProduct` which help evaluate the current `Logic` values in array form during simulation to help with debug.  The evaluation routine with the extension also adds the addends for you to help sanity check the partial product generation.  The routine is `EvaluateLivePartialProduct.representation`.  Here 'S' or 's' represent a sign bit extension (positive polarity) with 'S' representing '1', 's' representing 0.  'I' and 'i' represent an inverted sign bit.

```text
            18 17 16 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0  
00 M= 2 S=1                      i  S  S  1  1  1  1  1  1  0  0  0   = 2040 (2040)
01 M= 2 S=0                   1  I  0  0  0  0  0  0  1  1  0  1      = 6170 (6170)
02 M= 0 S=0             1  I  0  0  0  0  0  0  0  0  0  0            = 24576 (24576)
03 M= 0 S=0       1  I  0  0  0  0  0  0  0  0  0  0                  = 98304 (98304)
04 M= 0 S=0 1  I  0  0  0  0  0  0  0  0  0  0                        = 393216 (-131072)
=====================================================================
            0  0  0  0  0  0  0  0  0  0  0  0  0  0  1  0  0  1  0   = 18 (18)
```

You can also generate a Markdown form of the same matrix:

| R | M | S|  18  |  17  |  16  |  15  |  14  |  13  |  12  |  11  |  10  |  9  |  8  |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  | value|
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--|
|00| 2| 1||||||||$\overline0$|$\underline1$|$\underline1$|1|1|1|1|1|1|0|0|0| 2040 (2040)|
|01| 2| 0|||||||1|$\overline1$|0|0|0|0|0|0|1|1|0|1|| 6170 (6170)|
|02| 0| 0|||||1|$\overline1$|0|0|0|0|0|0|0|0|0|0|||| 24576 (24576)|
|03| 0| 0|||1|$\overline1$|0|0|0|0|0|0|0|0|0|0|||||| 98304 (98304)|
|04| 0| 0|1|$\overline1$|0|0|0|0|0|0|0|0|0|0|||||||| 393216 (-131072)|
||||0 |0 |0 |0 |0 |0 |0 |0 |0 |0 |0 |0 |0 |0 |1 |0 |0 |1 |0 |18 (18)|

 Here $\underline 1$ or $\underline 0$ represent a sign bit extension (positive polarity),
 whereas $\overline 1$ or $\overline 0$ represents a negative polarity sign bit.

## Compression Tree

Once you have a partial product matrix, you would like to add up the addends.  Traditionally this is done using compression trees which instantiate 2:1 and 3:2 column compressors (or carry-save adders) to reduce the matrix to two addends.  The final two addends are often added with an efficient final adder.

Our [ColumnCompressor](https://intel.github.io/rohd-hcl/rohd_hcl/ColumnCompressor-class.html) class uses a delay-driven approach to efficiently compress the rows of the partial product matrix.  Its only argument is a `PartialProductArray` (base class of `PartialProductGenerator`), and it creates a list of `ColumnQueue`s containing the final two addends stored by column after compression. An `extractRow`routine can be used to extract the columns.  `ColumnCompressor` currently has an extension `EvaluateLiveColumnCompressor` which can be used to print out the compression progress. Here is the legend for these printouts.

- `ppR,C` = partial product entry at row R, column C
- `sR,C` = sum term coming last from row R, column C
- `cR,C` = carry term coming last from row R, column C

Compression Tree before:

```text
        pp5,11  pp5,10  pp5,9   pp5,8   pp5,7   pp5,6   pp5,5   pp5,4   pp4,3   pp3,2   pp2,1   pp1,0
                        pp4,9   pp3,8   pp4,7   pp3,6   pp3,5   pp3,4   pp3,3   pp2,2   pp0,1   pp0,0
                                pp4,8   pp3,7   pp4,6   pp4,5   pp4,4   pp1,3   pp1,2   pp1,1
                                        pp2,7   pp0,6   pp0,5   pp0,4   pp0,3   pp0,2
                                                pp2,6   pp2,5   pp2,4   pp2,3
                                                pp1,6   pp1,5   pp1,4

       11      10       9       8       7       6       5       4       3       2       1       0
        1       1       0       0       0       0       0       s       s       s       S       S        = 3075 (-1021)
                        1       1       0       0       0       0       0       0       0       1        = 769 (769)
                                0       0       0       0       0       1       1       1                = 14 (14)
                                        1       i       S       1       1       0                        = 184 (184)
                                                0       0       1       1                                = 24 (24)
                                                0       1       1                                        = 48 (48)
p       0       0       0       0       0       0       0       1       0       0       1       0        = 18 (18)
```

Compression Tree after compression:

```text
        pp5,11  pp5,10  s0,9    s0,8    s0,7    c0,5    c0,4    c0,3    s0,3    s0,2    pp0,1   pp1,0
                c0,9    c0,8    c0,7    c0,6    s0,6    s0,5    s0,4    s0,3    s0,2    s0,1    pp0,0

       11      10       9       8       7       6       5       4       3       2       1       0
        1       1       1       1       1       1       0       0       1       1       0       S        = 4045 (-51)
                0       0       0       0       1       0       0       0       1       0       1        = 69 (69)
p       0       0       0       0       0       0       0       1       0       0       1       0        = 18 (18)
```

## Final Adder

Any adder can be used as the final adder of the final two addends produced from compression.  Typically, we use some for of parallel prefix adder for performance.

## Compress Tree Multiplier Example

Here is a code snippet that shows how these components can be used to create a multiplier.  

First the partial product generator is used (`PartialProductGenerator`), which we pass in the `RadixEncoder`, whether the operands are signed.  We operate on this generator with a compact sign extension class for rectangular products (`CompactRectSignExtension`). Note that sign extension is needed regardless of whether operands are signed or not due to Booth encoding.

Next, we use the `ColumnCompressor` to compress the partial products into two final addends.

We then choose a `ParallelPrefixAdder` using the `BrentKung` tree style to do the addition.  We pass in the two extracted rows of the compressor.
Finally, we produce the product.

```dart
    final pp =
        PartialProductGenerator(a, b, RadixEncoder(radix), signedMultiplicand: true, signedMultiplier: true);
    CompactRectSignExtension(pp).signExtend();
    final compressor = ColumnCompressor(pp)..compress();
    final adder = ParallelPrefixAdder(
        compressor.exractRow(0), compressor.extractRow(1), BrentKung.new);
    product <= adder.sum.slice(a.width + b.width - 1, 0);
```

## Utility: Aligned Vector Formatting

We provide an extension on `LogicValue` which permits formatting of binary vectors in an aligned way to help with debugging arithmetic components.

The `vecString` extension provides a basic string printer with an optional `header` flag for bit numbering.  A `prefix` value can be used to specify the name lengths to be used to keep vectors aligned.

`alignHigh` controls the highest (toward MSB) alignment column of the output whereas `alignLow` controls the lower limit (toward the LSB).

`sepPos` is optional and allows you to set a marker for a separator in the number.
`sepChar` is the separation character you wish to use (do not use '|' with Markdown formatting.)

```dart
  final ref = FloatingPoint64Value.fromDouble(3.14159);
  print(ref.mantissa
      .vecString('pi', alignHigh: 55, alignLow: 40, header: true, sepPos: 52));
```

Produces

```text
            54  53  52* 51  50  49  48  47  46  45  44  43  42  41  40
pi                    *  1   0   0   1   0   0   1   0   0   0   0   1
```

The routine also allows for output in Markdown format:

```dart
  print(ref.mantissa.vecString('pi',
      alignHigh: 58, alignLow: 40, header: true, sepPos: 52, markDown: true));
```

producing:

| Name | 54 | 53 | 52* |  51 | 50 | 49 | 48 | 47 | 46 | 45 | 44 | 43 | 42 | 41 | 40 |
|:--:|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|:---|
|pi|||* | 1 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1 |
