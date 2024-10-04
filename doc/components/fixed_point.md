# Fixed-Point Arithmetic

Fixed-point binary representation of numbers is useful several applications including digital signal processing and embedded systems. As a first step towards enabling fixed-point components, we created a new value system `FixedPointValue` similar to `LogicValue`. 

## FixedPointValue

A `FixedPointValue` represents a signed or unsigned fixed-point value following the Q notation (Qm.n format) as introduced by [Texas Instruments](https://www.ti.com/lit/ug/spru565b/spru565b.pdf). It comprises an optional sign, integer part and/or a fractional part. `FixedPointValue`s can be constructed from individual fields or from a Dart `double`, converted to Dart `double`, can be compared and can be operated on (+, -, *, /).
