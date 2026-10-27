# §26.7 built-in `std` package probes

The standard-derived expectations and scope of the `package std` negative probe are in [STANDARD.md](STANDARD.md). Probe sources, both-edition logs, hashes, and job records are stored here and in [RESULT.md](RESULT.md).

Expected positive output in both editions:

```text
S1 0
S2 5
S3 1
S4 42
S5 1 3
```

The negative source is classified only against normative text that explicitly settles a user package named `std`. The first full positive probe stopped at syntax errors on qualified built-in types; isolated follow-up results are recorded in `RESULT.md`.
