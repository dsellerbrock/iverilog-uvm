# IEEE 1800 §19.10 probe result

Slurm job 3008 completed on DAN-DESKTOP with `ExitCode=0:0` (1 CPU, 1 GiB
requested; `sacct` accounting is disabled). It used Icarus 13.0 devel from
`/home/dsell/toolchains/iverilog-a3-main-82023726-679`, source commit
`82023726`; executable SHA-256 values are in `results-3008/environment.txt`.
The input archive SHA-256 is
`2255741bd3edb3cb627a584ea94718486083c9e61e61b87911591db16d4daf0a`; the
submitted script SHA-256 is
`6fef64254ac9774456cb661c25c5b40215c8b90c868185facd6bbb72c2e4296e`.

The probe covers the implicit option structures in IEEE 1800-2017 §19.10
(pp. 585–586) and IEEE 1800-2023 §19.10 (pp. 613–614). Positive probes read
and write `option.weight` and `option.at_least` through covergroup,
coverpoint, and cross instances. Both editions compile and run successfully;
all five runtime checks print `PASS`. A negative probe rejects an unknown
covergroup option member in both editions. The procedural-member probe fails
to compile in both editions: `coverpoint option.goal` and `option.comment`
reads/writes are reported unsupported (four diagnostics per edition).

The result supports a **PARTIAL** classification: tested weight/threshold
access and unknown-member rejection work, while procedural `goal` and
`comment` access does not. The 2023-only `cross_retain_auto_bins` and
`real_interval` fields are covered separately by the §19.7 probes. Issue
[#689](https://github.com/dsellerbrock/iverilog-uvm/issues/689) tracks the
confirmed gap. Raw commands, logs, exit codes, timing, and input hashes are
preserved in `results-3008/`.
