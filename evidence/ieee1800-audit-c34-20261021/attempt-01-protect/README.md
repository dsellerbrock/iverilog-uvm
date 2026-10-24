# IEEE 1800 Clause 34 protected-envelope probes

`p34_plain.sv` is the non-protected control and should print `PLAIN` under `-g2017` and `-g2023`. `n34_cipher.sv` embeds the standard's raw ROT13 protected-envelope example inside `secret`; `top` would print `CIPHER 1` if the data were decrypted and compiled. This tests how the pinned tool handles an envelope without a supplied private key/decryption configuration; it does not claim encryption or decryption support.

## Standard basis

- IEEE 1800-2017/2023 §22.11 says: “Unless otherwise specified, pragma directives for pragma_names that are not recognized by an implementation shall have no effect on interpretation of the SystemVerilog source text.” Printed pages 686–687 (2017) and 718–719 (2023).
- §22.11.1 says: “The protect pragma is used to specify protected envelopes, as described in Clause 34.” Printed page 687 (2017) and 719 (2023). `protect` is therefore a standard pragma; the unknown-pragma rule does not clearly resolve its handling.
- §34.3 says: “Tools that process SystemVerilog source code shall perform envelope decryption for all decryption envelopes contained in the source text, where the proper key is supplied by the user.” The same paragraph says tools performing envelope encryption are only required to process protect pragmas and shall apply no other interpretation outside them (2017 p.918; 2023 p.950).
- §34.3.2 says: “SystemVerilog tools that support decrypting compilation shall transform source text containing decryption envelopes by replacing each decryption envelope with the decrypted source text from the data_block, according to the specified pragma expressions.” (2017 p.919; 2023 p.951).
- §34.5.3 says: “The begin_protected pragma expression begins a previously encrypted region. A decrypting tool shall accumulate all the pragma expressions in the block for use in decryption of the block.” (2017 p.922; 2023 p.954).

The cited text does not specify a fallback for a tool without decrypting support when no proper key is supplied. The lead classified Icarus's lack of protected-envelope handling as UNSUPPORTED; the issue records the misleading cascade as the honesty concern, not as a normative diagnostic requirement.

`p34_plain.sv` is §34.3's encryption-envelope form (`begin`/`end`) around ordinary source; it is expected to print `PLAIN`. The encrypted fixture is the raw `x-caesar`/`rot13` example in §34.3 (2017 p.918; 2023 p.950), with a small visible top module added to observe any successful decryption. Exact paired-edition results and open/closed issue dedupe are recorded in [`RESULT.md`](RESULT.md) and [`DEDUPE.md`](DEDUPE.md).
