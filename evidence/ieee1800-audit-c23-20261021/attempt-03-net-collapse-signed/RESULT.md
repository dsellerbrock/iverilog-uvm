# Clause 23.3.3 net/port probe results — Slurm job 3775

Pinned Icarus `cc25756d187314742d347267c2a513b3e640a7fb`; DAN-DESKTOP, 1 CPU/1 GiB. Scheduler, version, result rows, full raw compile/run logs and remote input hashes are under `raw-slurm-3775/`.

| Case | `-g2017` | `-g2023` | Initial classification |
|---|---|---|---|
| K1, internal `wire` / external `wand` | 0 / `K1 0 St0` | same | Matches Table 23-1 external cell |
| K2, internal `wand` / external `wire` | 0 / `K2 0 St0` | same | Matches Table 23-1 internal cell |
| K3, internal `wor` / external `wand` | compile warning plus `K3 0 St0` | same | Required external-net warning present; value matches |
| K4, internal `supply1` / external `wire` | 0 / `K4 1 Su1` | same | Matches Table 23-1 internal cell and supply strength |
| K5, interconnect merge | The first source was invalid because its top-level display read `iwire` outside a port connection (§23.3.3.1); exclude that failure. Corrected standard example in job 3776 compiles/runs 0/0 and prints `0` in both editions (attempt 04). |
| K6, four signed port expressions | `15, -1, -1, 15` | same | Matches §23.3.3.8 expectations; expected port-width warnings present |
| K7, internal `uwire` / external `wire`, two drivers | Compiles with `vvp.tgt warning: uwire "w" has 2 drivers (compile-progress: treated as wire)` | same | Fails the §6.6.2 single-driver error requirement. Local two-driver control T7 in job 3764 is correctly rejected. The audit lead filed #927; closed #27 is a broad bring-up umbrella, not a conformance tracker. |

Fresh live dedupe: 430 issues (303 open, 127 closed), `dedupe-all-issues-live.json`. No direct hits for the Table 23-1 cells, `interconnect merge`, or signed port conversion. The direct K7 overlap is closed #27; #923 is unpacked-struct user-defined nettype codegen and is distinct. Other nearby issues #436, #897, #818, #924, #925 and #492 are recorded in `DEDUPE.md`.

Lead classification: §23.3.3.6 PARTIAL (#927); §23.3.3.7, §23.3.3.7.1, and §23.3.3.8 IMPLEMENTED (tested subset). K5's corrected standard example passed in job 3776. Clause 23 count is +3 (#924, #925, #927); cumulative new audit issues are 191, with about 278 open `1800-audit` issues.
