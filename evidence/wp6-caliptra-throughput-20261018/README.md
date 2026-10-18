# WP6 Caliptra throughput comparison

This run extends the campaign's three-way, fixed-window Caliptra measurement
to the WP6 candidate. It will compare campaign base `f9f8e0a79f230f38da6cbb4445994ad1075ad531`,
current main `d9caaaea5b410ed14e7ca14be828fc2f2c9fea44`, and exact #658 head
`3b9101a810714c0abd81c3fb66c4b4a2976cac0d`.

It used the three campaign tests, a 2,000-mcycle window (`100–2100`), three
interleaved repeats, one pinned CPU, and the same Caliptra/RTL/QD-BFM inputs as
the M2 throughput measurement. Slurm job 2666 completed with exit code 0.

| Test | Campaign base f9f8e0a | Main d9caaae | WP6 #658 head 3b9101a | Candidate vs base | Candidate vs main |
|---|---:|---:|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 8.355 (3.45%) | 10.779 (5.75%) | 10.782 (5.48%) | +29.05% | +0.03% |
| `smoke_test_sha256` | 8.272 (6.46%) | 10.376 (2.66%) | 10.660 (1.96%) | +28.87% | +2.73% |
| `cptra_ss_test_rom` | 8.250 (7.58%) | 10.450 (3.17%) | 10.114 (14.69%) | +22.58% | -3.22% |

Three-test geometric-mean throughput is +27.03% for `d9caaae` and +26.80%
for the WP6 head versus campaign base. WP6 changes that mean by -0.18% versus
its main base; no Caliptra gain is claimed. The candidate's `cptra_ss_test_rom`
wall spread is 14.69%, so wall time remains supporting evidence. These runs
stop at mcycle 2,100 and are not firmware pass results.

All 39 generated firmware hex inputs and all normalized simulation logs match
across every repeat and build. The raw per-run logs and manifests are archived
in `attempts/job-2666-runs.tar.gz`; summary, event, and source files are in
`attempts/job-2666-results/`.

The runner, mcycle-window VPI plugin source, and deterministic ECC input were
reused byte-for-byte from the [October 16 throughput evidence](../caliptra-top-throughput-20261016/README.md):
their SHA-256 values match the run manifest. They are not copied here again.
The first generated summary carried stale labels from the prior #601 analysis;
that summary and the run-time analyzer are preserved as
`summary-generated-with-stale-labels.*` and
`analyze-3way-run-original.py`. The corrected summary was regenerated from the
raw runs using the source SHAs in the manifests. Its analyzer SHA-256 is
recorded in `attempts/job-2666-results/analysis-script.sha256`.
