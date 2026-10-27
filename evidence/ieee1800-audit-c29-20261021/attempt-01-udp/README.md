# IEEE 1800 Clause 29 UDP paired probe

This probe checks a combinational table (including unspecified and `z` input cases), a level-sensitive latch UDP with an initial state and hold row, and an edge-sensitive D flip-flop UDP with explicit hold and default-unknown behavior. It runs under `-g2017` and `-g2023`.

## Standard basis

- §29.3.4 says unspecified input combinations in the UDP state table produce a default output state `x`; §29.3.5 says `z` values at UDP inputs are treated as `x`. §29.4 likewise specifies `x` for unspecified combinations of a combinational UDP.
- §29.5 defines level-sensitive sequential tables with an internal output `reg`, current-state column, and next-state output; the symbol `-` means no change.
- §29.6 defines edge-sensitive sequential tables. Unspecified transitions default to `x`; hold transitions are represented by `-` in the output field.
- §29.7 allows an optional UDP `initial` procedural assignment to the output reg and specifies its value at simulation start. The test initializes the latch output to 1.

These rules and examples match in IEEE 1800-2017 and 1800-2023. The printed page locations are 2017 §§29.3.4–29.7, pp. 830–834; and 2023 §§29.3.4–29.7, pp. 862–866. The lead's note called the UDP `initial` rule §29.4, but both PDFs place it in §29.7; §29.4 is combinational UDP behavior.

Expected output in both editions:

```text
L0 1
M1 1
M2 0
M3 1
M4 x
M5 0
L1 0
L2 0
F1 1
F2 1
F3 0
F4 x
```

Probe: [`p29_udp.sv`](../../../tests/1800_audit/c29/p29_udp.sv). Open+closed issue dedupe is recorded in [`DEDUPE.md`](DEDUPE.md); completed paired results and raw logs are recorded in [`RESULT.md`](RESULT.md) and [`remote-3663/`](remote-3663/).
