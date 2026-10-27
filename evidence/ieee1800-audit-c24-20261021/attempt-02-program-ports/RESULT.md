# IEEE 1800 §24.3.2 program-port scheduling probe

## Standard basis

IEEE 1800-2017 and 1800-2023 §24.3.2 say program code updates variables
connected across program ports in the Reactive region set. Program net driving
and resolution also occurs there, and design processes sensitive to those
cross-region updates wake in the Active region set on the next loop iteration.
The relevant semantics and the LRM example are the same in both editions.

## Probe and result

[`p24_03_2_program_port_reactive.sv`](../../../tests/1800_audit/c24/p24_03_2_program_port_reactive.sv)
reduces the standard's module/program example: a design variable drives a
program input; the program's continuous assignment drives an output port; a
design `always` process checks the resulting transitions and ordering.

Slurm job 3605 used current-main toolchain commit
`fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, one CPU, 1 GiB, and a 5-minute
allocation. The test compiled and ran with `-g2017` and `-g2023`; both printed
`dw2=0`, `dw2=1`, and `PASS program_port_reactive`, with empty stderr. Each
compile and run had a 30-second timeout. Source SHA-256:
`77df6ec15ea56b2423a3f410b41cc7cc9cad01f6c0206e910226d220520afc7a`.
Raw stdout, stderr, and Slurm output are retained in [`remote-3605/`](remote-3605/).

## Lead status

No gap was observed in this tested subset, so no issue was proposed. The matrix
remains lead-pending until classification.
