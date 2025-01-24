# Control/Status Registers (CSRs)

ROHD HCL provides an infrastructure for creating CSRs at a few different granularities. These granularities are:

- Individual register (as an extension of ROHD's `LogicStructure`).
- A block of registers in which each register is uniquely addressable.
- A top-level module that contains arbitrarily many register blocks, each being uniquely addressable.

Each granularity will be discussed herein.

## Individual CSR Definition

An individual CSR is an extension of a `LogicStructure` and its members are the fields of the register. The class in HW to create a CSR is called `Csr`. It is constructed by passing a configuration object of type `CsrInstanceConfig`.

### CsrInstanceConfig

The `CsrInstanceConfig` is associated with a particular instantiation of an architecturally defined CSR. As such, it is constructed by passing a `CsrConfig` which defines the architectural CSR being instantiated. In addition to the properties of the architectural configuration, the instance configuration offers the following functionality:

- An address or unique ID for this CSR instance (called `addr`).
- A bit width for this CSR instance (called `width`).
- The ability to override the architectural reset value for this CSR upon construction.
- The ability to override the architectural readability and writability of this CSR (frontdoor, backdoor).
- A `validate()` method to check for configuration correctness and consistency.

#### Validation of CsrInstanceConfig

The following checks are run:

- Call the architectural configuration's `validate()` method.
- The `resetValue` for this CSR must fit within its `width`.
- Every field of this CSR must fit within its `width`.

### CsrConfig

The `CsrConfig` contains the architectural definition of a CSR (i.e., applies to every instance). An architectural CSR is logically comprised of 1 more fields. As such, it is constructed by providing a list of `CsrFieldConfig`s which defines its fields. The `CsrConfig` exposes the following functionality:

- A name for the CSR (called `name`).
- An access mode for the CSR (called `access`).
- An optional architectural reset value for the CSR (called `resetValue`).
- Configuration for the readability and writeability of the CSR (Booleans called `isFrontdoorReadable`, `isFrontdoorWriteable`, `isBackdoorReadable`, `isBackdoorWriteable`). All of these values default to `true` if not provided. 
- A `validate()` method to check for configuration correctness and consistency.
- A method `resetValueFromFields()` that computes an implicit reset value for the CSR based on the reset values for its individual fields.

#### CSR Access Modes

At the full CSR granularity, the access modes, defined in the Enum `CsrAccess`, are:

- Read only
- Read/write

Note that access rules only apply to frontdoor accesses. I.e., a read only register is still backdoor writeable if the configuration indicates as such. 

#### CSR Readability and Writeability Configuration

We define a "frontdoor" access as one performed by an external agent (i.e., software or some external hardware). For frontdoor accesses, the access (read or write) occurs using the address of the register and only one register is typically accessed via the frontdoor in a given cycle. A status register typically must be frontdoor readable while a control register typically must be frontdoor writeable.

We define a "backdoor" access as one performed by the encompassing hardware module (i.e., parent module reads or writes the register directly). For backdoor accesses, each register is individually and simultaneously accessible. A status register typically must be backdoor writeable while a control register typically must be backdoor readable.

#### Register Field Implications

There are certain special cases that are worth addressing regarding the fields of a CSR.

- It is a legal to have a `CsrConfig` with an empty field list. In this case, a single implicit field is added at hardware generation time that spans the entirety of the register. This field's access rules match the access rules of the register.
- If there are any gap bits between fields within a register, an implicit reserved field is added at hardware generation time to fill the gap. These reserved fields are always read only.

#### Validation of CsrConfig

The following checks are run:

- Call every field configuration's `validate()` method.
- No two fields in the register have the same `name`.
- No field overlaps with another field in the register.

### CsrFieldConfig

The `CsrFieldConfig` contains the architectural definition of an individual field within a CSR. The `CsrFieldConfig` exposes the following functionality:

- A name for the field (called `name`).
- A starting bit position for the field within the register (called `start`).
- A bit width for the field (called `width`).
- An access mode for the field (called `access`).
- An optional reset value for the field (called `resetValue`). If not provided, the reset value defaults to 0.
- An optional list of legal values for the field (called `legalValues`).
- A `validate()` method to check for configuration correctness and consistency.
- A method `transformIllegalValue()` to map illegal field values to some legal one. The default implementation statically maps to the first legal value in the `legalValues` list.

#### CSR Field Access Modes

At the CSR field granularity, the access modes, defined in the Enum `CsrFieldAccess`, are:

- Read only
- Read/write
- Write ones clear (read only, but writing it has a side effect)
- Read/write legal (can only write a legal value)

Note that field access rules apply to both frontdoor and backdoor accesses of the register.

To support the read/write legal mode, the configuration must provide a non-empty list of legal values to check against. In the hardware's logic construction, if a write is attempting to place an illegal value in the field, this write data is remapped to a legal value per the `transformIllegalValue()` method. This method can be custom defined in a derived class of `CsrFieldConfig` but has a default implementation that can be used as is.

#### Validation of CsrFieldConfig

The following checks are run:

- The `resetValue` must fit within the field's `width`.
- If the field has read/write legal access, the `legalValues` must not be empty.
- If the field has read/write legal access, the `resetValue` must appear in the `legalValues`.
- If the field has read/write legal access, every value in `legalValues` must fit within the field's `width`.

### API for Csr

As the `Csr` class is an extension of `LogicStructure`, it inherits all of the functionality of `LogicStructure`. This includes the ability to directly assign and/or consume it like any ROHD `Logic`.

In addition, the following attributes and methods are exposed:

- Accessors to all of the member attributes of the underlying `CsrInstanceConfig`.
- `Logic getField(String name)` which returns a `Logic` for the field within the CSR with the name `name`. This enables easy read/write access to the fields of the register if needed for logic in the parent hardware module.
- `Logic getWriteData(Logic wd) ` which returns a `Logic` tranforming the input `Logic` in such a way as to be a legal value to write to the given register. For example, if a field is read only, the current data for that field is grafted into the input data in the appropriate bit position.

## CSR Block Definition

A CSR block is a `Module` that wraps a collection of `Csr` objects, making them accessible to reads and writes. The class in HW to create a CSR block is called `CsrBlock`. It is constructed by passing a configuration object of type `CsrBlockConfig`.

### CsrBlockConfig

The `CsrBlockConfig` defines the contents of a register block. As such, it is constructed by passing a list of `CsrInstanceConfig`s which defines the registers contained within the block. In addition to the register instance configurations, the block configuration offers the following functionality:

- A name for the block (called `name`).
- A base address or unique ID for the block (called `baseAddr`).
- Methods to retrieve a given register instance's configuration by name or address (`getRegisterByName` and `getRegisterByAddr`).
- A `validate()` method to check for configuration correctness and consistency.
- A method `minAddrBits()` that returns the minimum number of address bits required to uniquely address every register instance in the given block. The return value is based on the largest `addr` across all register instances.
- A method `maxRegWidth()` that returns the number of bits in the largest register instance within the block.

#### Heterogeneity in CSR Widths

The `CsrBlock` hardware supports having registers of different widths if desired. As such, the hardware must ensure that the frontdoor data signals are wide enough to cover all registers within the block.

#### Validation of CsrBlockConfig

The following checks are run:

- There must be at least 1 register instance in the block.
- No two register instances in the block have the same `name`.
- No two register instances in the block have the same `addr`.

### Frontdoor CSR Access

The `CsrBlock` module provides frontdoor read/write access to its registers through a read `DataPortInterface` and a write `DataPortInterface`. These are passed to the module in its constructor.

To access a given register, in addition to asserting the enable signal, the encapsulating module must drive the address of the `DataPortInterface` to the address of one of the registers in the block (must be an exact match). If the address does not match any register, for writes, this is treated as a NOP and for reads the data returned is 0x0.

When performing a write, the write data driven on the write `DataPortInterface` is transformed using the target register's `getWriteData` function so as to enforce writing only valid values. If the target register's width is less than the width of the write `DataPortInterface`'s input data signal, the LSBs of the write data up to the width of the register are used.

When performing a read, if the target register's width is less than the width of the read `DataPortInterface`'s output data signal, the register's contents are zero-extended to match the target width. Read data from any register is always correct/legal by construction.

If a given register is configured as not frontdoor writeable, there is no hardware instantiated to write the register through the write `DataPortInterface`. In this case, even on an address match, the operation becomes a NOP.

If a given register is configured as not frontdoor readable, there is no hardware instantiated to read the register through the read `DataPortInterface`. In this case, even on an address match, the data returned will always be 0x0.

On module build, the width of the address signal on both `DataPortInterface`s is checked to ensure that it is at least as wide as the block's `minAddrBits`. On module build, the width of the input and output data signals on the `DataPortInterface`s are checked to ensure that they are at least as wide as the block's `maxRegWidth`.

### Backdoor CSR Access

The `CsrBlock` module provides backdoor read/write access to its registers through a `CsrBackdoorInterface`. One interface is instantiated per register that is backdoor accessible in the block and ported out of the module on build.

If a given register is configured as not backdoor writeable, the write related signals on its `CsrBackdoorInterface` will not be present.

If a given register is configured as not backdoor readable, the read related signals on its `CsrBackdoorInterface` will not be present.

The width of the data signals on the `CsrBackdoorInterface` will exactly match the associated register's `width` by construction.

#### CsrBackdoorInterface

The `CsrBackdoorInterface` has the following ports:

- `rdData` (width = `dataWidth`) => the data currently in the associated CSR
- `wrEn` (width = 1) => perform a backdoor write of the associated CSR in this cycle
- `wrData` (width = `dataWidth`) => the data to write to the associated CSR for a backdoor write

The `CsrBackdoorInterface` is constructed with a `CsrInstanceConfig`. This config enables the following:

- Populate the parameter `dataWidth` using the associated register config's `width`.
- Conditionally instantiate the `rdData` signal only if the associated register is backdoor readable.
- Conditionally instantiate the `wrEn` and `wrData` signals only if the associated register is backdoor writeable.

Note that `rdData` actually returns a `Csr` (i.e., a `LogicStructure`). This can be useful for subsequently retrieving fields. 

### API for CsrBlock

The following attributes and methods of `CsrBlock` are exposed:

- Accessors to all of the member attributes of the underlying `CsrBlockConfig`.
- `CsrBackdoorInterface getBackdoorPortsByName(String name)` which returns the `CsrBackdoorInterface` for the register within the block with the name `name`. This enables encapsulating module's to drive/consume the backdoor read/write outputs.
- `CsrBackdoorInterface getBackdoorPortsByAddr(int addr)` which returns the `CsrBackdoorInterface` for the register within the block with the address `addr`. This enables encapsulating module's to drive/consume the backdoor read/write outputs.

## CSR Top Definition

A CSR top is a `Module` that wraps a collection of `CsrBlock` objects, making them and their underlying registers accessible to reads and writes. The class in HW to create a CSR top is called `CsrTop`. It is constructed by passing a configuration object of type `CsrTopConfig`.

### CsrTopConfig

The `CsrTopConfig` defines the contents of the top module. As such, it is constructed by passing a list of `CsrBlockConfig`s which defines the blocks contained within the top module. In addition to the register block configurations, the top configuration offers the following functionality:

- A name for the module (called `name`).
- An offset width that is used to slice the main address signal to address registers within a given block (called `blockOffsetWidth`).
- Methods to retrieve a given register block's configuration by name or base address (`getBlockByName` and `getBlockByAddr`).
- A `validate()` method to check for configuration correctness and consistency.
- A method `minAddrBits()` that returns the minimum number of address bits required to uniquely address every register instance in every block. The return value is based on both the largest block `baseAddr` and its largest `minAddrBits`.
- A method `maxRegWidth()` that returns the number of bits in the largest register instance across all blocks.

#### Validation of CsrTopConfig

The following checks are run:

- There must be at least 1 register block in the module.
- No two register blocks in the module have the same `name`.
- No two register blocks in the module have the same `baseAddr`.
- No two register blocks in the module have `baseAddr`s that are too close together such there would be an address collision. This is based on the `minAddrBits` of each block to determine how much room that block needs before the next `baseAddr`.
- The `blockOffsetWidth` must be wide enough to cover the largest `minAddrBits` across all blocks.

### Frontdoor CSR Access

Similar to `CsrBlock`, the `CsrTop` module provides frontdoor read/write access to its blocks/registers through a read `DataPortInterface` and a write `DataPortInterface`. These are passed to the module in its constructor.

To access a particular register in a particular block, drive the address of the appropriate `DataPortInterface` to the block's `baseAddr` + the register's `addr`.

In the hardware's construction, each `CsrBlock`'s `DataPortInterface` is driven by the `CsrTop`'s associated `DataPortInterface`. For the address signal, the LSBs of the `CsrTop`'s `DataPortInterface` are used per the value of `blockOffsetWidth`. All other signals are direct pass-throughs.

If an access drives an address that doesn't map to any block, writes are NOPs and reads return 0x0.

On module build, the width of the address signal on both `DataPortInterface`s is checked to ensure that it is at least as wide as the module's `minAddrBits`. On module build, the width of the input and output data signals on the `DataPortInterface`s are checked to ensure that they are at least as wide as the module's `maxRegWidth`.

### Backdoor CSR Access

The `CsrTop` module provides backdoor read/write access to its blocks' registers through a `CsrBackdoorInterface`. One interface is instantiated per register in every block that is backdoor accessible and ported out of the module on build.

### API for CsrTop

The following attributes and methods of `CsrTop` are exposed:

- Accessors to all of the member attributes of the underlying `CsrTopConfig`.
- `CsrBackdoorInterface getBackdoorPortsByName(String block, String reg)` which returns the `CsrBackdoorInterface` for the register with name `reg` within the block with name `block`. This enables encapsulating modules to drive/consume the backdoor read/write outputs.
- `CsrBackdoorInterface getBackdoorPortsByAddr(int blockAddr, int regAddr)` which returns the `CsrBackdoorInterface` for the register with address `regAddr` within the block with base address `blockAddr`. This enables encapsulating modules to drive/consume the backdoor read/write outputs.














## Interface

The inputs to the divider module are:

* `clock` => clock for synchronous logic
* `reset` => reset for synchronous logic (active high, synchronous to `clock`)
* `dividend` => the numerator operand
* `divisor` => the denominator operand
* `isSigned` => should the operands of the division be treated as signed integers
* `validIn` => indication that a new division operation is being requested
* `readyOut` => indication that the result of the current division can be consumed

The outputs of the divider module are:

* `quotient` => the result of the division
* `remainder` => the remainder of the division
* `divZero` => divide by zero error indication
* `validOut` => the result of the current division operation is ready
* `readyIn` => the divider is ready to accept a new operation

The numerical inputs (`dividend`, `divisor`, `quotient`, `remainder`) are parametrized by a constructor parameter called `dataWidth`. All other signals have a width of 1.

## Protocol Description

To initiate a new request, it is expected that the requestor drive `validIn` to high along with the numerical values for `dividend`, `divisor` and the `isSigned` indicator. The first cycle in which `readyIn` is high where the above occurs is the cycle in which the operation is accepted by the divider.

When the division is complete, the module will assert the `validOut` signal along with the numerical values of `quotient` and `remainder` representing the division result and the signal `divZero` to indicate whether or not a division by zero occurred. The module will hold these signal values until `readyOut` is driven high by the integrating environment. The integrating environment must assume that `quotient` and `remainder` are meaningless if `divZero` is asserted.

## Mathematical Properties

For the division, implicit rounding towards 0 is always performed. I.e., a negative quotient will always be rounded up if the dividend is not evenly divisible by the divisor. Note that this behavior is not uniform across all programming languages (for example, Python rounds towards negative infinity).

For the remainder, the following equation will always precisely hold true: `dividend = divisor * quotient + remainder`. Note that this differs from the Euclidean modulo operator where the sign of the remainder is always positive.

Overflow can only occur when `dividend=<max negative number>`, `divisor=-1` and `isSigned=1`. In this case, the hardware will return `quotient=<max negative number>` and `remainder=0`. This is by design as the mathematically correct quotient cannot be represented in the fixed number of bits available.

## Code Example

```dart

final width = 32; // width of operands and result
final divIntf = MultiCycleDividerInterface(dataWidth: width);
final MultiCycleDivider divider = MultiCycleDivider(divIntf);

// ... assume some clock generator and reset flow occur ... //

if (divIntf.readyIn.value.toBool()) {
    divIntf.validIn.put(1);
    divIntf.dividend.put(2);
    divIntf.divisor.put(1);
    divIntf.isSigned.put(1);
}

// ... wait some time for result ... //

if (divIntf.validOut.value.toBool()) {
    expect(divIntf.quotient.value.toInt(), 2);
    expect(divIntf.remainder.value.toInt(), 0);
    expect(divIntf.divZero.value.toBool(), false);
    divIntf.readyOut.put(1);
}

```

## Future Considerations

In the future, an optimization might be added in which the `remainder` output is optional and controlled by a build time constructor parameter. If the remainder does not need to be computed, the implementation's upper bound latency can be significantly improved (`O(WIDTH**2)` => `O(WIDTH)`).
