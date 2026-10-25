# IEEE 1800 §§24.6–24.7 and §16.12.6 paired probe

Pinned simulator: protected Slurm toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020` (source head `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`). `-B` base: `/home/dsell/toolchains/iverilog-fb584a25-20261020/lib/ivl`. The assignment from the audit lead was to confirm `-g2017` and `-g2023` on a trivial module first, rerun #874 in both modes, and probe program `$exit` and anonymous-program scope.

## Standard text

IEEE 1800-2017 §24.6 (p. 747) states: “The set of program definitions and instances define a space of programwide data, tasks, and functions that is accessible only to programs.” It further says anonymous programs may be used inside packages or compilation-unit scopes to declare programwide items without a new scope, and that their items share the enclosing package or compilation-unit namespace. Its following NOTE says identifiers declared in an anonymous program cannot be referenced outside any program block. The NOTE is informative; the normative “accessible only to programs” sentence is separate.

IEEE 1800-2017 §20.2 states: “The $exit control task waits for all program blocks to complete, and then makes an implicit call to $finish.” Section 24.7 says `$exit` from a program initial thread terminates all initial procedures and their descendants in that originating program. The probe uses a concurrent module event to check that simulation nevertheless ends after the program completes.

## Probe set

- `edition_flags.sv`: control compile in `-g2017` and `-g2023`.
- `p16_13_4_ifelse_clock_flow.sv`: paired-edition reproduction for #874.
- `p24_07_exit.sv`: `$exit` terminates the program's concurrent initial procedure; expected user output is only `P1 5`, with no `NOT_REACHED`, `P1B_NOT_REACHED`, or `TOP 100`.
- `p24_06_anon.sv`: an anonymous program in a package declares `hello`; a program imports and calls it. Expected output: `ANON 1`.
- `n24_06_module_ref.sv`: module scope imports and calls that task. This is recorded as an observation only if rejected because the direct sentence establishing visibility outside a program is an informative NOTE.

## Execution

Slurm job 3653 ran the paired tests with one CPU, 1 GiB, and a five-minute allocation; each compile and simulation had a 30-second timeout. The results and binary hashes are in [`RESULT.md`](RESULT.md), and raw stdout/stderr are in [`remote-3653/`](remote-3653/). Open and closed issue searches are recorded in [`DEDUPE.md`](DEDUPE.md).
