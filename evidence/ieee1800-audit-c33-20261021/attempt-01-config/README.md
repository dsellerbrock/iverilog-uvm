# IEEE 1800 Clause 33 configuration probe

The probe selects configuration `cfg` as the Icarus elaboration root with `-s cfg` and checks that its instance binding selects `alt`; a `-s top` control checks the ordinary unconfigured design. The pinned compiler help documents `-s topmodule` but no configuration-specific selector. The `-s` flag is an Icarus invocation detail, not an IEEE syntax requirement.

## Standard basis

- §33.4 describes a configuration as rules for library-cell binding. Syntax 33-4 in §33.4.1 includes a config declaration, design statement, and config rules. IEEE 1800-2017 pp.905–906; 2023 pp.937–938.
- §33.4.1.1 says the design statement names the library and cell of the top-level module(s) configured by the declaration. This establishes the config’s design hierarchy. IEEE 1800-2017 p.906; 2023 p.938.
- §33.4.1.3 defines the instance selector as a hierarchical name from the config’s top-level module; §33.4.1.5 defines the ordered `liblist` search; §33.4.1.6 says a `use` clause “specifies the exact library and cell” for the selected instance. It can only be used with an instance or cell selector. IEEE 1800-2017 pp.907–908; 2023 p.939.

The specific rule under test is `instance top.u use work.alt;`, which should replace `leaf` with `alt` for `top.u`. Expected output under `-s cfg` is `ALT`; under `-s top` it is `LEAF`, in both editions. The config source was rejected before elaboration in both editions, so a separate modules-only control confirms that ordinary `-s top` selection compiles and prints `LEAF`.

Probes: [`p33_cfg.sv`](../../../../tests/1800_audit/c33/p33_cfg.sv) and [`p33_cfg_control.sv`](../../../../tests/1800_audit/c33/p33_cfg_control.sv). Paired-edition results and raw Slurm logs are in [`RESULT.md`](RESULT.md); open+closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md).
