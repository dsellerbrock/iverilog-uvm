# §§16.9.8–16.9.10 first probe attempt — partial evidence only

Host: DAN-DESKTOP, Slurm job 3193. Source: clean `main`
`c31cbf1b52f1a39d5775f276e2340525a444a79e`; Icarus SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.

The valid §16.9.8 composed test failed compilation in both editions with:
`first_match of a variable-length sequence that feeds a continuation is not supported by the automaton engine in this shape yet; the assertion is dropped.`
This is evidence of a supported-language gap, not a harness failure.

The §16.9.9 and §16.9.10 probes compiled in both editions, but their first
runtime counters were invalid: assertion success actions counted vacuous
implication passes (8 and 17 respectively). Those runtime counts are excluded.
The probes were corrected to count nonvacuous cover matches separately from
assertion failures; see attempt 24. Original test snapshots and all job 3193
logs are preserved here.
