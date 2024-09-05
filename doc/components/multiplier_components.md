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

| bit_i | bit_i-1 | multiple|
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

A few things to note: first, that we are negating by 1s complement (so we need a -0) and second, these rows do not add up to (18: 10010). For Booth encoded rows to add up properly, they need to be in 2s complement form, and they need to be sign-extended.

 Here is the matrix with crude sign extension (this formatting is available from our `PartialProductGenerator` component). With 2s complementation, and sign bits folded in (note the LSB of each row has a sign term from the previous row), these addends are correctly formed and add to (18: 10010).

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

 There are more compact ways of doing sign-extension which result in far fewer additions. Here is an example of compact sign-extension:  

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

Note that radix-4 shifts by 2 positions each row, but with only two rows and with sign-extension adding an LSB bit, you only see a shift of 1 in row 1.

## Partial Product Generator

This building block creates a set of rows of partial products from a multiplicand and a multiplier.  It maintains the partial products as a list of rows, which are themselves lists of Logic as well as a row shift value for each row to represent the starting column of the row's least-significant bit.  Its primary inputs are the multiplicand, multiplier, `RadixEncoder`, whether the operands are signed, and the type of `SignExtension` to use in generating the partial product rows.

The partial product generator produces a set of addends in shifted position to be added.  The main output of the component is

```dart
 - List<List<Logic>> partialProducts;
 - rowShift = <int>[];
```

### Radix Encoding

An argument to the `PartialProductGenerator` is the `RadixEncoder` to be used.  The [`RadixEncoder`] takes a single argument which is the radix (power of 2) to be used.

Instead of using the 1's in the multiplier to select shifted versions of the multiplicand to add in a partial product matrix, radix-encoding will encode multiples of the multiplicand by examining adjacent bits of the multiplier.  For radix-4, for example, for a multiplier of size M, instead of M rows of partial products, M/2 rows are formed by selecting from multiples [-2, -1, 0, 1, 2] of the multiplicand.  These multiples are computed from an 3 bit slices, overlapped by 1 bit, of the multiplier.  Higher radices use wider slices of the multiplier to encode fewer multiples and therefore fewer rows.

| bit_i | bit_i-1 | bit_i-2 | multiple|
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

Our `RadixEncoder` module is general, creating selection tables for arbitrary Booth radices of powers of 2.  Currently, we are limited to radix-16 because of challenges in creating the odd multiples efficiently, and there are more advanced techniques for efficiently generating higher radices than 16 than our current encoding/selection/partial-product generation scheme.

### Sign Extension Option

The `PartialProductGenerator` class also provides for sign extension with multiple options including `SignExtension.none` which is no sign extension for help in debugging, as well as `SignExtension.compactRect` which is a compact form which works for rectangular products where the multiplicand and multiplier can be of different widths.

### Partial Product Visualization

Creating new arithmetic building blocks from these components is tricky and visualizing intermediate results really helps.  To that end, our `PartialProductGenerator` class has visualization extension `EvaluatePartialProduct` which help evaluate the current `Logic` values in array form during simulation to help with debug.  The evaluation routine with the extension also adds the addends for you to help sanity check the partial product generation.  The routine is `EvaluateLivePartialProduct.representation`.

```text
             18 17 16 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0  
00 M= 2 S=1:                         0  1  1  1  1  1  1  1  0  1  0  : 0000000001111111010 = 1018 (1018)
01 M= 1 S=0:                   1  1  1  0  0  0  0  0  1  1  0        : 0000001110000011000 = 7192 (7192)
02 M= 0 S=0:          1  1  1  0  0  0  0  0  0  0  0                 : 0001110000000000000 = 57344 (57344)
03 M= 0 S=0: 1  1  1  0  0  0  0  0  0  0  0                          : 1110000000000000000 = 458752 (-65536)
======================================================================
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  1  0  0  1  0  : 0000000000000010010 = 18 (18)
```

## Compression Tree

Once you have a partial product matrix, you would like to add up the addends.  Traditionally this is done using compression trees which instantiate 2:1 and 3:2 column compressors (or carry-save adders) to reduce the matrix to two addends.  The final two addends are often added with an efficient final adder.

Our `ColumnCompressor` class uses a delay-driven approach to efficiently compress the rows of the partial product matrix.  Its only argument is a `PartialProductGenerator`, and it creates a list of `ColumnQueue`s containing the final two addends stored by column after compression. An `extractRow`routine can be used to extract the columns.  `ColumnCompressor` currently has an extension `EvaluateColumnCompressor` which can be used to print out the compression progress. Here is the legend for these printouts.

- ppR,C = partial product entry at row R, column C
- sR,C = sum term coming last from row R, column C
- cR,C = carry term coming last from row R, column C

Compression Tree before:

```text
        pp5,11  pp5,10  pp5,9   pp5,8   pp5,7   pp5,6   pp5,5   pp5,4   pp4,3   pp3,2   pp2,1   pp1,0
                        pp4,9   pp3,8   pp4,7   pp3,6   pp3,5   pp3,4   pp3,3   pp2,2   pp0,1   pp0,0
                                pp4,8   pp3,7   pp4,6   pp4,5   pp4,4   pp1,3   pp1,2   pp1,1
                                        pp2,7   pp0,6   pp0,5   pp0,4   pp0,3   pp0,2
                                                pp2,6   pp2,5   pp2,4   pp2,3
                                                pp1,6   pp1,5   pp1,4

        1       1       0       0       0       0       0       0       0       1       1       0       110000000110 (3078)
                        1       1       0       0       0       1       1       1       0       0       001100011100 (796)
                                0       0       0       0       0       1       0       0               000000001000 (8)
                                        0       1       0       0       0       0                       000001000000 (64)
                                                1       1       1       1                               000001111000 (120)
                                                0       1       1                                       000000110000 (48) Total=18
```

Compression Tree after compression:

```text
        pp5,11  pp5,10  s0,9    s0,8    s0,7    c0,5    c0,4    c0,3    s0,3    s0,2    pp0,1   pp1,0
                c0,9    c0,8    c0,7    c0,6    s0,6    s0,5    s0,4    s0,3    s0,2    s0,1    pp0,0

        1       1       1       1       1       0       1       0       0       1       0       0       111110100100 (4004)
                0       0       0       0       1       1       0       1       1       1       0       000001101110 (110) Total=18
```

## Final Adder

Any adder can be used as the final adder of the final two addends produced from compression.  Typically, we use some for of parallel prefix adder for performance.

## Compress Tree Multiplier Example

Here is a code snippet that shows how these components can be used to create a multiplier.  

First the partial product generator is used, which has compact sign extension for rectangular products (`PartialProductGeneratorCompactRectSignExtension`) which we pass in the `RadixEncoder`, whether the operands are signed, and the kind of sign extension to use on the partial products. Note that sign extension is needed regardless of whether operands are signed or not due to Booth encoding.

Next, we use the `ColumnCompressor` to compress the partial products into two final addends.

We then choose a `ParallelPrefixAdder` using the `BrentKung` tree style to do the addition.  We pass in the two extracted rows of the compressor.
Finally, we produce the product.

```dart
    final pp =
        PartialProductGeneratorCompactRectSignExtension(a, b, RadixEncoder(radix), signed: true);
    final compressor = ColumnCompressor(pp)..compress();
    final adder = ParallelPrefixAdder(
        compressor.exractRow(0), compressor.extractRow(1), BrentKung.new);
    product <= adder.sum.slice(a.width + b.width - 1, 0);
```
