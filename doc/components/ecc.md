# Error Correcting Codes (ECC)

ROHD-HCL implements [Hamming codes](https://en.wikipedia.org/wiki/Hamming_code) for error correction and detection. The Wikipedia article does a good job explaining the background and functionality of Hamming codes, for those unfamiliar.

An error correcting code is a code that can be included in a transmission with some data that enables the receiver to check whether there was an error (up to some number of bit flips), and possibly correct the error (up to a limit). There is a trade-off where increasing the number of additional bits included in the code improves error checking/correction, but costs more bits (area/power/storage).

ROHD-HCL only has Hamming codes currently, but there are many types of error correcting codes. The `HammingEccTransmitter` and `HammingEccReceiver` can support any data width, and support the following configurations:

| Type | Errors detectable | Errors correctable | Extra parity bit |
|------|-------------------|--------------------|------------------|
| Single Error Correction (SEC) | 1 | 1 | No |
| Double Error Detection (SEDDED) | 2 | 0 | No |
| Single Error Correction, Double Error Detection (SECDED) | 2 | 1 | Yes |
| Triple Error Detection (SEDDEDTED) | 3 | 0 | Yes |

## Typed payloads

`HammingEccTransmitter<T>` preserves structured inputs. Supply `dataSchema`
to `HammingEccReceiver<T>` for typed `originalData` and `correctedData`:

```dart
final tx = HammingEccTransmitter<Packet>(
  packet, hammingType: HammingType.secded);
final rx = HammingEccReceiver<Packet>(
  tx.transmission, dataSchema: packet, hammingType: HammingType.secded);
final Packet received = rx.originalData;
final Packet? corrected = rx.correctedData;
```

The schema provides layout only: it is cloned, not driven, and its width must
match the decoded payload. Structures, fixed/floating-point formats, enums,
and typed arrays (including rank-zero arrays and custom codecs) are preserved.
Without a schema, receivers retain ordinary `Logic` outputs; specialized
receiver type arguments require a schema.

Codewords and syndromes remain bit-oriented with unchanged encoding.
Correction operates on raw received bits before applying the output schema,
so an invalid enum encoding caused by a bit flip can still be corrected.
`correctedData` is null for SEDDED and SEDDEDTED, as before.
