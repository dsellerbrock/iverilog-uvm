# IEEE 1800-2023 `dist default :/` qualification

Fix 29 implements the IEEE 1800-2023 §18.5.3 `default :/ expression` item.
The item denotes one aggregate-weight bucket containing every subject value
not covered by any explicitly listed bin. Explicit zero-weight items still
exclude their values from that complement. Strict 2017 rejects the syntax;
missing weight, `:=`, and duplicate defaults are compile errors.

The paired 4-bit runtime oracle takes 4,000 samples from
`[2:3] :/ 3, default :/ 1`. It checks 2,700–3,300 explicit-bin draws,
700–1,300 complement draws, 1,250–1,750 draws for each explicit value, and
35–110 draws for each of the 14 complement values. A second class checks
overlapping explicit bins and that a zero-weight listed value never leaks into
the default set; a hard constraint on that zero-weight value must fail.

## Results

- New strict JSON/VVP focus: **5/5**.
- New strict legacy focus: **5/5**.
- Existing exact-dist neighbor lists: **14/14** JSON/VVP and **14/14** legacy.
- No OpenTitan or full-corpus run was needed for this language-only change.

Commands, from `iverilog-uvm/ivtest`:

```sh
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  python3 vvp_reg.py --strict regress-dist-default-vvp.list
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  perl vvp_reg.pl --strict regress-dist-default-legacy.list
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  python3 vvp_reg.py --strict regress-dist-large-exact-vvp.list
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  perl vvp_reg.pl --strict regress-dist-large-exact-legacy.list
```

Source-built tool hashes:

| Tool | SHA-256 |
| --- | --- |
| `iverilog` | `36167f4671b3cb3616dae40e800be83a238e10301cc4516d27c69ca98d486e15` |
| `ivl` | `0e331a08ecfcec1b42727864f444ad0a0e612ded08ecab4c83a0c138501998e5` |
| `vvp` | `158fb79e1624083da370d5a176bf85f3ef96e01b91e4c75279af8a68309638b1` |
| `vvp.tgt` | `dcdf2a5a5aeef3422952a7ff61ad874cb577beacf120e27b9244d9dd599c7243` |

The exact sampler retains its existing supported-shape limits. This focused
result does not qualify every legal endpoint, weight expression, or other
interaction in §18.5, and it does not close clause 18.
