# Clause 34 protected-envelope probe results

## Paired-edition probe: Slurm job 3671

- Host: DAN-DESKTOP, partition `verilog`; `scontrol` reports `COMPLETED`, exit `0:0`, elapsed 1 second; 1 CPU and 1 GiB requested.
- Probe checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, dirty branch `m7-1800-audit-c08`.
- Pinned toolchain source SHA: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, Icarus 13.0-devel. Binary and runtime SHA-256 values are in [`slurm-3671-logs/a3-c34-protect-3671.out`](slurm-3671-logs/a3-c34-protect-3671.out).
- Fixture SHA-256: `p34_plain.sv` `12c905abe99c984938895b830d304f2da7ebe8e183ddac9abf9dee99f4d6f717`; `n34_cipher.sv` `b553f91d5f58d1f288d3cea2ad5a173e1e88078d2bd5b0b637fb69a2d015abfd`.
- Commands: each source compiled independently with `iverilog -B <toolchain>/lib/ivl -g2017|-g2023 -s top -o <image> <source>`, then ran with `vvp <image>` on compile success. Per compile timeout 30 seconds; runtime timeout 10 seconds.
- Raw output: [`slurm-3671-logs`](slurm-3671-logs/).

`p34_plain.sv` wraps ordinary source in an encryption `begin`/`end` envelope. It compiles and runs in both editions, printing exactly `PLAIN`.

`n34_cipher.sv` uses the standard's raw `x-caesar`/`rot13` `begin_protected` example plus a visible testbench. Both editions exit 7 during compile; no executable or runtime output is produced. Diagnostics are identical:

```text
n34_cipher.sv:7: warning: macro centzn undefined (and assumed null) at this point.
n34_cipher.sv:7: syntax error
n34_cipher.sv:7: error: Invalid module instantiation
n34_cipher.sv:13: syntax error
n34_cipher.sv:11: error: Invalid module instantiation
n34_cipher.sv:17: syntax error
n34_cipher.sv:14: error: Invalid module instantiation
n34_cipher.sv:19: error: Invalid module instantiation
```

The leading macro warning shows the encoded ROT13 text was handled as ordinary source text rather than accumulated as a protected data block. The diagnostics do not identify unsupported protected-envelope decryption. No runtime conclusion is available because compilation fails.

## Standard text used for classification

- IEEE 1800-2017/2023 §22.11 says unrecognized pragma names have no effect on source interpretation; printed pp.686–687 (2017) and pp.718–719 (2023).
- §22.11.1 says: “The protect pragma is used to specify protected envelopes, as described in Clause 34.” Printed p.687 (2017) and p.719 (2023).
- §34.3 says: “Tools that process SystemVerilog source code shall perform envelope decryption for all decryption envelopes contained in the source text, where the proper key is supplied by the user.” Printed p.918 (2017) and p.950 (2023).
- §34.3.2 says: “SystemVerilog tools that support decrypting compilation shall transform source text containing decryption envelopes by replacing each decryption envelope with the decrypted source text from the data_block, according to the specified pragma expressions.” Printed p.919 (2017) and p.951 (2023).
- §34.5.3 says that `begin_protected` “begins a previously encrypted region” and “A decrypting tool shall accumulate all the pragma expressions in the block for use in decryption of the block.” Printed p.922 (2017) and p.954 (2023).

The standard does not specify a fallback for a tool without decrypting support when no proper key is supplied. The lead classified the decryption capability as UNSUPPORTED and filed [#882](https://github.com/dsellerbrock/iverilog-uvm/issues/882). The misleading syntax cascade is the honesty concern; the standard does not explicitly require an “unsupported” diagnostic. Open+closed issue searches are recorded in [`DEDUPE.md`](DEDUPE.md).
