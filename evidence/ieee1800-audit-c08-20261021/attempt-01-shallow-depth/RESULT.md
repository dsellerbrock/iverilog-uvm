# §8.12 depth probes

## Run provenance

- Host: DAN-DESKTOP, Slurm job 3716; 1 CPU, 1 GiB, 15-minute job limit.
- Source toolchain: `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`; Icarus 13.0-devel. SHA-256: `iverilog` `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`; `vvp` `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- Each source was compiled and run once with `-g2017` and once with `-g2023`. Each compile/run shell had a 60-second process-group timeout (`timeout --signal=TERM --kill-after=2s 60s`).
- Job stdout and per-case outputs are preserved in `slurm-3716.out` and `results/`. Slurm reports `RunTime=00:00:00` at its one-second resolution. `sacct` reports accounting storage disabled, so remote peak RSS is unavailable; the 1 GiB request was comfortably above the local 5 MiB pilot peak.

## Results

The operative sentence in both editions is: “An object of the class type being copied is allocated.” (IEEE 1800-2017 §8.12 p. 179; IEEE 1800-2023 §8.12 p. 189.)

| Probe | 2017 | 2023 | Observation |
|---|---:|---:|---|
| S1 base scalar copy | 0 | 0 | New scalar property value copied; modifying the copy leaves source unchanged. |
| S2 direct derived copy | 0 | 0 | Base and derived properties copied; both remain independent. |
| S3 derived object copied through base handle | 134 | 134 | `vvp` aborts in `vvp_cobject::shallow_copy` at assertion `defn_ == that->defn_`. |
| S4 queue, nested object handle, static property | 0 | 0 | Queue copied by value, nested handle remains shared, static property remains shared. |
| S5 inherited local/protected properties | 0 | 0 | Both access-controlled base properties copied into the derived copy. |
| S6 parameterized class property | 0 | 0 | Four-bit specialization and value copied; source remains independent. |

S3 reproduces open issue #616 in both editions. The other five targeted depth cases pass both editions. Overall job exit 1 is the expected result of the deliberately failing S3 reproducer, not an infrastructure failure.

## Reproduction

For each source and edition, the job ran the equivalent of:

```sh
timeout --signal=TERM --kill-after=2s 60s \
  bash -c 'iverilog -g<2017-or-2023> -s top -o case.vvp case.sv && vvp case.vvp'
```

The exact launcher, compiler paths, and raw output are in `run.sbatch`, `slurm-3716.out`, and `results/`.
