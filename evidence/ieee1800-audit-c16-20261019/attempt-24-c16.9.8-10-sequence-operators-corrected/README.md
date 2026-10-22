# §§16.9.8–16.9.10 second probe attempt — partial evidence only

Host: DAN-DESKTOP, Slurm job 3194. Source: clean `main`
`c31cbf1b52f1a39d5775f276e2340525a444a79e`; Icarus SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.

The §16.9.8 sequence-match-item form failed to parse in both editions. The
§16.9.9 and §16.9.10 assertions again observed their expected negative cases,
but the probes attempted to count positive cover actions; Icarus explicitly
warned that those actions are dropped, leaving the cover counters at zero.
This attempt is excluded for positive-result classification. The probe source,
compile/run logs, hashes, and metadata are preserved in `input/` and
`results/`; a simpler cover-counter form is being tried in attempt 25.
