# §16.9.8 first_match gap reproducers

Host: DAN-DESKTOP, Slurm job 3196. Source: clean `main`
`c31cbf1b52f1a39d5775f276e2340525a444a79e`. The protected Icarus SHA-256 is
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`.
Both probes were compiled using `iverilog -g<edition> -gassertions` under
`-g2017` and `-g2023`.

- `p16_09_08_first_match_composed.sv`: both editions exit 1 with the compiler's
  `sorry` that variable-length `first_match` feeding a continuation is not
  supported in this shape.
- `p16_09_08_first_match_match_item.sv`: both editions exit 3 with a syntax
  error at the optional `sequence_match_item` following the first_match
  operand. `parse.y:9116` confirms the parser currently accepts only
  `first_match ( sequence_expr )`.

The source snapshots, input/compiler hashes, compile logs, job log, and metadata
are preserved in this directory. Both paths are now tracked under
`tests/1800_audit/c16/` and were rerun from those exact files.
