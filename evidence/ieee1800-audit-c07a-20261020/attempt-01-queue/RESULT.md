# IEEE 1800 §7.10 queue probe (Slurm job 3509)

- Host: DAN-DESKTOP; 1 CPU, 1 GiB; each compile/run command had a 30-second timeout.
- Toolchain: Icarus 13.0-devel `cc25756d1`; pinned `iverilog`/`vvp` hashes are in `results/SHA256SUMS`.
- Probe: `tests/1800_audit/c07/p07_10_queue.sv`; source and expected stdout hashes are in `SHA256SUMS.input` and `results/SHA256SUMS`.
- Commands: `iverilog -g2017|-g2023 -s p07_10_queue -o <image> p07_10_queue.sv`.

| Edition | Compile rc | Run | Result |
|---|---:|---|---|
| 2017 | 4 | not run | compile rejected |
| 2023 | 4 | not run | compile rejected |

Both editions report the same legal-index syntax failures:

```text
p07_10_queue.sv:12: syntax error
p07_10_queue.sv:12: Syntax in assignment statement l-value.
p07_10_queue.sv:23: syntax error
p07_10_queue.sv:23: Syntax in assignment statement l-value.
```

The source locations are the standard's `q[$+1] = 50` and `b[$+1] = 6` writes. The first is explicitly legal in IEEE 1800-2017/2023 §7.10.1 (2017 p.162; 2023 p.170). Bounded queue behavior is specified in §7.10.5 (2017 p.163). Since compile failed, none of the remaining runtime observations were collected and no runtime warning lines were emitted. No separate warning lines were present in the compiler diagnostics.

Dedupe: all six required terms were searched separately in both open and closed issues; all searches returned no issues. See `dedupe-open-closed.txt`.

Raw output and source: `results-3509.tar.gz`, `input.tar.gz`, `results/SHA256SUMS`, `logs/job-3509.out`.
