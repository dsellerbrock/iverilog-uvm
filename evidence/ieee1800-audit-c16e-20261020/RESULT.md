# Raw §16.13.5–§16.13.6 results

| Job | Probe | Edition | Compile exit | Run exit | Observed result |
|---:|---|---:|---:|---:|---|
| 3584 | First cross-clock attempt with cover action | 2017 | 1 | — | Unbound `source_seq.matched`; also warned that the cover pass action was dropped |
| 3584 | First cross-clock attempt with cover action | 2023 | 1 | — | Same diagnostics as 2017 |
| 3585 | Reduced cross-clock assertion | 2017 | 1 | — | Unbound `source_seq.matched` |
| 3585 | Reduced cross-clock assertion | 2023 | 1 | — | Unbound `source_seq.matched` |
| 3586 | Existing same-clock endpoint control | 2017 | 0 | 0 | Expected `EP_FAIL@55`; `endpoint_cover=2` |
| 3586 | Existing same-clock endpoint control | 2023 | 0 | 0 | Expected `EP_FAIL@55`; `endpoint_cover=2` |

Each compile and run used a 30-second timeout. Raw logs, provenance, source and toolchain checksums, and version output are retained under each attempt's `remote-358N/results/` directory.
