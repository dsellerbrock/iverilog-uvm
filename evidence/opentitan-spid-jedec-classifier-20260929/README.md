# OpenTitan directed JEDEC result classification

The frozen 49-target census called `lowrisc:dv:spid_jedec_sim:0.1` a runtime failure solely because it lacked a generic UVM pass banner. The pinned bench checks five continuation bytes and ID `24'hBEA55A` with `$fatal` on mismatch before printing `SPI Flash Read JEDEC ID Tested!!:`. The runner now recognizes that exact checked marker for this core only, and treats directed `TEST TIMED OUT!!` output as failure, including a `$fatal` line. The wrong-core and unchecked-ID controls remain failures in `--self-test`.

- Runner self-test: PASS.
- Frozen 1.027-second output reclassified PASS: exit 0, one checked marker, no hard errors or debt.
- Same frozen VVP image replay: PASS in 1.021 seconds, byte-identical output. Image SHA-256 `74b98db56d1008bd9bc22c4ee789518a4e577c7583901d6db6947861b1138373`; installed VVP SHA-256 `5b9ed7a8ed8006a998b55c0bc42d035aa99ddeb9c1b3495fd0b4651cf23600c3`. The projectless `work/spid-jedec-selected-20260929/{result.json,sim.log}` preserves the replay.
- Fresh one-core matrix run: PASS. Compile exit 0 with zero semantic debt; runtime exit 0 in 1.025 seconds, one checked marker, zero runtime errors/debt, and no 2 GiB footprint-cap or 60-second timeout hit. See `matrix-result.json` and `matrix-runtime.log` here.

The pinned OpenTitan source and frozen 23 PASS / 49 aggregate were not changed. SPI upload and passthrough have separate result criteria.
