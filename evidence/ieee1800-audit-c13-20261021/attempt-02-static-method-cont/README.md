# Clause 13 static-method expression contexts

## Standard basis

IEEE 1800-2017 §13.4 pp. 324–325 and IEEE 1800-2023 §13.4 pp. 340–341 state:
“It shall be illegal to call a function with output, inout, or ref arguments”
in the listed event and expression contexts, including a procedural continuous
assignment and expressions outside procedural statements. These probes use
input-only arguments, so that restriction does not prohibit them. Both editions'
§13.8 examples (2017 pp. 334–335; 2023 pp. 352–353) explicitly place a static
method on a parameterized class in a continuous assignment, e.g.
`assign encoder_out = C#(8)::ENCODER_f(encoder_in);`.

## Cases

Each case is a separate source and is compiled with `-g2017` and `-g2023`.
Successful compilations are run, with every compile/run limited to 60 seconds.

| Case | Expression context | Expected observation |
|---|---|---|
| S1 | Plain class static method in `assign` | Compiles; `y` follows `x` through the method |
| S2 | Parameterized class static method in `assign` | Compiles; specialized-width result follows `x` |
| S3 | Module function in `assign` | Pass control; `y` follows `x` |
| S4 | Plain class static method in `always_comb` | Compiles; `y` follows `x` |
| S5 | Plain class static method in a module input connection | Compiles; child output follows the expression |
| S6 | Class static method called through a constant function in a `localparam` | Record behavior under constant-function rules |

## Dedupe

The fresh open-and-closed issue scan is in `DEDUPE.md`. Existing issue #642
covers the plain and parameterized static-method call failures in continuous
assignments. The new cases separate the expression contexts and retain module
function/procedural controls; they are depth probes for #642, not additional
issue candidates unless a distinct failure appears.

## Run

Slurm job 3738 completed on DAN-DESKTOP with exit code 0:0. Paired results,
exact toolchain hashes, raw logs, and scheduler metrics are in `RESULT.md`.
