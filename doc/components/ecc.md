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
